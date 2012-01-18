class SamplesController < ApplicationController

  include IndexPager
  before_filter :find_assets, :only => [:index]
  before_filter :find_and_auth, :only => [:show, :edit, :update, :destroy]


  def new_object_based_on_existing_one
    @existing_sample =  Sample.find(params[:id])
    @sample = @existing_sample.clone_with_associations

    unless @sample.specimen.can_view?
      @sample.specimen = nil
      flash.now[:notice] = "The specimen of the existing sample cannot be viewed, please specify your own specimen! <br/> "
    end

    @existing_sample.sop_masters.each do |s|
       if !s.sop.can_view?
       flash.now[:notice] << "Some or all sops of the existing sample cannot be viewed, you may specify your own! <br/>"
        break
      end
    end
    render :action=>"new"

  end

  def new
    @sample = Sample.new
    @sample.from_new_link = params[:from_new_link]
    @sample.specimen = Specimen.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml
    end
  end


  def create
    @sample = Sample.new(params[:sample])

    @sample.specimen.contributor = @sample.contributor if @sample.specimen.contributor.nil?
    @sample.specimen.projects = @sample.projects if @sample.specimen.projects.blank?
    if @sample.specimen.strain.nil?
      @sample.specimen.strain = Strain.default_strain_for_organism(params[:organism])
    end

    #add policy to sample and specimen
    @sample.policy.set_attributes_with_sharing params[:sharing], @sample.projects
    @sample.specimen.policy.set_attributes_with_sharing params[:sharing], @sample.projects
    sops = (params[:specimen_sop_ids].nil?? [] : params[:specimen_sop_ids].reject(&:blank?)) || []

    if @sample.save
        sops.each do |s_id|
          s = Sop.find(s_id)
          if s.can_view?
            SopSpecimen.create!(:sop_id => s.id,:sop_version=> s.version,:specimen_id=>@sample.specimen.id)
          end
        end
        if @sample.from_new_link=="true"
           render :partial=>"assets/back_to_fancy_parent",:locals=>{:child=>@sample,:parent=>"assay"}
        else
          respond_to do |format|
            flash[:notice] = 'Sample was successfully created.'
            format.html { redirect_to(@sample) }
            format.xml  { head :ok }
          end
        end
    else
        respond_to do |format|
          format.html { render :action => "new" }
        end
    end

  end


  def update

      spec = params[:sample].delete(:specimen_attributes)
      @sample.specimen.update_attributes(spec) unless spec.nil?
      @sample.update_attributes(params[:sample])
      @sample.contributor = @sample.specimen.contributor
      @sample.projects = @sample.specimen.projects
      if @sample.specimen.strain.nil?
        @sample.specimen.strain = Strain.default_strain_for_organism(params[:organism])
      end

      sops  = (params[:sample_sop_ids].nil?? [] : params[:sample_sop_ids].reject(&:blank?)) || []

      #update policy to sample
      @sample.policy.set_attributes_with_sharing params[:sharing],@sample.projects
      @sample.specimen.policy.set_attributes_with_sharing params[:sharing],@sample.projects

      respond_to do |format|

        if @sample.save

          if sops.blank?
            @sample.sop_masters= []
            @sample.save
          else
            sops.each do |s_id|
              s = Sop.find(s_id)
              @sample.associate_sop(s) if s.can_view?
            end
          end

          flash[:notice] = 'Sample was successfully updated.'
          format.html { redirect_to(@sample) }
          format.xml { head :ok }

        else
          format.html { render :action => "edit" }
        end
    end
  end

  def destroy

    respond_to do |format|
      if @sample.destroy
        format.html { redirect_to samples_url }
      else
        flash.now[:error] = "Unable to delete sample" if !@sample.specimen.nil?
        format.html { render :action => "show" }
      end
    end
  end

end
