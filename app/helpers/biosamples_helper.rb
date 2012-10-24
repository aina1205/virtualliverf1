module BiosamplesHelper
  def create_strain_popup_link
     return link_to_remote_redbox(image_tag("famfamfam_silk/add.png") + 'Create new strain',
      { :url => url_for(:controller => 'biosamples', :action => 'create_strain_popup') ,
        :failure => "alert('Sorry, an error has occurred.'); RedBox.close();",
        :with => "'strain_id=' + getSelectedStrains()+'&organism_ids='+$F('strain_organism_ids')",
        :condition => "checkSelectOneStrain()"
      }
      #,
      #:alt => "Click to create a new favourite group (opens popup window)",#options[:tooltip_text],
      #:title => tooltip_title_attrib("Opens a popup window, where you can create a new favourite<br/>group, add people to it and set individual access rights.") }  #options[:tooltip_text]
    )
  end

  
   def create_sample_popup_link
     link_to image("new") + "Create new sample", new_sample_path(), {:id => 'new_sample_link', :target => '_blank', :onclick => "if (checkSelectOneSpecimen('#{Seek::Config.sample_parent_term}')) {return(true);} else {return(false);}"}
   end

  def edit_strain_popup_link strain
    if strain.can_manage?
      return link_to_remote_redbox(image_tag("famfamfam_silk/wrench.png"),
                                   {:url => url_for(:controller => 'biosamples', :action => 'edit_strain_popup'),
                                    :failure => "alert('Sorry, an error has occurred.'); RedBox.close();",
                                    :with => "'strain_id=' + #{strain.id}"
                                   },
                                   :title => "Manage this strain")
    elsif strain.can_edit?
      return link_to_remote_redbox(image_tag("famfamfam_silk/page_white_edit.png"),
                                   {:url => url_for(:controller => 'biosamples', :action => 'edit_strain_popup'),
                                    :failure => "alert('Sorry, an error has occurred.'); RedBox.close();",
                                    :with => "'strain_id=' + #{strain.id}"
                                   },
                                   :title => "Edit this strain")
    else
      explanation = "You are unable to edit this Strain"
      return image('edit', {:alt=>"Edit",:class=>"disabled",:onclick=>"javascript:alert(\"#{explanation}\")",:title=>"#{tooltip_title_attrib(explanation)}"})
    end
  end

  def strain_row_data strain
    creator = strain.contributor.try(:person)
    creator_link = creator ? link_to(creator.name, person_path(creator.id)) : ""
    [(link_to strain.organism.title, organism_path(strain.organism.id)),
     (check_box_tag "selected_strain_#{strain.id}", strain.id, false, :onchange => strain_checkbox_onchange_function)   ,
     text_or_not_specified(strain.title), text_or_not_specified(strain.genotype_info), text_or_not_specified(strain.phenotype_info), strain.id, text_or_not_specified(strain.synonym), text_or_not_specified(creator_link), text_or_not_specified(strain.parent_strain),
     (if strain.can_delete?
        link_to_remote image("destroy", :alt => "Delete", :title => "Delete this strain"), :url => {:action => "destroy", :controller => 'biosamples', :id => strain.id, :class => 'strain', :id_column_position => 5},
                             :confirm => "Are you sure you want to delete this strain?", :method => :delete
      else
        explanation=unable_to_delete_text strain
        image('destroy', {:alt=>"Delete",:class=>"disabled",:onclick=>"javascript:alert(\"#{explanation}\")",:title=>"#{tooltip_title_attrib(explanation)}"})
      end ),
     edit_strain_popup_link(strain)]
  end
  
  def organism_selection_onchange_function
     function =  remote_function(:url=>{:action=>"existing_strains", :controller=>"biosamples"},
                                                      :with=>"'organism_ids='+$F('strain_organism_ids')",
                                                      :before=>"show_large_ajax_loader('existing_strains')")+ ";"
     function += remote_function(:url => {:controller => 'biosamples',
                                          :action => 'existing_specimens'},
                                          :with => "'strain_ids=' + getSelectedStrains() + '&organism_ids='+$F('strain_organism_ids')",
                                          :before=>"show_large_ajax_loader('existing_specimens')") + ";"  if Seek::Config.is_virtualliver
     function +=  "check_show_existing_items('strain_organism_ids', 'existing_strains', '');"
     if Seek::Config.is_virtualliver
       function +=  "check_show_existing_items('strain_organism_ids', 'existing_specimens', '');"
     else
       function += "hide_existing_specimens();"
     end
     function += "hide_existing_samples();return(false);"
     function
   end

  def strain_checkbox_onchange_function
        function = remote_function(:url => {:controller => 'biosamples',
                                            :action => 'existing_specimens'},
                                            :with => "'strain_ids=' + getSelectedStrains()+'&organism_ids='+$F('strain_organism_ids')",
                                            :before=>"show_large_ajax_loader('existing_specimens')")+ ";"
        function += "show_existing_specimens();hide_existing_samples();" unless Seek::Config.is_virtualliver
        function += "return(false);"
        function
  end   

  def specimen_row_data specimen
    id_column = Seek::Config.is_virtualliver ? 8 : 6
    creators = []
    specimen.creators.each do |creator|
      creators << link_to(creator.name, person_path(creator.id))
    end
    creators << specimen.other_creators unless specimen.other_creators.blank?

    explanation = "You are unable to delete this #{Seek::Config.sample_parent_term}. "
    explanation += unable_to_delete_text specimen  unless specimen.samples.blank?
    disabled_delete_icon = image('destroy', {:alt=>"Delete",:class=>"disabled",:onclick=>"javascript:alert(\"#{explanation}\")",:title=>"#{tooltip_title_attrib(explanation)}"})

    delete_icon = specimen.can_delete? ? (link_to_remote image("destroy", :alt => "Delete", :title => "Delete this #{Seek::Config.sample_parent_term}"),
                         :url => {:action => "destroy", :controller => 'biosamples', :id => specimen.id, :class => 'specimen', :id_column_position => id_column},
                         :confirm => "Are you sure you want to delete this #{Seek::Config.sample_parent_term}?", :method => :delete) : disabled_delete_icon
    update_icon = nil
    if specimen.can_manage?
      update_icon = link_to image("manage"), edit_specimen_path(specimen) + "?from_biosamples=true", {:title => "Manage this #{Seek::Config.sample_parent_term}", :target => '_blank'}
    elsif specimen.can_edit?
      update_icon = link_to image("edit"), edit_specimen_path(specimen) + "?from_biosamples=true", {:title => "Edit this #{Seek::Config.sample_parent_term}", :target => '_blank'}
    else
      explanation = "You are unable to edit this #{Seek::Config.sample_parent_term}."
      update_icon = image('edit', {:alt=>"Edit",:class=>"disabled",:onclick=>"javascript:alert(\"#{explanation}\")",:title=>"#{tooltip_title_attrib(explanation)}"})
    end
    strain = specimen.strain
    strain_info = 'Strain' + ": "+ strain.info + "(Seek ID=#{strain.id})"

    unless Seek::Config.is_virtualliver
      [strain_info,
       (check_box_tag "selected_specimen_#{specimen.id}", specimen.id, false, {:onchange => remote_function(:url => {:controller => 'biosamples',
                                                                                                                     :action => 'existing_samples'},
                                                                                                                    :with => "'specimen_ids=' + getSelectedSpecimens()",
                                                                                                                    :before=>"show_large_ajax_loader('existing_samples')") + ";show_existing_samples();"}),
       link_to(specimen.title, specimen_path(specimen.id)), text_or_not_specified(specimen.born_info), text_or_not_specified(specimen.culture_growth_type.try(:title)), text_or_not_specified(creators.join(", ")), specimen.id, text_or_not_specified(asset_version_links(specimen.sops).join(", ")), delete_icon, update_icon]

    else
      [strain_info,
           (check_box_tag "selected_specimen_#{specimen.id}", specimen.id, false, {:onchange => remote_function(:url => {:controller => 'biosamples',
                                                                                                                         :action => 'existing_samples'},
                                                                                                                        :with => "'specimen_ids=' + getSelectedSpecimens()",
                                                                                                                        :before=>"show_large_ajax_loader('existing_samples')") + ";show_existing_samples();"}),
           link_to(specimen.title, specimen_path(specimen.id)), text_or_not_specified(specimen.born_info), text_or_not_specified(specimen.culture_growth_type.try(:title)), text_or_not_specified(specimen.genotype_info),text_or_not_specified(specimen.phenotype_info),text_or_not_specified(creators.join(", ")), specimen.id, text_or_not_specified(asset_version_links(specimen.sops).join(", ")), delete_icon, update_icon]
    end
  end

  def sample_row_data sample
    explanation = "You are unable to delete this Sample. "
    explanation += unable_to_delete_text sample  unless sample.assays.blank?
    disabled_delete_icon =  image('destroy', {:alt=>"Delete",:class=>"disabled",:onclick=>"javascript:alert(\"#{explanation}\")",:title=>"#{tooltip_title_attrib(explanation)}"})

    delete_icon = sample.can_delete? ? (link_to_remote image("destroy", :alt => "Delete", :title => "Delete this sample"),
                             :url => {:action => "destroy", :controller => 'biosamples', :id => sample.id, :class => 'sample', :id_column_position => 6},
                             :confirm => "Are you sure you want to delete this sample?", :method => :delete) : disabled_delete_icon
    update_icon = nil
    if sample.can_manage?
      update_icon = link_to image("manage"), edit_sample_path(sample) + "?from_biosamples=true", {:title => "Manage this sample", :target => '_blank'}
    elsif sample.can_edit?
      update_icon = link_to image("edit"), edit_sample_path(sample) + "?from_biosamples=true", {:title => "Edit this sample}", :target => '_blank'}
    else
      explanation = "You are unable to edit this Sample"
      update_icon = image('edit', {:alt=>"Edit",:class=>"disabled",:onclick=>"javascript:alert(\"#{explanation}\")",:title=>"#{tooltip_title_attrib(explanation)}"})
    end

    [sample.specimen_info,
     (link_to sample.title, sample_path(sample.id)),
     text_or_not_specified(sample.lab_internal_number), text_or_not_specified(sample.sampling_date_info), text_or_not_specified(sample.age_at_sampling_info), text_or_not_specified(sample.provider_name), sample.id, text_or_not_specified(sample.comments), delete_icon, update_icon]
  end
end
