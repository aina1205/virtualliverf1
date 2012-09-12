#A couple of these rely on certain things existing in the test db ahead of time.
#:pal relies on Role.pal_role being able to find an appropriate role in the db.
#:assay_modelling and :assay_experimental rely on the existence of the AssayClass's

#Person
  Factory.define(:brand_new_person, :class => Person) do |f|
    f.sequence(:email) { |n| "test#{n}@test.com" }
    f.sequence(:first_name) { |n| "Person#{n}" }
    f.last_name "Last"
  end

  Factory.define(:person_in_project, :parent => :brand_new_person) do |f|
    f.group_memberships {[Factory.build :group_membership]}
  end

  Factory.define(:person, :parent => :person_in_project) do |f|
    f.association :user, :factory => :activated_user
  end

  Factory.define(:admin,:parent=>:person) do |f|
    f.is_admin true
  end

  Factory.define(:pal, :parent => :person) do |f|
    f.is_pal true
    f.after_create { |pal| pal.group_memberships.first.project_roles << ProjectRole.pal_role}
  end

  Factory.define(:asset_manager,:parent=>:person) do |f|
    f.is_asset_manager true
  end

  Factory.define(:project_manager,:parent=>:person) do |f|
    f.is_project_manager true
  end

  Factory.define(:gatekeeper,:parent=>:person) do |f|
    f.is_gatekeeper true
  end

#User
  Factory.define(:brand_new_user, :class => User) do |f|
    f.sequence(:login) { |n| "user#{n}" }
    test_password = "blah"
    f.password test_password
    f.password_confirmation test_password
  end

  Factory.define(:avatar) do |f|
    f.original_filename "#{Rails.root}/test/fixtures/files/file_picture.png"
    f.image_file File.new("#{Rails.root}/test/fixtures/files/file_picture.png","rb")
    f.association :owner,:factory=>:person
  end

  #activated_user mainly exists for :person to use in its association
  Factory.define(:activated_user, :parent => :brand_new_user) do |f|
    f.after_create { |user| user.activate }
  end

  Factory.define(:user_not_in_project,:parent => :activated_user) do |f|
    f.association :person, :factory => :brand_new_person
  end

  Factory.define(:user, :parent => :activated_user) do |f|
    f.association :person, :factory => :person_in_project
  end

#Project
  Factory.define(:project) do |f|
    f.sequence(:title) { |n| "A Project: #{n}" }
  end

#Institution
  Factory.define(:institution) do |f|
    f.sequence(:title) { |n| "An Institution: #{n}" }
  end

#Sop
  Factory.define(:sop) do |f|
    f.title "This Sop"
    f.projects { [Factory.build(:project)] }
    f.association :contributor, :factory => :user

    f.after_create do |sop|
      if sop.content_blob.blank?
        sop.content_blob = Factory.create(:content_blob, :content_type => "application/pdf", :asset => sop, :asset_version => sop.version)
      else
        sop.content_blob.asset = sop
        sop.content_blob.asset_version = sop.version
        sop.content_blob.save
      end
    end
  end

  Factory.define(:doc_sop, :parent => :sop) do |f|
    f.association :content_blob, :factory => :doc_content_blob
  end

  Factory.define(:odt_sop, :parent => :sop) do |f|
    f.association :content_blob, :factory => :odt_content_blob
end

  Factory.define(:pdf_sop,:parent=>:sop) do |f|
    f.association :content_blob,:factory=>:pdf_content_blob
  end


#Policy
  Factory.define(:policy, :class => Policy) do |f|
    f.name "test policy"
    f.sharing_scope Policy::PRIVATE
    f.access_type Policy::NO_ACCESS
  end

  Factory.define(:private_policy, :parent => :policy) do |f|
    f.sharing_scope Policy::PRIVATE
    f.access_type Policy::NO_ACCESS
  end

  Factory.define(:public_policy, :parent => :policy) do |f|
    f.sharing_scope Policy::EVERYONE
    f.access_type Policy::MANAGING
  end

  Factory.define(:all_sysmo_viewable_policy,:parent=>:policy) do |f|
    f.sharing_scope Policy::ALL_SYSMO_USERS
    f.access_type Policy::VISIBLE
  end

  Factory.define(:all_sysmo_downloadable_policy,:parent=>:policy) do |f|
    f.sharing_scope Policy::ALL_SYSMO_USERS
    f.access_type Policy::ACCESSIBLE
  end
    
  Factory.define(:publicly_viewable_policy, :parent=>:policy) do |f|
    f.sharing_scope Policy::EVERYONE
    f.access_type Policy::VISIBLE
  end

  Factory.define(:public_download_and_no_custom_sharing,:parent=>:policy) do |f|
    f.sharing_scope Policy::ALL_SYSMO_USERS
    f.access_type Policy::ACCESSIBLE
  end
  
  Factory.define(:editing_public_policy,:parent=>:policy) do |f|
    f.sharing_scope Policy::EVERYONE
    f.access_type Policy::EDITING
  end

  Factory.define(:downloadable_public_policy,:parent=>:policy) do |f|
    f.sharing_scope Policy::EVERYONE
    f.access_type Policy::ACCESSIBLE
  end

#Permission
  Factory.define(:permission, :class => Permission) do |f|
    f.association :contributor, :factory => :person
    f.association :policy
    f.access_type Policy::NO_ACCESS
  end

#Assay and Technology types

  Factory.define(:technology_type, :class=>TechnologyType) do |f|
    f.sequence(:title) {|n| "A TechnologyType#{n}"}
  end

  Factory.define(:assay_type) do |f|
    f.sequence(:title) {|n| "An AssayType#{n}"}
  end

#Assay
Factory.define(:assay_base, :class => Assay) do |f|
  f.sequence(:title) {|n| "An Assay #{n}"}
  f.sequence(:description) {|n| "Assay description #{n}"}
  f.association :contributor, :factory => :person
  f.association :study
  f.association :assay_type

end

Factory.define(:modelling_assay_class, :class => AssayClass) do |f|
  f.title 'Modelling Assay'
  f.key 'MODEL'
end

Factory.define(:experimental_assay_class, :class => AssayClass) do |f|
  f.title 'Experimental Assay'
  f.key 'EXP'
end

Factory.define(:modelling_assay, :parent => :assay_base) do |f|
  f.association :assay_class, :factory => :modelling_assay_class
end

Factory.define(:modelling_assay_with_organism, :parent => :modelling_assay) do |f|
  f.after_create{|ma|Factory.build(:organism,:assay=>ma)}

end
Factory.define(:experimental_assay, :parent => :assay_base) do |f|
  f.association :assay_class, :factory => :experimental_assay_class
  f.association :technology_type
  f.samples {[Factory.build :sample]}
end

  Factory.define(:assay, :parent => :modelling_assay) {}

#Study
Factory.define(:study) do |f|
  f.sequence(:title) { |n| "Study#{n}" }
  f.association :investigation
  f.association :contributor, :factory => :person
end

#Investigation
Factory.define(:investigation) do |f|
  f.projects {[Factory.build(:project)]}
  f.sequence(:title) { |n| "Investigation#{n}" }
end

#Strain
Factory.define(:strain) do |f|
  f.sequence(:title) { |n| "Strain#{n}" }
  f.association :organism
  f.projects {[Factory.build(:project)]}
  f.association :contributor, :factory => :user
  f.association :policy, :factory => :public_policy
end

#Culture growth type
Factory.define(:culture_growth_type) do |f|
  f.title "a culture_growth_type"
end

#Specimen
Factory.define(:specimen) do |f|
  f.sequence(:title) { |n| "Specimen#{n}" }
  f.sequence(:lab_internal_number) { |n| "Lab#{n}" }
  f.association :contributor, :factory => :user
  f.projects {[Factory.build(:project)]}
  f.association :institution
  f.association :strain
end

#Sample
Factory.define(:sample) do |f|
  f.sequence(:title) { |n| "Sample#{n}" }
  f.sequence(:lab_internal_number) { |n| "Lab#{n}" }
  f.projects {[Factory.build(:project)]}
  f.donation_date Date.today
  f.association :specimen
end


#Data File
Factory.define(:data_file) do |f|
  f.sequence(:title) {|n| "A Data File_#{n}"}
  f.projects {[Factory.build(:project)]}
  f.association :contributor, :factory => :user
  f.after_create do |data_file|
    if data_file.content_blob.blank?
      data_file.content_blob = Factory.create(:pdf_content_blob, :asset => data_file, :asset_version=>data_file.version)
    else
      data_file.content_blob.asset = data_file
      data_file.content_blob.asset_version = data_file.version
      data_file.content_blob.save
    end
  end
end

Factory.define(:rightfield_datafile,:parent=>:data_file) do |f|
  f.association :content_blob,:factory=>:rightfield_content_blob
end

Factory.define(:rightfield_annotated_datafile,:parent=>:data_file) do |f|
  f.association :content_blob,:factory=>:rightfield_annotated_content_blob
end

Factory.define(:non_spreadsheet_datafile,:parent=>:data_file) do |f|
  f.association :content_blob,:factory=>:cronwright_model_content_blob
end

Factory.define(:xlsx_spreadsheet_datafile,:parent=>:data_file) do |f|
  f.association :content_blob,:factory=>:xlsx_content_blob
end

#Model
  Factory.define(:model) do |f|
    f.sequence(:title) {|n| "A Model #{n}"}
    f.projects {[Factory.build(:project)]}
    f.association :contributor, :factory => :user
    f.after_create do |model|
       model.content_blobs = [Factory.create(:cronwright_model_content_blob, :asset => model,:asset_version=>model.version)] if model.content_blobs.blank?
    end
  end

  Factory.define(:model_2_files,:class=>Model) do |f|
    f.sequence(:title) {|n| "A Model #{n}"}
    f.projects {[Factory.build(:project)]}
    f.association :contributor, :factory => :user
    f.after_create do |model|
      model.content_blobs = [Factory.create(:cronwright_model_content_blob, :asset => model,:asset_version=>model.version),Factory.create(:rightfield_content_blob, :asset => model,:asset_version=>model.version)] if model.content_blobs.blank?
    end
  end

  Factory.define(:teusink_model,:parent=>:model) do |f|
    f.after_create do |model|
      model.content_blobs = [Factory.create(:teusink_model_content_blob, :asset=>model,:asset_version=>model.version)]
    end
  end

  Factory.define(:teusink_jws_model,:parent=>:model) do |f|
    f.after_create do |model|
      model.content_blobs = [Factory.create(:teusink_jws_model_content_blob, :asset=>model,:asset_version=>model.version)]
    end
  end

#Publication
  Factory.define(:publication) do |f|
    f.sequence(:title) {|n| "A Publication #{n}"}
    f.sequence(:pubmed_id) {|n| n}
    f.projects {[Factory.build(:project)]}
    f.association :contributor, :factory => :user
  end

#Presentation
  Factory.define(:presentation) do |f|
    f.sequence(:title) { |n| "A Presentation #{n}" }
    f.projects { [Factory.build :project] }
    # f.data_url "http://www.virtual-liver.de/images/logo.png"
    f.association :contributor, :factory => :user
    f.after_create do |presentation|
      if presentation.content_blob.blank?
        presentation.content_blob = Factory.create(:content_blob, :original_filename => "test.pdf", :content_type => "application/pdf", :asset => presentation, :asset_version => presentation.version)
      else
        presentation.content_blob.asset = presentation
        presentation.content_blob.asset_version = presentation.version
        presentation.content_blob.save
      end
    end
  end

  Factory.define(:ppt_presentation, :parent => :presentation) do |f|
    f.association :content_blob, :factory => :ppt_content_blob
  end

  Factory.define(:odp_presentation, :parent => :presentation) do |f|
    f.association :content_blob, :factory => :odp_content_blob
  end

  #Model Version
  Factory.define("Model::Version".to_sym) do |f|
    f.association :model
    f.after_create do |model_version|
      model_version.model.version +=1
      model_version.model.save
      model_version.version = model_version.model.version
      model_version.save
    end

  end

  #SOP Version
  Factory.define("Sop::Version".to_sym) do |f|
    f.association :sop
    f.after_create do |sop_version|
      sop_version.sop.version +=1
      sop_version.sop.save
      sop_version.version = sop_version.sop.version
      sop_version.save
    end
  end

  #DataFile Version
  Factory.define("DataFile::Version".to_sym) do |f|
    f.association :data_file
    f.after_create do |data_file_version|
      data_file_version.data_file.version +=1
      data_file_version.data_file.save
      data_file_version.version = data_file_version.data_file.version
      data_file_version.save
    end
  end

  #Presentation Version
  Factory.define("Presentation::Version".to_sym) do |f|
    f.association :presentation
    f.after_create do |presentation_version|
      presentation_version.presentation.version +=1
      presentation_version.presentation.save
      presentation_version.version = presentation_version.presentation.version
      presentation_version.save
    end
  end

#Misc
  Factory.define(:group_membership) do |f|
    f.association :work_group
  end

  Factory.define(:project_role) do |f|
    f.name "A Role"
  end

  Factory.define(:work_group) do |f|
    f.association :project
    f.association :institution
  end

  Factory.define(:favourite_group) do |f|
    f.association :user
    f.name 'A Favourite Group'
  end

  Factory.define(:favourite_group_membership) do |f|
    f.association :person
    f.association :favourite_group
    f.access_type 1
  end

  Factory.define(:organism) do |f|
    f.title "An Organism"
  end

  Factory.define(:event) do |f|
    f.title "An Event"
    f.start_date Time.now
    f.end_date 1.days.from_now
  end

  Factory.define(:saved_search) do |f|
    f.search_query "cheese"
    f.search_type "All"
    f.user :factory=>:user
    f.include_external_search false
  end

#Content_blob
#either url or data should be provided for assets
  Factory.define(:content_blob) do |f|
    f.sequence(:uuid) {|n| "uuid-#{n}"}
    f.sequence(:data) {|n| "data [#{n}]" }
  end

  Factory.define(:pdf_content_blob, :parent => :content_blob) do |f|
    f.original_filename "a_pdf_file.pdf"
    f.content_type "application/pdf"
    f.data  File.new("#{Rails.root}/test/fixtures/files/a_pdf_file.pdf","rb").read
  end
  
  Factory.define(:rightfield_content_blob,:parent=>:content_blob) do |f|
    f.content_type "application/excel"
    f.original_filename "rightfield.xls"
    f.data  File.new("#{Rails.root}/test/fixtures/files/rightfield-test.xls","rb").read
  end

  Factory.define(:spreadsheet_content_blob, :parent => :content_blob) do |f|
    f.content_type "application/excel"
    f.original_filename "test.xls"
  end

  Factory.define(:rightfield_annotated_content_blob,:parent=>:content_blob) do |f|
    f.data  File.new("#{Rails.root}/test/fixtures/files/simple_populated_rightfield.xls","rb").read
    f.content_type "application/excel"
  end

  Factory.define(:xlsx_content_blob,:parent=>:content_blob) do |f|
    f.content_type "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    f.data  File.new("#{Rails.root}/test/fixtures/files/lihua_column_index_error.xlsx","rb").read
  end

  Factory.define(:cronwright_model_content_blob,:parent=>:content_blob) do |f|
    f.content_type "text/xml"
    f.original_filename "cronwright.xml"
    f.data  File.new("#{Rails.root}/test/fixtures/files/cronwright.xml","rb").read
  end

  Factory.define(:teusink_model_content_blob,:parent=>:content_blob) do |f|
    f.content_type "text/xml"
    f.original_filename "teusink.xml"
    f.data  File.new("#{Rails.root}/test/fixtures/files/Teusink.xml","rb").read
  end

  Factory.define(:teusink_jws_model_content_blob,:parent=>:content_blob) do |f|
    f.data  File.new("#{Rails.root}/test/fixtures/files/Teusink2010921171725.dat","rb").read
    f.original_filename "teusink.dat"
  end

  Factory.define(:doc_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/ms_word_test.doc", "rb").read
    f.content_type 'application/msword'
  end

  Factory.define(:docx_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/ms_word_test.docx", "rb").read
    f.content_type "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  end

  Factory.define(:odt_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/openoffice_word_test.odt", "rb").read
    f.content_type 'application/vnd.oasis.opendocument.text'
  end

  Factory.define(:fodt_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/openoffice_word_test.fodt", "rb").read
    f.content_type "application/vnd.oasis.opendocument.text-flat-xml"
  end

  Factory.define(:ppt_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/ms_ppt_test.ppt", "rb").read
    f.content_type 'application/vnd.ms-powerpoint'
  end

  Factory.define(:pptx_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/ms_ppt_test.pptx", "rb").read
    f.content_type "application/vnd.openxmlformats-officedocument.presentationml.presentation"
  end

  Factory.define(:pps_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/ms_ppt_test.pps", "rb").read
    f.content_type "application/vnd.openxmlformats-officedocument.presentationml.presentation"
  end

  Factory.define(:odp_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/openoffice_ppt_test.odp", "rb").read
    f.content_type 'application/vnd.oasis.opendocument.presentation'
  end

  Factory.define(:fodp_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/openoffice_ppt_test.fodp", "rb").read
    f.content_type "application/vnd.oasis.opendocument.presentation-flat-xml"
  end

  Factory.define(:rtf_content_blob, :parent => :content_blob) do |f|
    f.data File.new("#{Rails.root}/test/fixtures/files/rtf_test.rtf", "rb").read
    f.content_type "application/rtf"
  end

  Factory.define(:activity_log) do |f|
    f.action "create"
    f.association :activity_loggable, :factory => :data_file
    f.controller_name "data_files"
    f.association :culprit, :factory => :user
  end

  #Factor studied
  Factory.define(:studied_factor) do |f|
    f.start_value 1
    f.end_value 10
    f.standard_deviation 2
    f.data_file_version 1
    f.association :measured_item, :factory => :measured_item
    f.association :unit, :factory => :unit
    f.studied_factor_links {[StudiedFactorLink.new(:substance => Factory(:compound))]}
    f.association :data_file, :factory => :data_file
  end

  Factory.define(:project_subscription) do |f|
    f.association :person
    f.association :project
  end

  Factory.define(:subscription) do |f|
    f.association :person
    f.association :subscribable
  end

  Factory.define(:subscribable, :parent => :data_file){}

  Factory.define(:notifiee_info) do |f|
    f.association :notifiee, :factory => :person
  end
    
  Factory.define(:measured_item) do |f|
    f.title 'concentration'
  end

  Factory.define(:unit) do |f|
    f.symbol 'g'
    f.sequence(:order) {|n| n}
  end

  Factory.define(:compound) do |f|
    f.sequence(:name) {|n| "glucose #{n}"}
  end

  Factory.define(:studied_factor_link) do |f|
    f.association :substance, :factory => :compound
    f.association :studied_factor
  end

  #Experimental condition
  Factory.define(:experimental_condition) do |f|
    f.start_value 1
    f.sop_version 1
    f.association :measured_item, :factory => :measured_item
    f.association :unit, :factory => :unit
    f.association :sop, :factory => :sop
    f.experimental_condition_links {[ExperimentalConditionLink.new(:substance => Factory(:compound))]}
  end

  Factory.define(:relationship) do |f|
    f.association :subject, :factory => :model
    f.association :object, :factory => :model
    f.predicate Relationship::ATTRIBUTED_TO
  end

  Factory.define(:attribution, :parent => :relationship) {}

  Factory.define(:special_auth_code) do |f|
    f.association :asset, :factory => :data_file
  end
  
  Factory.define(:experimental_condition_link) do |f|
    f.association :substance, :factory => :compound
    f.association :experimental_condition
  end

  Factory.define :synonym do |f|
    f.name "coffee"
    f.association :substance, :factory=>:compound
  end

  Factory.define :mapping_link do |f|
    f.association :substance, :factory=>:compound
    f.association :mapping,:factory=>:mapping
  end

  Factory.define :mapping do |f|
    f.chebi_id "12345"
    f.kegg_id "6789"
    f.sabiork_id "4"
  end

  Factory.define :site_announcement do |f|
    f.sequence(:title) {|n| "Announcement #{n}"}
    f.sequence(:body) {|n| "This is the body for announcement #{n}"}
    f.association :announcer,:factory=>:admin
    f.is_headline false
    f.expires_at 5.days.since
    f.email_notification false
  end

  Factory.define :headline_announcement,:parent=>:site_announcement do |f|
    f.is_headline true
  end

  Factory.define :annotation do |f|
    f.sequence(:value) {|n| "anno #{n}"}
    f.association :source, :factory=>:person
    f.attribute_name "annotation"
  end

  Factory.define :tag,:parent=>:annotation do |f|
    f.attribute_name "tag"
  end

  Factory.define :expertise,:parent=>:annotation do |f|
    f.attribute_name "expertise"
  end

  Factory.define :tool,:parent=>:annotation do |f|
    f.attribute_name "tool"
  end

  Factory.define :text_value do |f|
    f.sequence(:text) {|n| "value #{n}"}
  end

  Factory.define :assets_creator do |f|
    f.association :asset, :factory => :data_file
    f.association :creator, :factory => :person_in_project
  end

  Factory.define :project_folder do |f|
    f.association :project, :factory=>:project
    f.sequence(:title) {|n| "project folder #{n}"}
  end

  Factory.define :worksheet do |f|
    f.content_blob { Factory.build(:spreadsheet_content_blob, :asset => Factory(:data_file))}
    f.last_row 10
    f.last_column 10
  end

  Factory.define :cell_range do |f|
    f.cell_range "A1:B3"
    f.association :worksheet
  end


  Factory.define :genotype do |f|
    f.association :gene, :factory => :gene
    f.association :modification, :factory => :modification
    f.association :strain, :factory => :strain
    f.association :specimen,:factory => :specimen
  end

  Factory.define :gene do |f|
    f.sequence(:title) {|n| "gene #{n}"}
  end

  Factory.define :modification do |f|
    f.sequence(:title) {|n| "modification #{n}"}
  end

  Factory.define :phenotype do |f|
    f.sequence(:description) {|n| "phenotype #{n}"}
    f.association :strain, :factory => :strain
    f.association :specimen,:factory => :specimen
  end
