module ResourceListItemHelper

  def get_list_item_content_partial resource
    get_original_model_name(resource).pluralize.underscore + "/resource_list_item"
  end

  def get_list_item_actions_partial resource
    if resource.authorization_supported? && resource.is_downloadable_asset?
      actions_partial = "assets/resource_actions_td"
    else
      actions_partial = nil
    end
    actions_partial
  end

  def get_list_item_avatar_partial resource
    if resource.show_contributor_avatars?
      "assets/asset_avatars"
    elsif resource.class.name.downcase=="event"
      ""
    else
      "layouts/avatars"
    end
  end

  def list_item_title resource, options={}
    cache_key = "rli_title_#{resource.cache_key}_#{resource.authorization_supported? && resource.can_manage?}"
    result = Rails.cache.fetch(cache_key) do
      title=options[:title]
      url=options[:url]
      include_avatar=options[:include_avatar]
      include_avatar=true if include_avatar.nil?

      if title.nil?
        title = get_object_title(resource)
      end

      html = "<div class=\"list_item_title\">"

      if resource.class.name.split("::")[0] == "Person"
        icons = seek_role_icons(resource)
        html << "<p>#{link_to title, (url.nil? ? show_resource_path(resource) : url)} #{icons}</p>"
      else
        if include_avatar && (resource.avatar_key || resource.use_mime_type_for_avatar?)
          image=resource_avatar resource,:style=>"width: 24px; height: 24px; vertical-align: middle"

          icon  = link_to_draggable(image, show_resource_path(resource), :id=>model_to_drag_id(resource), :class=> "asset", :title=>tooltip_title_attrib(get_object_title(resource)))

          html << "<p style=\"float:left;width:95%;\">#{icon} #{link_to title, (url.nil? ? show_resource_path(resource) : url)}</p>"
          html << "#item_visibility"
          html << "<br style=\"clear:both\"/>"
        else
          html << "<p>#{link_to title, (url.nil? ? show_resource_path(resource) : url)}</p>"
        end
      end
      html << "</div>"
    end
    visibility = resource.authorization_supported? && resource.can_manage? ? list_item_visibility(resource.policy) : ""
    result = result.gsub("#item_visibility",visibility)
    result
  end

  def list_item_tag_list resource
    list_item_simple_list(resource.annotations.collect{|a| a.value}, "Tags") {|i| link_for_ann(i)}
  end

  def list_item_scale_list resource
    if resource.is_scalable?
      ordered_scales = sort_scales resource.scales
      list_item_simple_list(ordered_scales, "Scales") {|i| link_for_scale(i)}
    else
      nil
    end
  end

  def list_item_simple_list items, attribute
    html = "<p class=\"list_item_attribute\"><b>#{attribute}:</b> "
    if items.empty?
      html << "<span class='none_text'>Not specified</span>"
    else
      items.each do |i|
        if block_given?
          value = yield(i)
        else
          value = (link_to get_object_title(i), show_resource_path(i))
        end
        html << value + (i == items.last ? "" : ", ")
      end
    end
    return html + "</p>"
  end

  def list_item_authorized_list *args
   "<p class=\"list_item_attribute\">#{authorized_list *args}</p>"
  end

  def list_item_attribute attribute, value, url=nil, url_options={}
    unless url.nil?
      value = link_to value, url, url_options
    end
    return "<p class=\"list_item_attribute\"><b>#{attribute}</b>: #{value}</p>"
  end

  def list_item_authorized_attribute attribute, object, url='undefined', method = :title
    url = object if url == 'undefined'
    not_authorized_text = object.try(:title_is_public?) ? object.title : "Not available"
    list_item_optional_attribute attribute, object.try(:can_view?) ? object.send(method) : nil, url, not_authorized_text
  end

  def list_item_optional_attribute attribute, value, url=nil, missing_value_text="Not specified"
    if value.blank?
      value = "<span class='none_text'>#{missing_value_text}</span>"
    else
      unless url.nil?
        value = link_to value, url
      end
    end
    return missing_value_text.nil? ? "" : "<p class=\"list_item_attribute\"><b>#{attribute}</b>: #{value}</p>"
  end

  def list_item_timestamp resource
    html = "<p class=\"list_item_attribute none_text\" style=\"text-align:center;\"><b>Created:</b> " + date_as_string(resource.created_at,true)
    unless resource.created_at == resource.updated_at
      html << "&nbsp;&nbsp;&nbsp<b>Last updated:</b> " + date_as_string(resource.updated_at,true)
    end
    html << "</p>"
    return html
  end

  def list_profile_registered_timestamp resource
    html = "<p class=\"list_item_attribute none_text\" style=\"text-align:center;\"><b>Registered:</b> <label>" + (resource.try(:user).try(:created_at).nil? ? "Not yet registered" : date_as_string(resource.try(:user).try(:created_at)))
    html << "</label></p>"
    return html
  end

  def list_item_description text, auto_link=true, length=500
    html = "<div class=\"list_item_desc\">"
    html << text_or_not_specified(text, :description => true, :auto_link=>auto_link, :length=>length)
    html << "</div>"
    return html
  end

  def list_item_contributor resource
    return "<p class=\"list_item_attribute\"><b>Uploader</b>: #{jerm_harvester_name}</p>" if resource.contributor.nil?
    list_item_authorized_attribute 'Uploader', resource.contributor.person
  end

  def list_item_expandable_text attribute, text, length=200
    full_text  = text_or_not_specified(text, :description => false, :auto_link=>false)
    trunc_text = text_or_not_specified(text, :description => false, :auto_link=>false, :length=>length)
    #Don't bother with fancy stuff if not enough text to expand
    if full_text == trunc_text
      html = (attribute ? "<p class=\"list_item_attribute\"><b>#{attribute}</b>:</p>" : "") + "<div class=\"list_item_desc\">"
      html << trunc_text
      html << "</div>"
    else
      html = "<script type=\"text/javascript\">\n"
      html << "fullResourceListItemExpandableText[#{text.object_id}] = '#{escape_javascript(full_text)}';\n"
      html << "truncResourceListItemExpandableText[#{text.object_id}]  = '#{escape_javascript(trunc_text)}';\n"
      html << "</script>\n"
      html << (attribute ? "<p class=\"list_item_attribute\"><b>#{attribute}</b> " : "")
      html << (link_to "(Expand)", "#", :id => "expandableLink#{text.object_id}", :onClick => "expandResourceListItemExpandableText(#{text.object_id});return false;")
      html << "</p>"
      html << "<div class=\"list_item_desc\"><div id=\"expandableText#{text.object_id}\">"
      html << trunc_text
      html << "</div>"
      html << "</div>"
    end
  end

  def list_item_visibility policy
    title = ""
    html  = ""
    case policy.sharing_scope
      when 0
        title = "Private"
        html << image('lock', :title=>title, :class => "visibility_icon")
      when 1
        title = "Custom Policy"
        html << image('manage', :title=>title, :class => "visibility_icon")
      when 2
        title = "Visible to all #{Seek::Config.project_name} projects"
        html << image('open', :title=>title, :class => "visibility_icon")
      when 3
        title = "Visible to all registered users"
        html << image('open', :title=>title, :class => "visibility_icon")
      when 4
        title = "Visible to everyone"
        html << image('world', :title=>title, :class => "visibility_icon")
    end
    html << ""
    html
  end

end