#lib/seek/annotation_common.rb

module Seek
  module AnnotationCommon
    include CommonSweepers

    def update_annotations_ajax
      entity=controller_name.singularize.camelize.constantize.find(params[:id])
      if entity.can_view?
        update_owned_annotations entity
        eval("@#{controller_name.singularize} = entity")
        render :update do |page|
          page.replace_html 'tags_box', :partial=>'assets/tags_box'
          page.replace_html 'sidebar_tag_cloud', :partial=>'gadgets/merged_tag_cloud_gadget'
          page.visual_effect :highlight, 'tags_box'
          page.visual_effect :highlight, 'sidebar_tag_cloud'
        end
      else
        render :update do |page|
          #this is to prevent a missing template error. If permission is not allowed, then the entity is silently left unchanged
        end
      end
    end

    protected
    def resolve_tags_from_params params
      tags=[]
      params[:tag_autocompleter_selected_ids].each do |selected_id|
        tag=Annotation.find(selected_id)
        tags << tag.value.text
      end unless params[:tag_autocompleter_selected_ids].nil?
      params[:tag_autocompleter_unrecognized_items].each do |item|
        tags << item
      end unless params[:tag_autocompleter_unrecognized_items].nil?
      tags
    end

    #Updates all annotations as the owner of the entity, using the parameters passed through the web interface Any tags that do not match those passed in are removed as a tagging for this item.
    #New tags are assigned to the owner, which defaults to the current user.
    def update_annotations entity, owner=User.current_user

      return false if owner.nil?

      tags = resolve_tags_from_params params

      entity.annotate_with tags
    end

    #Updates tags for a given owner using the params passed through the tagging web interface. This just updates the tags for a given owner, which defaults
    #to the current user - it doesn't affect other peoples tags for that item.
    def update_owned_annotations entity, owner=User.current_user
      return false if owner.nil?

      attr="tag"

      #FIXME: this is currently more or less a copy of Person.update_annotations - need consolidating

      tags = resolve_tags_from_params params

      current = entity.annotations_with_attribute(attr)
      current = current.select{|c| c.source==owner}

      for_removal = []
      current.each do |cur|
        unless tags.include?(cur.value.text)
          for_removal << cur
        end
      end

      tags.each do |tag|
        exists = TextValue.find(:all, :conditions=>{:text=>tag}).select{ |tv| !tv.annotations.select { |a| a.attribute.name == attr }.empty?}
        # text_value exists for this attr
        if !exists.empty?
          # isn't already used as an annotation for this entity with this owner
          exists_for_owner=exists.select{|e| e.annotations{|a| a.annotatable==entity && a.source==owner}.empty?}
          if exists_for_owner.empty?
            annotation = Annotation.new(:source => owner,
                                        :annotatable => entity,
                                        :attribute_name => attr,
                                        :value => exists.first)
            annotation.save!
          end
        else
          annotation = Annotation.new(:source => owner,
                                      :annotatable => entity,
                                      :attribute_name => attr,
                                      :value => tag)
          annotation.save!
        end
      end
      for_removal.each do |annotation|
        annotation.destroy
      end
    end


  end

end
