require 'test_helper'

class SopTest < ActiveSupport::TestCase
  fixtures :all
  
  test "project" do
    s=sops(:editable_sop)
    p=projects(:sysmo_project)
    assert_equal p,s.projects.first
  end

  test "sort by updated_at" do
    last = 9999999999999 #safe until the year 318857 !

    Sop.record_timestamps = false
    Factory(:sop,:title=>"8 day old SOP",:updated_at=>8.day.ago)
    Factory(:sop,:title=>"20 day old SOP",:updated_at=>20.days.ago)
    Sop.record_timestamps = true
    
    sops = Sop.find(:all)

    sops.each do |sop|
      assert sop.updated_at.to_i <= last
      last=sop.updated_at.to_i
    end
  end

  def test_title_trimmed 
    sop=Factory(:sop, :title => " test sop")
    assert_equal("test sop",sop.title)
  end

  test "validation" do
    asset=Sop.new :title=>"fred",:projects=>[projects(:sysmo_project)]
    assert asset.valid?

    asset=Sop.new :projects=>[projects(:sysmo_project)]
    assert !asset.valid?

    asset=Sop.new :title=>"fred"
    assert !asset.valid?
  end

  test "assay association" do
    sop = sops(:sop_with_fully_public_policy)
    assay = assays(:modelling_assay_with_data_and_relationship)
    assay_asset = assay_assets(:metabolomics_assay_asset1)
    assert_not_equal assay_asset.asset, sop
    assert_not_equal assay_asset.assay, assay
    assay_asset.asset = sop
    assay_asset.assay = assay
    User.with_current_user(assay.contributor.user){assay_asset.save!}
    assay_asset.reload
    assert assay_asset.valid?
    assert_equal assay_asset.asset, sop
    assert_equal assay_asset.assay, assay

  end

  def test_avatar_key
    assert_nil sops(:editable_sop).avatar_key
    assert sops(:editable_sop).use_mime_type_for_avatar?

    assert_nil sop_versions(:my_first_sop_v1).avatar_key
    assert sop_versions(:my_first_sop_v1).use_mime_type_for_avatar?
  end
  
  def test_defaults_to_private_policy
    sop=Sop.new Factory.attributes_for(:sop).tap{|h|h[:policy] = nil}
    sop.save!
    sop.reload
    assert_not_nil sop.policy
    assert_equal Policy::PRIVATE, sop.policy.sharing_scope
    assert_equal Policy::NO_ACCESS, sop.policy.access_type
    assert_equal false,sop.policy.use_whitelist
    assert_equal false,sop.policy.use_blacklist
    assert sop.policy.permissions.empty?
  end

  def test_version_created_for_new_sop

    sop=Factory(:sop)

    assert sop.save

    sop=Sop.find(sop.id)

    assert 1,sop.version
    assert 1,sop.versions.size
    assert_equal sop,sop.versions.last.sop
    assert_equal sop.title,sop.versions.first.title

  end

  #really just to test the fixtures for versions, but may as well leave here.
  def test_version_from_fixtures
    sop_version=sop_versions(:my_first_sop_v1)
    assert_equal 1,sop_version.version
    assert_equal users(:owner_of_my_first_sop),sop_version.contributor
    assert_equal content_blobs(:content_blob_with_little_file2),sop_version.content_blob

    sop=sops(:my_first_sop)
    assert_equal sop.id,sop_version.sop_id

    assert_equal 1,sop.version
    assert_equal sop.title,sop.versions.first.title

  end  

  def test_create_new_version
    sop=sops(:my_first_sop)
    User.current_user = sop.contributor
    sop.save!
    sop=Sop.find(sop.id)
    assert_equal 1,sop.version
    assert_equal 1,sop.versions.size
    assert_equal "My First Favourite SOP",sop.title

    sop.save!
    sop=Sop.find(sop.id)

    assert_equal 1,sop.version
    assert_equal 1,sop.versions.size
    assert_equal "My First Favourite SOP",sop.title

    sop.title="Updated Sop"

    sop.save_as_new_version("Updated sop as part of a test")
    sop=Sop.find(sop.id)
    assert_equal 2,sop.version
    assert_equal 2,sop.versions.size
    assert_equal "Updated Sop",sop.title
    assert_equal "Updated Sop",sop.versions.last.title
    assert_equal "Updated sop as part of a test",sop.versions.last.revision_comments
    assert_equal "My First Favourite SOP",sop.versions.first.title

    assert_equal "My First Favourite SOP",sop.find_version(1).title
    assert_equal "Updated Sop",sop.find_version(2).title

  end

  def test_project_for_sop_and_sop_version_match
    sop=sops(:my_first_sop)
    project=projects(:sysmo_project)
    assert_equal project,sop.projects.first
    assert_equal project,sop.latest_version.projects.first
  end

  test "sop with no contributor" do
    sop=sops(:sop_with_no_contributor)
    assert_nil sop.contributor
  end

  test "versions destroyed as dependent" do
    sop = sops(:my_first_sop)
    assert_equal 1,sop.versions.size,"There should be 1 version of this SOP"   
    assert_difference(["Sop.count","Sop::Version.count"],-1) do
      User.current_user = sop.contributor
      sop.destroy
    end    
  end

  test "make sure content blob is preserved after deletion" do
    sop = sops(:my_first_sop)
    assert_not_nil sop.content_blob,"Must have an associated content blob for this test to work"
    cb=sop.content_blob
    assert_difference("Sop.count",-1) do
      assert_no_difference("ContentBlob.count") do
        User.current_user = sop.contributor
        sop.destroy
      end
    end
    assert_not_nil ContentBlob.find(cb.id)
  end

  test "is restorable after destroy" do
    sop = Factory :sop, :policy => Factory(:all_sysmo_viewable_policy), :title => 'is it restorable?'
    User.current_user = sop.contributor
    assert_difference("Sop.count",-1) do
      sop.destroy
    end
    assert_nil Sop.find_by_title 'is it restorable?'
    assert_difference("Sop.count",1) do
      disable_authorization_checks {Sop.restore_trash!(sop.id)}
    end
    assert_not_nil Sop.find_by_title 'is it restorable?'
  end

  test 'failing to delete due to can_delete does not create trash' do
    sop = Factory :sop, :policy => Factory(:private_policy)
    assert_no_difference("Sop.count") do
      sop.destroy
    end
    assert_nil Sop.restore_trash(sop.id)
  end

  test "test uuid generated" do
    x = sops(:my_first_sop)
    assert_nil x.attributes["uuid"]
    x.save
    assert_not_nil x.attributes["uuid"]
  end
  
  test "uuid doesn't change" do
    x = sops(:my_first_sop)
    x.save
    uuid = x.attributes["uuid"]
    x.save
    assert_equal x.uuid, uuid
  end

  test "contributing_user" do
    sop = Factory :sop
    assert sop.contributor
    assert_equal sop.contributor, sop.contributing_user
    sop_without_contributor = Factory :sop, :contributor => nil
    assert_equal nil, sop_without_contributor.contributing_user
  end

  test 'is_downloadable_pdf?' do
    sop_with_pdf_format = Factory(:sop, :content_blob => Factory(:content_blob, :content_type=>"application/pdf", :data => File.new("#{Rails.root}/test/fixtures/files/a_pdf_file.pdf","rb").read))
    User.with_current_user sop_with_pdf_format.contributor do
      assert sop_with_pdf_format.is_pdf?
      assert sop_with_pdf_format.is_downloadable_pdf?
    end
    sop_with_no_pdf_format = Factory(:sop, :content_blob => Factory(:content_blob, :content_type=>"text/plain", :data => File.new("#{Rails.root}/test/fixtures/files/little_file.txt","rb").read))
    User.with_current_user sop_with_no_pdf_format.contributor do
      assert !sop_with_no_pdf_format.is_pdf?
      assert !sop_with_no_pdf_format.is_downloadable_pdf?
    end
  end

  test 'is_content_viewable?' do
    viewable_formats= %w[application/pdf]
    viewable_formats << "application/msword"
    viewable_formats << "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    viewable_formats << "application/vnd.ms-powerpoint"
    viewable_formats << "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    viewable_formats << "application/vnd.oasis.opendocument.text"
    viewable_formats << "application/vnd.oasis.opendocument.text-flat-xml"
    viewable_formats << "application/vnd.oasis.opendocument.presentation"
    viewable_formats << "application/vnd.oasis.opendocument.presentation-flat-xml"
    viewable_formats << "application/rtf"

    viewable_formats.each do |viewable_format|
      sop_with_content_viewable_format = Factory(:sop, :content_blob => Factory(:content_blob, :content_type=>viewable_format, :data => File.new("#{Rails.root}/test/fixtures/files/a_pdf_file.pdf","rb").read))
      User.with_current_user sop_with_content_viewable_format.contributor do
        assert sop_with_content_viewable_format.is_viewable_format?
        assert sop_with_content_viewable_format.is_content_viewable?
      end
    end
    sop_with_no_viewable_format = Factory(:sop, :content_blob => Factory(:content_blob, :content_type=>"text/plain", :data => File.new("#{Rails.root}/test/fixtures/files/little_file.txt","rb").read))
    User.with_current_user sop_with_no_viewable_format.contributor do
       assert !sop_with_no_viewable_format.is_viewable_format?
       assert !sop_with_no_viewable_format.is_content_viewable?
    end
  end

  test 'filter_text_content' do
    ms_word_sop = Factory(:doc_sop)
    content = "test \n content \f only"
    filtered_content = ms_word_sop.send(:filter_text_content,content)
    assert !filtered_content.include?('\n')
    assert !filtered_content.include?('\f')
  end

  test 'pdf_contents_for_search' do
    ms_word_sop = Factory(:doc_sop)
    assert ms_word_sop.is_viewable_format?
    content = ms_word_sop.pdf_contents_for_search
    assert_equal 'This is a ms word doc format', content
  end
end
