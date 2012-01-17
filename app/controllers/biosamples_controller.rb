class BiosamplesController < ApplicationController
  def existing_strains
      strains_of_organisms = []
      organisms = []
      if params[:organism_ids]
        organism_ids = params[:organism_ids].split(',')
        organism_ids.each do |organism_id|
          organism=Organism.find_by_id(organism_id)
          if organism
            organisms << organism
            strains=organism.try(:strains)
            strains_of_organisms |= strains ? strains.reject { |s| s.title == 'default' } : strains
          end
        end
      end
      render :update do |page|
          page.replace_html 'existing_strains', :partial=>"biosamples/existing_strains", :object=>strains_of_organisms, :locals=>{:organisms=>organisms}
      end
  end

  def create_strain_popup
    strain = Strain.find_by_id(params[:strain_id])
    respond_to do  |format|
      if current_user.person.member?
        format.html{render :partial => 'biosamples/create_strain_popup', :locals => {:strain => strain}}
      else
        flash[:error] = "You are not authorized to create new strain. Only members of known projects, institutions or work groups are allowed to create new content."
      end
    end
  end

  def new_strain_form
    strain = Strain.find_by_id(params[:id]) || Strain.new
    render :update do |page|
      page.replace_html 'strain_form', :partial=>"biosamples/strain_form",:locals=>{:strain => strain, :organism_id => params[:organism_id]}
    end
  end

  def existing_specimens
    specimens_of_strains = []
    strains = []
    if params[:strain_ids]
      strain_ids = params[:strain_ids].split(',')
      strain_ids.each do |strain_id|
        strain=Strain.find_by_id(strain_id)
        if strain
          strains << strain
          specimens=strain.specimens
          specimens_of_strains |= specimens.select(&:can_view?)
        end
      end
    end

    render :update do |page|
        page.replace_html 'existing_specimens', :partial=>"biosamples/existing_specimens",:object=>specimens_of_strains, :locals=>{:strains=>strains}
    end
  end

  def existing_samples
    samples_of_specimens = []
    specimens = []
    if params[:specimen_ids]
      specimen_ids = params[:specimen_ids].split(',')
      specimen_ids.each do |specimen_id|
        specimen=Specimen.find_by_id(specimen_id)
        if specimen and specimen.can_view?
        specimens << specimen
        samples=specimen.try(:samples)
        samples_of_specimens |= samples.select(&:can_view?)
          end
      end
    end
    render :update do |page|
        page.replace_html 'existing_samples', :partial=>"biosamples/existing_samples",:object=>samples_of_specimens,:locals=>{:specimens=>specimens}
    end
  end

  def create_sample_popup
    sample = Sample.find_by_id(params[:sample_id])
    unless sample
      specimen = Specimen.find_by_id(params[:specimen_id])
    else
      specimen = sample.specimen
    end
    respond_to do  |format|
      if current_user.person.member?
        format.html{render :partial => 'biosamples/create_sample_popup', :locals => {:sample => sample, :specimen => specimen}}
      else
        flash[:error] = "You are not authorized to create new sample. Only members of known projects, institutions or work groups are allowed to create new content."
      end
    end
  end

  def create_specimen_sample
    params[:sharing][:permissions] = nil

    sample = Sample.new(params[:sample])

    sop_ids = []

    specimen = Specimen.find_by_id(params[:specimen][:id])
    if specimen.nil?
      specimen = Specimen.new(params[:specimen])
      sop_ids = (params[:specimen_sop_ids].nil? ? [] : params[:specimen_sop_ids].reject(&:blank?))||[]
      specimen.policy.set_attributes_with_sharing params[:sharing], sample.projects
      #if no strain is selected, create/select the default strain
      if params[:specimen][:strain_id] == '0'
        strain = @specimen.default_strain_for params[:organism_id]
        specimen.strain = strain
      end
      #Add creators
      AssetsCreator.add_or_update_creator_list(specimen, params[:creators])
    end
    sample.policy.set_attributes_with_sharing params[:sharing], sample.projects
    sample.specimen = specimen
    respond_to do |format|
      if specimen.save && sample.save
        sop_ids.each do |sop_id|
          sop= Sop.find sop_id
          SopSpecimen.create!(:sop_id => sop_id, :sop_version=> sop.version, :specimen_id=>specimen.id)
        end
      else
        specimen_error_messages = ''
        specimen.errors.full_messages.each do |e_m|
          specimen_error_messages << "cell culture #{e_m.downcase}. "
        end
        sample_error_messages = ''
        sample.errors.full_messages.each do |e_m|
          sample_error_messages << "sample #{e_m.downcase}. "
        end
        flash[:error] = "Fail to create new sample: #{specimen_error_messages}#{sample_error_messages}"
      end
      format.html { redirect_to :back }
    end
  end

end
