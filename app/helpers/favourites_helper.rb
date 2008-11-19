module FavouritesHelper
  def model_to_drag_id object
    model_name=object.class.to_s
    return "drag_"+model_name+"_"+object.id.to_s
  end
  
  def fav_image_tag favourite
    item = favourite.model_name.constantize.find(favourite.asset_id)
    #FIXME: these need to be protected with 'h'
    if (item.instance_of? Person)
      title=item.name
      image=person_avatar_image(item)
    elsif (item.instance_of? Project)
      title=item.name
      image="project_64x64.png"
    elsif (item.instance_of? Institution)
      title=item.name
      image="institution_64x64.png"
    end
    image_tag = image_tag(image, :size=>"27x32",:alt=>title)
    return link_to_draggable(image_tag, url_for(item), :title=>tooltip_title_attrib(title),:class=>"favourite", :id=>"fav_#{favourite.id}")
  end
  
  def favourite_drag_element drag_id
    return draggable_element(drag_id, :revert=>true, :ghosting=>true)
  end
  
  private
  
end
