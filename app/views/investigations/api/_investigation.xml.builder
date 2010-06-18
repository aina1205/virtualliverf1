s_root = false unless local_assigns.has_key?(:is_root)

parent_xml.tag! "investigation",
xlink_attributes(uri_for_object(investigation), :title => xlink_title(investigation)).merge(is_root ? xml_root_attributes : {}),
                :resourceType => "Investigation" do
  
  render :partial=>"api/standard_elements",:locals=>{:parent_xml => parent_xml,:is_root=>is_root,:object=>investigation}
  
  
end