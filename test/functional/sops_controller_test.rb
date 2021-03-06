require 'test_helper'

class SopsControllerTest < ActionController::TestCase

  fixtures :all

  include AuthenticatedTestHelper
  include RestTestCases
  include SharingFormTestHelper

  def setup
    login_as(:quentin)
  end

  def rest_api_test_object
    @object=sops(:downloadable_sop)
  end

  def test_get_xml_specific_version
    login_as(:owner_of_my_first_sop)
    get :show, :id=>sops(:downloadable_sop), :version=>2, :format=>"xml"
    perform_api_checks
    xml          =@response.body
    document     = LibXML::XML::Document.string(xml)
    version_node = document.find_first("//ns:version", "ns:http://www.sysmo-db.org/2010/xml/rest")
    assert_not_nil version_node
    assert_equal "2", version_node.content
    content_blob_node = document.find_first("//ns:blob", "ns:http://www.sysmo-db.org/2010/xml/rest")
    assert_not_nil content_blob_node
    md5sum=content_blob_node.find_first("//ns:md5sum", "ns:http://www.sysmo-db.org/2010/xml/rest").content

    #now check version 1
    get :show, :id=>sops(:downloadable_sop), :version=>1, :format=>"xml"
    perform_api_checks
    xml          =@response.body
    document     = LibXML::XML::Document.string(xml)
    version_node = document.find_first("//ns:version", "ns:http://www.sysmo-db.org/2010/xml/rest")
    assert_not_nil version_node
    assert_equal "1", version_node.content
    content_blob_node = document.find_first("//ns:blob", "ns:http://www.sysmo-db.org/2010/xml/rest")
    assert_not_nil content_blob_node
    md5sum2=content_blob_node.find_first("//ns:md5sum", "ns:http://www.sysmo-db.org/2010/xml/rest").content
    assert_not_equal md5sum, md5sum2

  end

  test 'creators do not show in list item' do
    p1=Factory :person
    p2=Factory :person
    sop=Factory(:sop,:title=>"ZZZZZ",:creators=>[p2],:contributor=>p1.user,:policy=>Factory(:public_policy, :access_type=>Policy::VISIBLE))

    get :index,:page=>"Z"

    #check the test is behaving as expected:
    assert_equal p1.user,sop.contributor
    assert sop.creators.include?(p2)
    assert_select ".list_item_title a[href=?]",sop_path(sop),"ZZZZZ","the data file for this test should appear as a list item"

    #check for avatars
    assert_select ".list_item_avatar" do
      assert_select "a[href=?]",person_path(p2) do
        assert_select "img"
      end
      assert_select ["a[href=?]", person_path(p1)], 0
    end
  end

  test "request file button visibility when logged in and out" do

    sop = Factory :sop,:policy => Factory(:policy, :sharing_scope => Policy::EVERYONE, :access_type => Policy::VISIBLE)

    assert !sop.can_download?, "The SOP must not be downloadable for this test to succeed"

    get :show, :id => sop
    assert_response :success
    assert_select "#request_resource_button > a",:text=>/Request SOP/,:count=>1

    logout
    get :show, :id => sop
    assert_response :success
    assert_select "#request_resource_button > a",:text=>/Request SOP/,:count=>0
  end

  test "fail gracefullly when trying to access a missing sop" do
    get :show,:id=>99999
    assert_redirected_to sops_path
    assert_not_nil flash[:error]
  end

  test "should not create sop with file url" do
    file_path=File.expand_path(__FILE__) #use the current file
    file_url ="file://"+file_path
    uri      =URI.parse(file_url)

    assert_no_difference('Sop.count') do
      assert_no_difference('ContentBlob.count') do
        post :create, :sop => {:title=>"Test", :data_url=>uri.to_s}, :sharing=>valid_sharing
      end
    end
    assert_not_nil flash[:error]
  end

  def test_title
    get :index
    assert_select "title", :text=>/The Sysmo SEEK SOPs.*/, :count=>1
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sops)
  end

  test "shouldn't show hidden items in index" do
    login_as(:aaron)
    get :index, :page => "all"
    assert_response :success
    assert_equal assigns(:sops).sort_by(&:id), Sop.authorized_partial_asset_collection(assigns(:sops), "view", users(:aaron)).sort_by(&:id), "sops haven't been authorized properly"
  end

  test "should not show private sop to logged out user" do
    sop=Factory :sop
    logout
    get :show, :id=>sop
    assert_redirected_to sops_path
    assert_not_nil flash[:error]
    assert_equal "You are not authorized to view this SOP, you may need to login first.",flash[:error]
  end

  test "should not show private sop to another user" do
    sop=Factory :sop,:contributor=>Factory(:user)
    get :show, :id=>sop
    assert_redirected_to sops_path
    assert_not_nil flash[:error]
    assert_equal "You are not authorized to view this SOP.",flash[:error]
  end

  test "should get new" do
    get :new
    assert_response :success
    assert_select "h1", :text=>"New SOP"
  end

  test "should correctly handle bad data url" do
    sop={:title=>"Test", :data_url=>"http:/sdfsdfds.com/sdf.png",:projects=>[projects(:sysmo_project)]}
    assert_no_difference('Sop.count') do
      assert_no_difference('ContentBlob.count') do
        post :create, :sop => sop, :sharing=>valid_sharing
      end
    end
    assert_not_nil flash.now[:error]

    #not even a valid url
    sop={:title=>"Test", :data_url=>"s  df::sd:dfds.com/sdf.png",:projects=>[projects(:sysmo_project)]}
    assert_no_difference('Sop.count') do
      assert_no_difference('ContentBlob.count') do
        post :create, :sop => sop, :sharing=>valid_sharing
      end
    end
    assert_not_nil flash.now[:error]
  end

  test "should not create invalid sop" do
    sop={:title=>"Test",:projects=>[projects(:sysmo_project)]}
    assert_no_difference('Sop.count') do
      assert_no_difference('ContentBlob.count') do
        post :create, :sop => sop, :sharing=>valid_sharing
      end
    end
    assert_not_nil flash.now[:error]
  end

  test "associates assay" do
    login_as(:owner_of_my_first_sop) #can edit assay_can_edit_by_my_first_sop_owner
    s = sops(:my_first_sop)
    original_assay = assays(:assay_can_edit_by_my_first_sop_owner1)
    asset_ids = original_assay.related_asset_ids 'Sop'
    assert asset_ids.include? s.id

    new_assay=assays(:assay_can_edit_by_my_first_sop_owner2)
    new_asset_ids = new_assay.related_asset_ids 'Sop'
    assert !new_asset_ids.include?(s.id)

    put :update, :id => s.id, :sop =>{}, :assay_ids=>[new_assay.id.to_s]

    assert_redirected_to sop_path(s)

    s.reload
    original_assay.reload
    new_assay.reload

    assert !original_assay.related_asset_ids('Sop').include?(s.id)
    assert new_assay.related_asset_ids('Sop').include?(s.id)
  end

  test "associate sample" do
     # assign to a new sop
     sop_with_samples = valid_sop
     sop_with_samples[:sample_ids] = [Factory(:sample,:title=>"newTestSample",:contributor=> User.current_user).id]

     assert_difference("Sop.count") do
       post :create,:sop => sop_with_samples, :sharing => valid_sharing
       puts assigns(:sop).errors.full_messages
       puts assigns(:sop).valid?
     end

    s = assigns(:sop)
    assert_equal "newTestSample",s.samples.first.title

    #edit associations of samples to an existing sop
    put :update,:id=> s.id, :sop => {:sample_ids=> [Factory(:sample,:title=>"editTestSample",:contributor=> User.current_user).id]}
    s = assigns(:sop)
    assert_equal "editTestSample", s.samples.first.title
  end

  test "should create sop" do
    login_as(:owner_of_my_first_sop) #can edit assay_can_edit_by_my_first_sop_owner
    assay=assays(:assay_can_edit_by_my_first_sop_owner1)
    assert_difference('Sop.count') do
      assert_difference('ContentBlob.count') do
        post :create, :sop => valid_sop, :sharing=>valid_sharing, :assay_ids => [assay.id.to_s]
      end
    end

    assert_redirected_to sop_path(assigns(:sop))
    assert_equal users(:owner_of_my_first_sop), assigns(:sop).contributor

    assert assigns(:sop).content_blob.url.blank?
    assert !assigns(:sop).content_blob.data_io_object.read.nil?
    assert assigns(:sop).content_blob.file_exists?
    assert_equal "file_picture.png", assigns(:sop).content_blob.original_filename
    assay.reload
    assert assay.related_asset_ids('Sop').include? assigns(:sop).id
  end

  def test_missing_sharing_should_not_default
    assert_no_difference('Sop.count') do
      assert_no_difference('ContentBlob.count') do
        post :create, :sop => valid_sop
      end
    end
    s = assigns(:sop)
    assert !s.valid?
    assert !s.policy.valid?
    assert_blank s.policy.sharing_scope
    assert_blank s.policy.access_type
  end

  test "should create sop with url" do
    assert_difference('Sop.count') do
      assert_difference('ContentBlob.count') do
        post :create, :sop => valid_sop_with_url.tap {|sop| sop[:external_link] = "1"}, :sharing=>valid_sharing
      end
    end
    assert_redirected_to sop_path(assigns(:sop))
    assert_equal users(:quentin), assigns(:sop).contributor
    assert !assigns(:sop).content_blob.url.blank?
    assert assigns(:sop).content_blob.data_io_object.nil?
    assert !assigns(:sop).content_blob.file_exists?
    assert_equal "sysmo-db-logo-grad2.png", assigns(:sop).content_blob.original_filename
    assert_equal "image/png", assigns(:sop).content_blob.content_type
  end

  test "should create sop and store with url and store flag" do
    sop_details=valid_sop_with_url

    assert_difference('Sop.count') do
      assert_difference('ContentBlob.count') do
        post :create, :sop => sop_details, :sharing=>valid_sharing
      end
    end
    assert_redirected_to sop_path(assigns(:sop))
    assert_equal users(:quentin), assigns(:sop).contributor
    assert !assigns(:sop).content_blob.url.blank?
    assert !assigns(:sop).content_blob.data_io_object.read.nil?
    assert assigns(:sop).content_blob.file_exists?
    assert_equal "sysmo-db-logo-grad2.png", assigns(:sop).content_blob.original_filename
    assert_equal "image/png", assigns(:sop).content_blob.content_type
  end

  test "should show sop" do
    login_as(:owner_of_my_first_sop)
    s=Factory :pdf_sop,:policy=>Factory(:public_policy)

    assert_difference('ActivityLog.count') do
      get :show, :id => s.id
    end

    assert_response :success
    assert_select "div.box_about_actor" do
      assert_select "p > b",:text=>/Filename:/
      assert_select "p",:text=>/a_pdf_file\.pdf/
      assert_select "p > b",:text=>/Format:/
      assert_select "p",:text=>/PDF document/
      assert_select "p > b",:text=>/Size:/
      assert_select "p",:text=>/8.8 KB/
    end

    al = ActivityLog.last
    assert_equal "show",al.action
    assert_equal User.current_user,al.culprit
    assert_equal s,al.activity_loggable
    assert_equal "Rails Testing",al.user_agent
  end

  test "should get edit" do
    login_as(:owner_of_my_first_sop)
    get :edit, :id => sops(:my_first_sop)
    assert_response :success
    assert_select "h1", :text=>/Editing SOP/

    #this is to check the SOP is all upper case in the sharing form
    assert_select "label",:text=>/Keep this SOP private/
  end

  test "publications excluded in form for sops" do
    login_as(:owner_of_my_first_sop)
    get :edit, :id => sops(:my_first_sop)
    assert_response :success
    assert_select "div#publications_fold_content", false

    get :new
    assert_response :success
    assert_select "div#publications_fold_content", false
  end

  test "should update sop" do
    login_as(:owner_of_my_first_sop)
    put :update, :id => sops(:my_first_sop).id, :sop => {:title=>"Test2"}, :sharing=>valid_sharing
    assert_redirected_to sop_path(assigns(:sop))
  end


  test "should destroy sop" do
    login_as(:owner_of_my_first_sop)
    assert_difference('Sop.count', -1) do
      assert_no_difference("ContentBlob.count") do
        delete :destroy, :id => sops(:my_first_sop)
      end

    end
    assert_redirected_to sops_path
  end


  test "should not be able to edit exp conditions for downloadable only sop" do
    s=sops(:downloadable_sop)

    get :show, :id=>s
    assert_select "a", :text=>/Edit experimental conditions/, :count=>0
  end

  def test_should_be_able_to_edit_exp_conditions_for_owners_downloadable_only_sop
    login_as(:owner_of_my_first_sop)
    s=sops(:downloadable_sop)

    get :show, :id=>s
    assert_select "a", :text=>/Edit experimental conditions/, :count=>1
  end

  def test_should_be_able_to_edit_exp_conditions_for_editable_sop
    s=sops(:editable_sop)

    get :show, :id=>sops(:editable_sop)
    assert_select "a", :text=>/Edit experimental conditions/, :count=>1
  end

  def test_should_show_version
    s = sops(:editable_sop)

    #!!!description cannot be changed in new version but revision comments and file name,etc


    #create new version
    post :new_version, :id=>s, :sop=>{:data=>fixture_file_upload('files/little_file_v2.txt',Mime::TEXT)}
    assert_redirected_to sop_path(assigns(:s))

    s=Sop.find(s.id)
    assert_equal 2, s.versions.size
    assert_equal 2, s.version
    assert_equal 1, s.versions[0].version
    assert_equal 2, s.versions[1].version

    get :show, :id=>sops(:editable_sop)
    assert_select "p", :text=>/little_file_v2.txt/, :count=>1
    assert_select "p", :text=>/little_file.txt/, :count=>0

    get :show, :id=>sops(:editable_sop), :version=>"2"
    assert_select "p", :text=>/little_file_v2.txt/, :count=>1
    assert_select "p", :text=>/little_file.txt/, :count=>0

    get :show, :id=>sops(:editable_sop), :version=>"1"
    assert_select "p", :text=>/little_file_v2.txt/, :count=>0
    assert_select "p", :text=>/little_file.txt/, :count=>1

  end

  test "should download SOP from standard route" do
    sop = Factory :doc_sop, :policy=>Factory(:public_policy)
    login_as(sop.contributor.user)
    assert_difference("ActivityLog.count") do
      get :download, :id=>sop.id
    end
    assert_response :success
    al=ActivityLog.last
    assert_equal "download",al.action
    assert_equal sop,al.activity_loggable
    assert_equal "attachment; filename=\"ms_word_test.doc\"",@response.header['Content-Disposition']
    assert_equal "application/msword",@response.header['Content-Type']
    assert_equal "9216",@response.header['Content-Length']
  end

  def test_should_create_new_version
    s=sops(:editable_sop)

    assert_difference("Sop::Version.count", 1) do
      post :new_version, :id=>s, :sop=>{:data=>fixture_file_upload('files/file_picture.png')}, :revision_comment=>"This is a new revision"
    end

    assert_redirected_to sop_path(s)
    assert assigns(:sop)
    assert_not_nil flash[:notice]
    assert_nil flash[:error]

    s=Sop.find(s.id)
    assert_equal 2, s.versions.size
    assert_equal 2, s.version
    assert_equal "file_picture.png", s.content_blob.original_filename
    assert_equal "file_picture.png", s.versions[1].content_blob.original_filename
    assert_equal "little_file.txt", s.versions[0].content_blob.original_filename
    assert_equal "This is a new revision", s.versions[1].revision_comments

  end

  def test_should_not_create_new_version_for_downloadable_only_sop
    s                    =sops(:downloadable_sop)
    current_version      =s.version
    current_version_count=s.versions.size

    assert_no_difference("Sop::Version.count") do
      post :new_version, :id=>s, :data=>fixture_file_upload('files/file_picture.png'), :revision_comment=>"This is a new revision"
    end

    assert_redirected_to sop_path(s)
    assert_not_nil flash[:error]

    s=Sop.find(s.id)
    assert_equal current_version_count, s.versions.size
    assert_equal current_version, s.version

  end

  def test_should_duplicate_conditions_for_new_version
    s=sops(:editable_sop)
    condition1 = ExperimentalCondition.create(:unit        => units(:gram), :measured_item => measured_items(:weight),
                                              :start_value => 1, :sop_id => s.id, :sop_version => s.version)
    assert_difference("Sop::Version.count", 1) do
      post :new_version, :id=>s, :sop=>{:data=>fixture_file_upload('files/file_picture.png')}, :revision_comment=>"This is a new revision" #v2
    end

    assert_not_equal 0, s.find_version(1).experimental_conditions.count
    assert_not_equal 0, s.find_version(2).experimental_conditions.count
    assert_not_equal s.find_version(1).experimental_conditions, s.find_version(2).experimental_conditions
  end

  def test_adding_new_conditions_to_different_versions
    s =sops(:editable_sop)
    condition1 = ExperimentalCondition.create(:unit => units(:gram), :measured_item => measured_items(:weight),
                                              :start_value => 1, :sop_id => s.id, :sop_version => s.version)
    assert_difference("Sop::Version.count", 1) do
      post :new_version, :id=>s, :sop=>{:data=>fixture_file_upload('files/file_picture.png')}, :revision_comment=>"This is a new revision" #v2
    end

    s.find_version(2).experimental_conditions.each { |e| e.destroy }
    assert_equal condition1, s.find_version(1).experimental_conditions.first
    assert_equal 0, s.find_version(2).experimental_conditions.count

    condition2 = ExperimentalCondition.create(:unit => units(:gram), :measured_item => measured_items(:weight),
                                              :start_value => 2, :sop_id => s.id, :sop_version => 2)

    assert_not_equal 0, s.find_version(2).experimental_conditions.count
    assert_equal condition2, s.find_version(2).experimental_conditions.first
    assert_not_equal condition2, s.find_version(1).experimental_conditions.first
    assert_equal condition1, s.find_version(1).experimental_conditions.first
  end

  def test_should_add_nofollow_to_links_in_show_page
    get :show, :id=> sops(:sop_with_links_in_description)
    assert_select "div#description" do
      assert_select "a[rel=nofollow]"
    end
  end

  def test_can_display_sop_with_no_contributor
    get :show, :id=>sops(:sop_with_no_contributor)
    assert_response :success
  end

  def test_can_show_edit_for_sop_with_no_contributor
    get :edit, :id=>sops(:sop_with_no_contributor)
    assert_response :success
  end

  def test_editing_doesnt_change_contributor
    login_as(:pal_user) #this user is a member of sysmo, and can edit this sop
    sop=sops(:sop_with_no_contributor)
    put :update, :id => sop, :sop => {:title=>"blah blah blah"}, :sharing=>valid_sharing
    updated_sop=assigns(:sop)
    assert_redirected_to sop_path(updated_sop)
    assert_equal "blah blah blah", updated_sop.title, "Title should have been updated"
    assert_nil updated_sop.contributor, "contributor should still be nil"
  end

  test "filtering by assay" do
    assay=assays(:metabolomics_assay)
    get :index, :filter => {:assay => assay.id}
    assert_response :success
  end

  test "filtering by study" do
    study=studies(:metabolomics_study)
    get :index, :filter => {:study => study.id}
    assert_response :success
  end

  test "filtering by investigation" do
    inv=investigations(:metabolomics_investigation)
    get :index, :filter => {:investigation => inv.id}
    assert_response :success
  end

  test "filtering by project" do
    project=projects(:sysmo_project)
    get :index, :filter => {:project => project.id}
    assert_response :success
  end

  test "filtering by person" do
    login_as(:owner_of_my_first_sop)
    person = people(:person_for_owner_of_my_first_sop)
    p = projects(:sysmo_project)
    get :index, :filter=>{:person=>person.id}, :page=>"all"
    assert_response :success
    sop  = sops(:downloadable_sop)
    sop2 = sops(:sop_with_fully_public_policy)
    assert_select "div.list_items_container" do
      assert_select "a", :text=>sop.title, :count=>1
      assert_select "a", :text=>sop2.title, :count=>0
    end
  end

  test "should not be able to update sharing without manage rights" do
    login_as(:quentin)
    user = users(:quentin)
    sop   = sops(:sop_with_all_sysmo_users_policy)

    assert sop.can_edit?(user), "sop should be editable but not manageable for this test"
    assert !sop.can_manage?(user), "sop should be editable but not manageable for this test"
    assert_equal Policy::EDITING, sop.policy.access_type, "data file should have an initial policy with access type for editing"
    put :update, :id => sop, :sop => {:title=>"new title"}, :sharing=>{:use_whitelist=>"0", :user_blacklist=>"0", :sharing_scope =>Policy::ALL_SYSMO_USERS, "access_type_#{Policy::ALL_SYSMO_USERS}"=>Policy::NO_ACCESS}
    assert_redirected_to sop_path(sop)
    sop.reload

    assert_equal "new title", sop.title
    assert_equal Policy::EDITING, sop.policy.access_type, "policy should not have been updated"

  end

  test "owner should be able to update sharing" do
    user = Factory(:user)
    login_as(user)

    sop = Factory :sop, :contributor => User.current_user, :policy => Factory(:policy, :sharing_scope => Policy::ALL_SYSMO_USERS, :access_type => Policy::EDITING)

    put :update, :id => sop, :sop => {:title=>"new title"}, :sharing=>{:use_whitelist=>"0", :user_blacklist=>"0", :sharing_scope =>Policy::ALL_SYSMO_USERS, "access_type_#{Policy::ALL_SYSMO_USERS}"=>Policy::NO_ACCESS}
    assert_redirected_to sop_path(sop)
    sop.reload

    assert_equal "new title", sop.title
    assert_equal Policy::NO_ACCESS, sop.policy.access_type, "policy should have been updated"
  end

  test "do publish" do
    login_as(:owner_of_my_first_sop)
    sop=sops(:sop_with_project_without_gatekeeper)
    assert sop.can_manage?,"The sop must be manageable for this test to succeed"
    post :publish,:id=>sop
    assert_response :success
    assert_nil flash[:error]
    assert_not_nil flash[:notice]
  end

  test "do not publish if not can_manage?" do
    sop=sops(:sop_with_project_without_gatekeeper)
    assert !sop.can_manage?,"The sop must not be manageable for this test to succeed"
    post :publish,:id=>sop
    assert_redirected_to sop
    assert_not_nil flash[:error]
    assert_nil flash[:notice]
  end

  test "get preview_publish" do
    login_as(:owner_of_my_first_sop)
    sop=sops(:sop_with_project_without_gatekeeper)
    assert sop.can_manage?,"The sop must be manageable for this test to succeed"
    get :preview_publish, :id=>sop
    assert_response :success
  end

  test "cannot get preview_publish when not manageable" do
    sop=sops(:my_first_sop)
    assert !sop.can_manage?,"The sop must not be manageable for this test to succeed"
    get :preview_publish, :id=>sop
    assert_redirected_to sop
    assert flash[:error]
  end

  test 'should show <Not specified> for  other creators if no other creators' do
    get :index
    assert_response :success
    no_other_creator_sops = assigns(:sops).select { |s| s.other_creators.blank? }
    assert_select 'p.list_item_attribute', :text => /Other contributors: Not specified/, :count => no_other_creator_sops.count
  end

  test 'breadcrumb for sop index' do
    get :index
    assert_response :success
    assert_select "div.breadcrumbs", :text => /Home > SOPs Index/, :count => 1 do
      assert_select "a[href=?]", root_path, :count => 1
    end
  end

  test 'breadcrumb for showing sop' do
    sop = sops(:sop_with_fully_public_policy)
    get :show, :id => sop
    assert_response :success
    assert_select "div.breadcrumbs", :text => /Home > SOPs Index > #{sop.title}/, :count => 1 do
      assert_select "a[href=?]", root_path, :count => 1
       assert_select "a[href=?]", sops_url, :count => 1
    end
  end

  test 'breadcrumb for editing sop' do
    sop = sops(:sop_with_all_sysmo_users_policy)
    assert sop.can_edit?
    get :edit, :id => sop
    assert_response :success
    assert_select "div.breadcrumbs", :text => /Home > SOPs Index > #{sop.title} > Edit/, :count => 1 do
      assert_select "a[href=?]", root_path, :count => 1
      assert_select "a[href=?]", sops_url, :count => 1
      assert_select "a[href=?]", sop_url(sop), :count => 1
    end
  end

  test 'breadcrumb for creating new sop' do
    get :new
    assert_response :success
    assert_select "div.breadcrumbs", :text => /Home > SOPs Index > New/, :count => 1 do
      assert_select "a[href=?]", root_path, :count => 1
      assert_select "a[href=?]", sops_url, :count => 1
    end
  end

  test "should set the policy to sysmo_and_projects if the item is requested to be published, when creating new sop" do
    as_not_virtualliver do
      gatekeeper = Factory(:gatekeeper)
      post :create, :sop => {:title => 'test', :projects => gatekeeper.projects, :data => fixture_file_upload('files/file_picture.png')}, :sharing => {:sharing_scope => Policy::EVERYONE, "access_type_#{Policy::EVERYONE}" => Policy::VISIBLE}
      sop = assigns(:sop)
      assert_redirected_to (sop)
      policy = sop.policy
      assert_equal Policy::ALL_SYSMO_USERS, policy.sharing_scope
      assert_equal Policy::VISIBLE, policy.access_type
      assert_equal 1, policy.permissions.count
      assert_equal gatekeeper.projects.first, policy.permissions.first.contributor
      assert_equal Policy::ACCESSIBLE, policy.permissions.first.access_type
    end
  end

  test "should not change the policy if the item is requested to be published, when managing sop" do
      gatekeeper = Factory(:gatekeeper)
      policy = Factory(:policy, :sharing_scope => Policy::PRIVATE, :permissions => [Factory(:permission)])
      sop = Factory(:sop, :projects => gatekeeper.projects, :policy => policy)
      login_as(sop.contributor)
      assert sop.can_manage?
      put :update, :id => sop.id, :sop =>{}, :sharing => {:sharing_scope => Policy::EVERYONE, "access_type_#{Policy::EVERYONE}" => Policy::VISIBLE}
      sop = assigns(:sop)
      assert_redirected_to(sop)
      updated_policy = sop.policy
      assert_equal policy, updated_policy
      assert_equal policy.permissions, updated_policy.permissions
  end

  test 'should be able to view pdf content' do
     sop = Factory(:sop, :policy => Factory(:all_sysmo_downloadable_policy))
     assert sop.content_blob.is_content_viewable?
     get :show, :id => sop.id
     assert_response :success
     assert_select 'a', :text => /View content/, :count => 1
  end

  test 'should be able to view ms/open office word content' do
     ms_word_sop = Factory(:doc_sop, :policy => Factory(:all_sysmo_downloadable_policy))
     content_blob = ms_word_sop.content_blob
     pdf_filepath = content_blob.filepath('pdf')
     FileUtils.rm pdf_filepath if File.exist?(pdf_filepath)
     assert content_blob.is_content_viewable?
     get :show, :id => ms_word_sop.id
     assert_response :success
     assert_select 'a', :text => /View content/, :count => 1

     openoffice_word_sop = Factory(:odt_sop, :policy => Factory(:all_sysmo_downloadable_policy))
     assert openoffice_word_sop.content_blob.is_content_viewable?
     get :show, :id => openoffice_word_sop.id
     assert_response :success
     assert_select 'a', :text => /View content/, :count => 1
  end

  test 'should disappear view content button for the document needing pdf conversion, when pdf_conversion_enabled is false' do
    tmp = Seek::Config.pdf_conversion_enabled
    Seek::Config.pdf_conversion_enabled = false

    ms_word_sop = Factory(:doc_sop, :policy => Factory(:all_sysmo_downloadable_policy))
    content_blob = ms_word_sop.content_blob
    pdf_filepath = content_blob.filepath('pdf')
    FileUtils.rm pdf_filepath if File.exist?(pdf_filepath)
    assert !content_blob.is_content_viewable?
    get :show, :id => ms_word_sop.id
    assert_response :success
    assert_select 'a', :text => /View content/, :count => 0

    Seek::Config.pdf_conversion_enabled = tmp
  end

  test 'duplicated logs are NOT created by uploading new version' do
    assert_difference('ActivityLog.count', 1) do
      assert_difference('Sop.count', 1) do
        post :create, :sop => valid_sop, :sharing => valid_sharing
      end
    end
    al1= ActivityLog.last
    s=assigns(:sop)
    assert_difference('ActivityLog.count', 1) do
      assert_difference("Sop::Version.count", 1) do
        post :new_version, :id => s, :sop => {:data => fixture_file_upload('files/file_picture.png')}, :revision_comment => "This is a new revision"
      end
    end
    al2=ActivityLog.last
    assert_equal al1.activity_loggable, al2.activity_loggable
    assert_equal al1.culprit, al2.culprit
    assert_equal 'create', al1.action
    assert_equal 'update', al2.action
  end

  test 'should not create duplication sop_versions_projects when uploading new version' do
    sop = Factory(:sop)
    login_as(sop.contributor)
    post :new_version, :id => sop, :sop => {:data => fixture_file_upload('files/file_picture.png')}, :revision_comment => "This is a new revision"

    sop.reload
    assert_equal 2, sop.versions.count
    assert_equal 1, sop.latest_version.projects.count
  end

  test 'should not create duplication sop_versions_projects when uploading sop' do
    post :create, :sop => valid_sop, :sharing => valid_sharing

    sop = assigns(:sop)
    assert_equal 1, sop.versions.count
    assert_equal 1, sop.latest_version.projects.count
  end

  test "should destroy all versions related when destroying sop" do
    sop = Factory(:sop)
    assert_equal 1, sop.versions.count
    sop_version = sop.latest_version
    assert_equal 1, sop_version.projects.count
    project_sop_version = sop_version.projects.first

    login_as(sop.contributor)
    delete :destroy, :id => sop
    assert_nil Sop::Version.find_by_id(sop_version.id)
    sql = "select * from projects_sop_versions where project_id = #{project_sop_version.id} and version_id = #{sop_version.id}"
    assert ActiveRecord::Base.connection.select_all(sql).empty?
  end

  private

  def valid_sop_with_url
    mock_remote_file "#{Rails.root}/test/fixtures/files/file_picture.png","http://www.sysmo-db.org/images/sysmo-db-logo-grad2.png"
    {:title=>"Test", :data_url=>"http://www.sysmo-db.org/images/sysmo-db-logo-grad2.png",:projects=>[projects(:sysmo_project)]}
  end

  def valid_sop
    {:title=>"Test", :data=>fixture_file_upload('files/file_picture.png'),:projects=>[projects(:sysmo_project)]}
  end

end
