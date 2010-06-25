is_root = false unless local_assigns.has_key?(:is_root)

parent_xml.tag! "publication",
core_xlink(publication).merge(is_root ? xml_root_attributes : {}),
                :resourceType => "Publication" do
  
  render :partial=>"api/standard_elements",:locals=>{:parent_xml => parent_xml,:is_root=>is_root,:object=>publication} 
  if (is_root)
    parent_xml.tag! "doi",publication.doi
    parent_xml.tag! "pubmed_id",publication.pubmed_id
    parent_xml.tag! "abstract",publication.abstract
    parent_xml.tag! "journal",publication.journal
    parent_xml.tag! "published_date",publication.published_date
    associated_resources_xml parent_xml,publication
  end
end