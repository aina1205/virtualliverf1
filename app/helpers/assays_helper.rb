require 'acts_as_ontology_view_helper'

module AssaysHelper
  
  include Stu::Acts::Ontology::ActsAsOntologyViewHelper  

  #assays that haven't already been associated with a study
  def assays_available_for_study_association
    Assay.find(:all,:conditions=>['study_id IS NULL'])
  end

  #only data files authorised for show, and belonging to projects matching current_user
  def data_files_for_assay_association
    data_files=DataFile.find(:all,:include=>:asset)
    data_files=data_files.select{|df| current_user.person.member_of?(df.projects)}
    Authorization.authorize_collection("view",data_files,current_user)
  end

  def assay_organism_list_item assay_organism
    result = link_to h(assay_organism.organism.title),assay_organism.organism
    if assay_organism.strain
       result += " : "
       result += link_to h(assay_organism.strain.title),assay_organism.organism,{:class => "assay_strain_info"}
    end
    if assay_organism.culture_growth_type
      result += " (#{assay_organism.culture_growth_type.title})"
    end
    return result
  end
  def show_assay_organisms_list assay_organisms,none_text="Not specified"
      result=""
      result="<span class='none_text'>#{none_text}</span>" if assay_organisms.empty?
      result += "<br/>"
    assay_organisms.each do |ao|

        organism = ao.organism
        strain = ao.strain
        culture_growth_type = ao.culture_growth_type

        if organism
        result += link_to h(organism.title),organism,{:class => "assay_organism_info"}
        end

        if strain
          result += " : "
          result += link_to h(strain.title),strain,{:class => "assay_strain_info"}
        end

        if culture_growth_type
          result += " (#{culture_growth_type.title})"
        end
        result += ",<br/>" unless ao == assay_organisms.last

      end
      result
    end

  def show_specimen_organisms_list specimens,none_text="Not specified"
    result=""
    result="<span class='none_text'>#{none_text}</span>" if specimens.empty?
    organisms = specimens.collect{|s|[s.organism,s.strain,s.culture_growth_type]}.uniq

    organisms.each do |ao|

      organism = ao.first
      strain = ao.second
      culture_growth_type = ao.third

      if organism
      result += link_to h(organism.title),organism,{:class => "assay_organism_info"}
      end

      if strain
        result += " : "
        result += link_to h(strain.title),strain,{:class => "assay_strain_info"}
      end

      if culture_growth_type
        result += " (#{culture_growth_type.title})"
      end
      result += ",<br/>" unless ao == organisms.last

    end
    result
  end

  def authorised_assays projects=nil
    authorised_assets(Assay, projects, "edit")
  end

  def list_assay_samples_and_organisms attribute,assay_samples,assay_organisms, none_text="Not Specified"

    result= "<p class=\"list_item_attribute\"> <b>#{attribute}</b>: "

    result +="<span class='none_text'>#{none_text}</span>" if assay_samples.blank? and assay_organisms.blank?

    assay_samples.each do |as|
      result += "<br/>" if as==assay_samples.first
      organism = as.specimen.organism
      strain = as.specimen.strain
      sample = as
      culture_growth_type = as.specimen.culture_growth_type

      if organism
      result += link_to h(organism.title),organism,{:class => "assay_organism_info"}
      end

      if strain
        result += " : "
        result += link_to h(strain.title),strain,{:class => "assay_strain_info"}
      end

      if sample
        result += " : "
        result += link_to h(sample.title),sample
      end

      if culture_growth_type
        result += " (#{culture_growth_type.title})"
      end
      result += ",<br/>" unless as==assay_samples.last and assay_organisms.blank?
    end

    assay_organisms.each do |ao|
      organism = ao.organism
      strain = ao.strain
      culture_growth_type = ao.culture_growth_type

       result += "<br/>" if assay_samples.blank? and ao==assay_organisms.first
      if organism
      result += link_to h(organism.title),organism,{:class => "assay_organism_info"}
      end

      if strain
        result += " : "
        result += link_to h(strain.title),strain,{:class => "assay_strain_info"}
      end

      if culture_growth_type
        result += " (#{culture_growth_type.title})"
      end
      result += ",<br/>" unless ao==assay_organisms.last
    end
    result += "</p>"

    return result
  end

  def list_assay_samples attribute,assay_samples, none_text="Not Specified"

    result= "<p class=\"list_item_attribute\"> <b>#{attribute}</b>: "

    result +="<span class='none_text'>#{none_text}</span>" if assay_samples.blank?

    assay_samples.each do |as|

      organism = as.specimen.organism
      strain = as.specimen.strain
      sample = as
      culture_growth_type = as.specimen.culture_growth_type


      if organism
      result += link_to h(organism.title),organism,{:class => "assay_organism_info"}
      end

      if strain
        result += " : "
        result += link_to h(strain.title),strain,{:class => "assay_strain_info"}
      end

      if sample
        result += " : "
        result += link_to h(sample.title),sample       
      end

      if culture_growth_type
        result += " (#{culture_growth_type.title})"
      end
      result += ",<br/>" unless as == assay_samples.last

    end

    result += "</p>"
    return result
  end

  def list_assay_organisms attribute,assay_organisms,none_text="Not specified"
    result="<p class=\"list_item_attribute\"> <b>#{attribute}</b>: "
    result +="<span class='none_text'>#{none_text}</span>" if assay_organisms.empty?

    assay_organisms.each do |ao|

     organism = ao.organism
     strain = ao.strain
     culture_growth_type = ao.culture_growth_type

        if organism
            result += link_to h(organism.title),organism,{:class => "assay_organism_info"}
        end

        if strain
          result += " : "
          result += link_to h(strain.title),strain,{:class => "assay_strain_info"}
        end
       

        if culture_growth_type
          result += " (#{culture_growth_type.title})"
        end
        result += ",<br/>" unless ao==assay_organisms.last
      end

    result += "</p>"
    return result
  end

end
