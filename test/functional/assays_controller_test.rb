require 'test_helper'


class AssaysControllerTest < ActionController::TestCase
  fixtures :all

  include AuthenticatedTestHelper
  include RestTestCases
  include SharingFormTestHelper

  def setup
    login_as(:quentin)
    @object=Factory(:experimental_assay, :policy => Factory(:public_policy))
  end


  test "modelling assay validates with schema" do
    a=assays(:modelling_assay_with_data_and_relationship)
    User.with_current_user(a.study.investigation.contributor) { a.study.investigation.projects << Factory(:project) }
    assert_difference('ActivityLog.count') do
      get :show, :id=>a, :format=>"xml"
    end

    assert_response :success

    validate_xml_against_schema(@response.body)

  end

  test "check SOP and DataFile drop down contents" do
    user = Factory :user
    project=user.person.projects.first
    login_as user
    sop = Factory :sop, :contributor=>user.person,:projects=>[project]
    data_file = Factory :data_file, :contributor=>user.person,:projects=>[project]
    get :new, :class=>"experimental"
    assert_response :success

    assert_select "select#possible_data_files" do
      assert_select "option[value=?]",data_file.id,:text=>/#{data_file.title}/
      assert_select "option",:text=>/#{sop.title}/,:count=>0
    end

    assert_select "select#possible_sops" do
      assert_select "option[value=?]",sop.id,:text=>/#{sop.title}/
      assert_select "option",:text=>/#{data_file.title}/,:count=>0
    end
  end

  test "index includes modelling validates with schema" do
    get :index, :page=>"all", :format=>"xml"
    assert_response :success
    assays=assigns(:assays)
    assert assays.include?(assays(:modelling_assay_with_data_and_relationship)), "This test is invalid as the list should include the modelling assay"

    validate_xml_against_schema(@response.body)
  end

  test "shouldn't show unauthorized assays" do
    login_as Factory(:user)
    hidden = Factory(:experimental_assay, :policy => Factory(:private_policy)) #ensure at least one hidden assay exists
    get :index, :page=>"all", :format=>"xml"
    assert_response :success
    assert_equal assigns(:assays).sort_by(&:id), Authorization.authorize_collection("view", assigns(:assays), users(:aaron)).sort_by(&:id), "assays haven't been authorized"
    assert !assigns(:assays).include?(hidden)
  end

  def test_title
    get :index
    assert_select "title", :text=>/The Sysmo SEEK Assays.*/, :count=>1
  end

  test "should show index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:assays)
  end

  test "should show draggable icon in index" do
    get :index
    assert_response :success
    assays = assigns(:assays)
    first_assay = assays.first
    assert_not_nil first_assay
    assert_select "a[id*=?]", /drag_Assay_#{first_assay.id}/
  end

  test "should show index in xml" do
    get :index
    assert_response :success
    assert_not_nil assigns(:assays)
  end

  test "should update assay with new version of same sop" do
    login_as(:model_owner)
    assay=assays(:metabolomics_assay)
    timestamp=assay.updated_at

    sop = sops(:sop_with_all_sysmo_users_policy)
    assert !assay.sops.include?(sop.latest_version)
    assert_difference('ActivityLog.count') do
      put :update, :id=>assay, :assay_sop_ids=>[sop.id], :assay=>{}, :assay_sample_ids=>[Factory(:sample).id]
    end

    assert_redirected_to assay_path(assay)
    assert assigns(:assay)

    assay.reload
    stored_sop = assay.assay_assets.detect { |aa| aa.asset_id=sop.id }.versioned_asset
    assert_equal sop.version, stored_sop.version

    login_as sop.contributor
    sop.save_as_new_version
    login_as(:model_owner)

    assert_difference('ActivityLog.count') do
      put :update, :id=>assay, :assay_sop_ids=>[sop.id], :assay=>{}, :assay_sample_ids=>[Factory(:sample).id]
    end

    assay.reload
    stored_sop = assay.assay_assets.detect { |aa| aa.asset_id=sop.id }.versioned_asset
    assert_equal sop.version, stored_sop.version


  end

  test "should update timestamp when associating sop" do
    login_as(:model_owner)
    assay=assays(:metabolomics_assay)
    timestamp=assay.updated_at

    sop = sops(:sop_with_all_sysmo_users_policy)
    assert !assay.sops.include?(sop.latest_version)
    sleep(1)
    assert_difference('ActivityLog.count') do
      put :update, :id=>assay, :assay_sop_ids=>[sop.id], :assay=>{}, :assay_sample_ids=>[Factory(:sample).id]
    end

    assert_redirected_to assay_path(assay)
    assert assigns(:assay)
    updated_assay=Assay.find(assay.id)
    assert updated_assay.sops.include?(sop.latest_version)
    assert_not_equal timestamp, updated_assay.updated_at

  end


  test "should update timestamp when associating datafile" do
    login_as(:model_owner)
    assay=assays(:metabolomics_assay)
    timestamp=assay.updated_at

    df = data_files(:downloadable_data_file)
    assert !assay.data_files.include?(df.latest_version)
    sleep(1)
    assert_difference('ActivityLog.count') do
      put :update, :id=>assay, :data_file_ids=>["#{df.id},Test data"], :assay=>{}, :assay_sample_ids=>[Factory(:sample).id]
    end

    assert_redirected_to assay_path(assay)
    assert assigns(:assay)
    updated_assay=Assay.find(assay.id)
    assert updated_assay.data_files.include?(df.latest_version)
    assert_not_equal timestamp, updated_assay.updated_at
  end

  test "should update timestamp when associating model" do
    login_as(:model_owner)
    assay=assays(:metabolomics_assay)
    timestamp=assay.updated_at

    model = models(:teusink)
    assert !assay.models.include?(model.latest_version)
    sleep(1)
    assert_difference('ActivityLog.count') do
      put :update, :id=>assay, :assay_model_ids=>[model.id], :assay=>{}, :assay_sample_ids=>[Factory(:sample).id]
    end

    assert_redirected_to assay_path(assay)
    assert assigns(:assay)
    updated_assay=Assay.find(assay.id)
    assert updated_assay.models.include?(model.latest_version)
    assert_not_equal timestamp, updated_assay.updated_at
  end

  test "should show item" do
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay)
    end

    assert_response :success
    assert_not_nil assigns(:assay)

    assert_select "p#assay_type", :text=>/Metabalomics/, :count=>1
    assert_select "p#technology_type", :text=>/Gas chromatography/, :count=>1
  end

  test "should not show tagging when not logged in" do
    logout
    public_assay = Factory(:experimental_assay, :policy => Factory(:public_policy))
    get :show, :id=>public_assay
    assert_response :success
    assert_select "div#tags_box", :count=>0
  end

  test "should show svg item" do
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay), :format=>"svg"
    end

    assert_response :success
    assert @response.body.include?("Generated by Graphviz"), "SVG generation failed, please make you you have graphviz installed, and the 'dot' command is available"
  end

  test "should show modelling assay" do
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:modelling_assay_with_data_and_relationship)
    end

    assert_response :success
    assert_not_nil assigns(:assay)
    assert_equal assigns(:assay), assays(:modelling_assay_with_data_and_relationship)
  end

  test "should show new" do
    get :new
    assert_response :success
    assert_not_nil assigns(:assay)
    assert_nil assigns(:assay).study
  end

  test "should show new with study when id provided" do
    s=studies(:metabolomics_study)
    get :new, :study_id=>s
    assert_response :success
    assert_not_nil assigns(:assay)
    assert_equal s, assigns(:assay).study
  end

  test "should show item with no study" do
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:assay_with_no_study_or_files)
    end

    assert_response :success
    assert_not_nil assigns(:assay)
  end

  test "should update with study" do
    login_as(:model_owner)
    a=assays(:assay_with_no_study_or_files)
    s=studies(:metabolomics_study)
    assert_difference('ActivityLog.count') do
      put :update, :id=>a, :assay=>{:study=>s}, :assay_sample_ids=>[Factory(:sample).id]
    end

    assert_redirected_to assay_path(a)
    assert assigns(:assay)
    assert_not_nil assigns(:assay).study
    assert_equal s, assigns(:assay).study
  end

test "should create experimental assay with or without sample" do
    #THIS TEST MAY BECOME INVALID ONCE IT IS DECIDED HOW ASSAYS LINK TO SAMPLES OR ORGANISMS
    assert_difference('ActivityLog.count') do
      assert_difference("Assay.count") do
        post :create, :assay=>{:title=>"test",
                               :technology_type_id=>technology_types(:gas_chromatography).id,
                               :assay_type_id=>assay_types(:metabolomics).id,
                               :study_id=>studies(:metabolomics_study).id,
                               :assay_class=>assay_classes(:experimental_assay_class),
                               :owner => Factory(:person)}, :sharing => valid_sharing
      end
    end
    a=assigns(:assay)
    assert a.samples.empty?


    sample = Factory(:sample)
    assert_difference('ActivityLog.count') do
      assert_difference("Assay.count") do
        post :create, :assay=>{:title=>"test",
                               :technology_type_id=>technology_types(:gas_chromatography).id,
                               :assay_type_id=>assay_types(:metabolomics).id,
                               :study_id=>studies(:metabolomics_study).id,
                               :assay_class=>assay_classes(:experimental_assay_class),
                               :owner => Factory(:person),
                               :sample_ids=>[sample.id]
        }, :sharing => valid_sharing

      end
    end
    a=assigns(:assay)
    assert_redirected_to assay_path(a)
    assert_equal [sample],a.samples
    #assert_equal organisms(:yeast),a.organism
end


  test "should create experimental assay with/without organisms" do

    tissue_and_cell_type = Factory(:tissue_and_cell_type)
    #create assay only with organisms
    assert_difference("Assay.count") do
      post :create, :assay=>{:title=>"test",
                             :technology_type_id=>technology_types(:gas_chromatography).id,
                             :assay_type_id=>assay_types(:metabolomics).id,
                             :study_id=>studies(:metabolomics_study).id,
                             :assay_class=>assay_classes(:experimental_assay_class),
                             :owner => Factory(:person),
                             :samples => [Factory(:sample)]}, :assay_organism_ids =>[Factory(:organism).id,Factory(:strain).title,Factory(:culture_growth_type).title,tissue_and_cell_type.id,tissue_and_cell_type.title].to_s, :sharing => valid_sharing
    end

    assert_difference("Assay.count") do
      post :create, :assay=>{:title=>"test",
                             :technology_type_id=>technology_types(:gas_chromatography).id,
                             :assay_type_id=>assay_types(:metabolomics).id,
                             :study_id=>studies(:metabolomics_study).id,
                             :assay_class=>assay_classes(:experimental_assay_class),
                             :owner => Factory(:person),
                             :samples => [Factory(:sample)]},
           :assay_organism_ids => [Factory(:organism).id, Factory(:strain).title, Factory(:culture_growth_type).title].to_s, :sharing => valid_sharing
    end
    a=assigns(:assay)
    assert_redirected_to assay_path(a)
  end

  test "should create modelling assay with/without organisms" do

    assert_difference("Assay.count") do
      post :create, :assay=>{:title=>"test",
                             :assay_type_id=>assay_types(:metabolomics).id,
                             :study_id=>studies(:metabolomics_study).id,
                             :assay_class=>assay_classes(:modelling_assay_class),
                             :owner => Factory(:person)}, :sharing => valid_sharing
    end

    assert_difference("Assay.count") do
      post :create, :assay=>{:title=>"test",
                             :assay_type_id=>assay_types(:metabolomics).id,
                             :study_id=>studies(:metabolomics_study).id,
                             :assay_class=>assay_classes(:modelling_assay_class),
                             :owner => Factory(:person)},
           :assay_organism_ids => [Factory(:organism).id, Factory(:strain).title, Factory(:culture_growth_type).title].to_s, :sharing => valid_sharing
    end
    a=assigns(:assay)
    assert_redirected_to assay_path(a)
    #create assay with samples and organisms
    assert_difference('ActivityLog.count') do
    assert_difference("Assay.count") do
      post :create,:assay=>{:title=>"test",
        :technology_type_id=>technology_types(:gas_chromatography).id,
        :assay_type_id=>assay_types(:metabolomics).id,
        :study_id=>studies(:metabolomics_study).id,
        :assay_class=>assay_classes(:experimental_assay_class),
        :owner => Factory(:person),
        :sample_ids=>[Factory(:sample).id]
      },:assay_organism_ids=>[Factory(:organism).id.to_s,"",""].join(",").to_a, :sharing => valid_sharing
    end
    end
    a=assigns(:assay)
    assert_redirected_to assay_path(a)
  end

  test "should not create modelling assay with sample" do
    #FIXME: its allows at the moment due to time constraints before pals meeting, and fixtures and factories need updating. JIRA: SYSMO-734
    assert_no_difference("Assay.count") do
      post :create, :assay=>{:title=>"test",
                             :technology_type_id=>technology_types(:gas_chromatography).id,
                             :assay_type_id=>assay_types(:metabolomics).id,
                             :study_id=>studies(:metabolomics_study).id,
                             :assay_class=>assay_classes(:modelling_assay_class),
                             :owner => Factory(:person),
                             :sample_ids=>[Factory(:sample).id, Factory(:sample).id]
      }
    end
    
  end

  test "should delete assay with study" do
    login_as(:model_owner)
    assert_difference('ActivityLog.count') do
      assert_difference('Assay.count', -1) do
        delete :destroy, :id => assays(:assay_with_just_a_study).id
      end
    end

    assert_nil flash[:error]
    assert_redirected_to assays_path
  end

  test "should not delete assay when not project member" do
    a = assays(:assay_with_just_a_study)
    login_as(:aaron)
    assert_no_difference('ActivityLog.count') do
      assert_no_difference('Assay.count') do
        delete :destroy, :id => a
      end
    end

    assert flash[:error]
    assert_redirected_to assays_path
  end

  test "should not delete assay when not project pal" do
    a = assays(:assay_with_just_a_study)
    login_as(:datafile_owner)
    assert_no_difference('ActivityLog.count') do
      assert_no_difference('Assay.count') do
        delete :destroy, :id => a
      end
    end

    assert flash[:error]
    assert_redirected_to assays_path
  end

  test "should show edit when not logged in" do
    logout
    a = Factory :experimental_assay,:contributor=>Factory(:person),:policy=>Factory(:editing_public_policy)
    get :edit,:id=>a
    assert_response :success

    a = Factory :modelling_assay,:contributor=>Factory(:person),:policy=>Factory(:editing_public_policy)
    get :edit,:id=>a
    assert_response :success
  end

  test "should not edit assay when not project pal" do
    a = assays(:assay_with_just_a_study)
    login_as(:datafile_owner)
    get :edit, :id => a
    assert flash[:error]
    assert_redirected_to a
  end

  test "admin should not edit somebody elses assay" do
    a = assays(:assay_with_just_a_study)
    login_as(:quentin)
    get :edit, :id => a
    assert flash[:error]
    assert_redirected_to a
  end

  test "should not delete assay with data files" do
    login_as(:model_owner)
    a = assays(:assay_with_no_study_but_has_some_files)
    assert_no_difference('ActivityLog.count') do
      assert_no_difference('Assay.count') do
        delete :destroy, :id => a
      end
    end
    assert flash[:error]
    assert_redirected_to assays_path
  end

  test "should not delete assay with model" do
    login_as(:model_owner)
    a = assays(:assay_with_a_model)
    assert_no_difference('ActivityLog.count') do
      assert_no_difference('Assay.count') do
        delete :destroy, :id => a
      end
    end

    assert flash[:error]
    assert_redirected_to assays_path
  end

  test "should not delete assay with publication" do
    login_as(:model_owner)
    a = assays(:assay_with_a_publication)
    assert_no_difference('ActivityLog.count') do
      assert_no_difference('Assay.count') do
        delete :destroy, :id => a
      end
    end

    assert flash[:error]
    assert_redirected_to assays_path
  end

  test "should not delete assay with sops" do
    login_as(:model_owner)
    a = assays(:assay_with_no_study_but_has_some_sops)
    assert_no_difference('ActivityLog.count') do
      assert_no_difference('Assay.count') do
        delete :destroy, :id => a
      end
    end

    assert flash[:error]
    assert_redirected_to assays_path
  end

  test "get new presents options for class" do
    login_as(:model_owner)
    get :new
    assert_response :success
    assert_select "a[href=?]", new_assay_path(:class=>:experimental), :count=>1
    assert_select "a", :text=>/An experimental assay/i, :count=>1
    assert_select "a[href=?]", new_assay_path(:class=>:modelling), :count=>1
    assert_select "a", :text=>/A modelling analysis/i, :count=>1
  end

  test "get new with class doesnt present options for class" do
    login_as(:model_owner)
    get :new, :class=>"experimental"
    assert_response :success
    assert_select "a[href=?]", new_assay_path(:class=>:experimental), :count=>0
    assert_select "a", :text=>/An experimental assay/i, :count=>0
    assert_select "a[href=?]", new_assay_path(:class=>:modelling), :count=>0
    assert_select "a", :text=>/A modelling analysis/i, :count=>0

    get :new, :class=>"modelling"
    assert_response :success
    assert_select "a[href=?]", new_assay_path(:class=>:experimental), :count=>0
    assert_select "a", :text=>/An experimental assay/i, :count=>0
    assert_select "a[href=?]", new_assay_path(:class=>:modelling), :count=>0
    assert_select "a", :text=>/A modelling analysis/i, :count=>0
  end

  test "data file list should only include those from project" do
    login_as(:model_owner)
    get :new, :class=>"experimental"
    assert_response :success
    assert_select "select#possible_data_files" do
      assert_select "option", :text=>/Sysmo Data File/, :count=>1
      assert_select "option", :text=>/Myexperiment Data File/, :count=>0
    end
  end

  test "download link for sop in tab has version" do
    login_as(:owner_of_my_first_sop)
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay)
    end

    assert_response :success

    assert_select "div.list_item div.list_item_actions" do
      path=download_sop_path(sops(:my_first_sop))
      assert_select "a[href=?]", path, :minumum=>1
    end
  end

  test "show link for sop in tab has version" do
    login_as(:owner_of_my_first_sop)
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay)
    end

    assert_response :success

    assert_select "div.list_item div.list_item_actions" do
      path=sop_path(sops(:my_first_sop))
      assert_select "a[href=?]", path, :minumum=>1
    end
  end

  test "edit link for sop in tabs" do
    login_as(:owner_of_my_first_sop)
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay)
    end

    assert_response :success

    assert_select "div.list_item div.list_item_actions" do
      path=edit_sop_path(sops(:my_first_sop))
      assert_select "a[href=?]", path, :minumum=>1
    end
  end

  test "download link for data_file in tabs" do
    login_as(:owner_of_my_first_sop)
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay)
    end

    assert_response :success

    assert_select "div.list_item div.list_item_actions" do
      path=download_data_file_path(data_files(:picture))
      assert_select "a[href=?]", path, :minumum=>1
    end
  end

  test "show link for data_file in tabs" do
    login_as(:owner_of_my_first_sop)
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay)
    end

    assert_response :success

    assert_select "div.list_item div.list_item_actions" do
      path=data_file_path(data_files(:picture))
      assert_select "a[href=?]", path, :minumum=>1
    end
  end

  test "edit link for data_file in tabs" do
    login_as(:owner_of_my_first_sop)
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay)
    end

    assert_response :success

    assert_select "div.list_item div.list_item_actions" do
      path=edit_data_file_path(data_files(:picture))
      assert_select "a[href=?]", path, :minumum=>1
    end
  end

  test "links have nofollow in sop tabs" do
    login_as(:owner_of_my_first_sop)
    sop_version=sops(:my_first_sop)
    sop_version.description="http://news.bbc.co.uk"
    sop_version.save!
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay)
    end

    assert_select "div.list_item div.list_item_desc" do
      assert_select "a[rel=?]", "nofollow", :text=>/news\.bbc\.co\.uk/, :minimum=>1
    end
  end

  test "links have nofollow in data_files tabs" do
    login_as(:owner_of_my_first_sop)
    data_file_version=data_files(:picture)
    data_file_version.description="http://news.bbc.co.uk"
    data_file_version.save!
    assert_difference('ActivityLog.count') do
      get :show, :id=>assays(:metabolomics_assay)
    end

    assert_select "div.list_item div.list_item_desc" do
      assert_select "a[rel=?]", "nofollow", :text=>/news\.bbc\.co\.uk/, :minimum=>1
    end
  end


  def test_should_add_nofollow_to_links_in_show_page
    assert_difference('ActivityLog.count') do
      get :show, :id=> assays(:assay_with_links_in_description)
    end

    assert_select "div#description" do
      assert_select "a[rel=nofollow]"
    end
  end

    #checks that for an assay that has 2 sops and 2 datafiles, of which 1 is public and 1 private - only links to the public sops & datafiles are show
  def test_authorization_of_sops_and_datafiles_links
    #sanity check the fixtures are correct
    check_fixtures_for_authorization_of_sops_and_datafiles_links
    login_as(:model_owner)
    assay=assays(:assay_with_public_and_private_sops_and_datafiles)
    assert_difference('ActivityLog.count') do
      get :show, :id=>assay.id
    end

    assert_response :success

    assert_select "div.tabbertab" do
      assert_select "h3", :text=>"SOPs (1+1)", :count=>1
      assert_select "h3", :text=>"Data Files (1+1)", :count=>1
    end

    assert_select "div.list_item" do
      assert_select "div.list_item_title a[href=?]", sop_path(sops(:sop_with_fully_public_policy)), :text=>"SOP with fully public policy", :count=>1
      assert_select "div.list_item_actions a[href=?]", sop_path(sops(:sop_with_fully_public_policy)), :count=>1
      assert_select "div.list_item_title a[href=?]", sop_path(sops(:sop_with_private_policy_and_custom_sharing)), :count=>0
      assert_select "div.list_item_actions a[href=?]", sop_path(sops(:sop_with_private_policy_and_custom_sharing)), :count=>0

      assert_select "div.list_item_title a[href=?]", data_file_path(data_files(:downloadable_data_file)), :text=>"Download Only", :count=>1
      assert_select "div.list_item_actions a[href=?]", data_file_path(data_files(:downloadable_data_file)), :count=>1
      assert_select "div.list_item_title a[href=?]", data_file_path(data_files(:private_data_file)), :count=>0
      assert_select "div.list_item_actions a[href=?]", data_file_path(data_files(:private_data_file)), :count=>0
    end

  end

  test "associated assets aren't lost on failed validation in create" do
    sop=sops(:sop_with_all_sysmo_users_policy)
    model=models(:model_with_links_in_description)
    datafile=data_files(:downloadable_data_file)
    rel=RelationshipType.first

    assert_no_difference('ActivityLog.count') do
      assert_no_difference("Assay.count", "Should not have added assay because the title is blank") do
        assert_no_difference("AssayAsset.count", "Should not have added assay assets because the assay validation failed") do
          #title is blank, so should fail validation
          post :create, :assay=>{
              :title=>"",
              :technology_type_id=>technology_types(:gas_chromatography).id,
              :assay_type_id=>assay_types(:metabolomics).id,
              :study_id=>studies(:metabolomics_study).id,
              :assay_class=>assay_classes(:modelling_assay_class)
          },
               :assay_sop_ids=>["#{sop.id}"],
               :assay_model_ids=>["#{model.id}"],
               :data_file_ids=>["#{datafile.id},#{rel.title}"]
        end
      end
    end


      #since the items are added to the UI by manipulating the DOM with javascript, we can't do assert_select on the HTML elements to check they are there.
      #so instead check for the relevant generated lines of javascript
    assert_select "script", :text=>/sop_title = '#{sop.title}'/, :count=>1
    assert_select "script", :text=>/sop_id = '#{sop.id}'/, :count=>1
    assert_select "script", :text=>/model_title = '#{model.title}'/, :count=>1
    assert_select "script", :text=>/model_id = '#{model.id}'/, :count=>1
    assert_select "script", :text=>/data_title = '#{datafile.title}'/, :count=>1
    assert_select "script", :text=>/data_file_id = '#{datafile.id}'/, :count=>1
    assert_select "script", :text=>/relationship_type = '#{rel.title}'/, :count=>1
    assert_select "script", :text=>/addDataFile/, :count=>1
    assert_select "script", :text=>/addSop/, :count=>1
    assert_select "script", :text=>/addModel/, :count=>1
  end

  test "associated assets aren't lost on failed validation on update" do
    login_as(:model_owner)
    assay=assays(:assay_with_links_in_description)

      #remove any existing associated assets
    assay.assets.clear
    assay.save!
    assay.reload
    assert assay.sops.empty?
    assert assay.models.empty?
    assert assay.data_files.empty?

    sop=sops(:sop_with_all_sysmo_users_policy)
    model=models(:model_with_links_in_description)
    datafile=data_files(:downloadable_data_file)
    rel=RelationshipType.first

    assert_no_difference('ActivityLog.count') do
      assert_no_difference("Assay.count", "Should not have added assay because the title is blank") do
        assert_no_difference("AssayAsset.count", "Should not have added assay assets because the assay validation failed") do
          #title is blank, so should fail validation
          put :update, :id=>assay, :assay=>{:title=>"", :assay_class=>assay_classes(:modelling_assay_class)},
              :assay_sop_ids=>["#{sop.id}"],
              :assay_model_ids=>["#{model.id}"],
              :data_file_ids=>["#{datafile.id},#{rel.title}"]
        end
      end
    end


      #since the items are added to the UI by manipulating the DOM with javascript, we can't do assert_select on the HTML elements to check they are there.
      #so instead check for the relevant generated lines of javascript
    assert_select "script", :text=>/sop_title = '#{sop.title}'/, :count=>1
    assert_select "script", :text=>/sop_id = '#{sop.id}'/, :count=>1
    assert_select "script", :text=>/model_title = '#{model.title}'/, :count=>1
    assert_select "script", :text=>/model_id = '#{model.id}'/, :count=>1
    assert_select "script", :text=>/data_title = '#{datafile.title}'/, :count=>1
    assert_select "script", :text=>/data_file_id = '#{datafile.id}'/, :count=>1
    assert_select "script", :text=>/relationship_type = '#{rel.title}'/, :count=>1
    assert_select "script", :text=>/addDataFile/, :count=>1
    assert_select "script", :text=>/addSop/, :count=>1
    assert_select "script", :text=>/addModel/, :count=>1
  end

  def check_fixtures_for_authorization_of_sops_and_datafiles_links
    user=users(:model_owner)
    assay=assays(:assay_with_public_and_private_sops_and_datafiles)
    assert_equal 4, assay.assets.size
    assert_equal 2, assay.sops.size
    assert_equal 2, assay.data_files.size
    assert assay.sops.include?(sops(:sop_with_fully_public_policy).find_version(1))
    assert assay.sops.include?(sops(:sop_with_private_policy_and_custom_sharing).find_version(1))
    assert assay.data_files.include?(data_files(:downloadable_data_file).find_version(1))
    assert assay.data_files.include?(data_files(:private_data_file).find_version(1))

    assert sops(:sop_with_fully_public_policy).can_view? user
    assert !sops(:sop_with_private_policy_and_custom_sharing).can_view?(user)
    assert data_files(:downloadable_data_file).can_view?(user)
    assert !data_files(:private_data_file).can_view?(user)
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
    person = people(:person_for_model_owner)
    get :index, :filter=>{:person=>person.id}, :page=>"all"
    assert_response :success
    a = assays(:metabolomics_assay)
    a2 = assays(:modelling_assay_with_data_and_relationship)
    assert_select "div.list_items_container" do
      assert_select "a", :text=>a.title, :count=>1
      assert_select "a", :text=>a2.title, :count=>0
    end
  end

  test 'edit assay with selected projects scope policy' do
    proj = User.current_user.person.projects.first
    assay = Factory(:assay, :contributor => User.current_user.person,
                    :study => Factory(:study, :investigation => Factory(:investigation, :projects => [proj])),
                    :policy => Factory(:policy,
                                       :sharing_scope => Policy::ALL_SYSMO_USERS,
                                       :access_type => Policy::NO_ACCESS,
                                       :permissions => [Factory(:permission, :contributor => proj, :access_type => Policy::EDITING)]))
    get :edit, :id => assay.id
  end

  test "should create sharing permissions 'with your project and with all SysMO members'" do
    login_as(:quentin)
    a = {:title=>"test", :technology_type_id=>technology_types(:gas_chromatography).id, :assay_type_id=>assay_types(:metabolomics).id,
         :study_id=>studies(:metabolomics_study).id, :assay_class=>assay_classes(:experimental_assay_class), :sample_ids=>[Factory(:sample).id]}
    assert_difference('ActivityLog.count') do
      assert_difference('Assay.count') do
        post :create, :assay => a, :sharing=>{"access_type_#{Policy::ALL_SYSMO_USERS}"=>Policy::VISIBLE, :sharing_scope=>Policy::ALL_SYSMO_USERS, :your_proj_access_type => Policy::ACCESSIBLE}
      end
    end

    assay=assigns(:assay)
    assert_redirected_to assay_path(assay)
    assert_equal Policy::ALL_SYSMO_USERS, assay.policy.sharing_scope
    assert_equal Policy::VISIBLE, assay.policy.access_type
    assert_equal assay.policy.permissions.count, 1

    assay.policy.permissions.each do |permission|
      assert_equal permission.contributor_type, 'Project'
      assert assay.study.investigation.project_ids.include?(permission.contributor_id)
      assert_equal permission.policy_id, assay.policy_id
      assert_equal permission.access_type, Policy::ACCESSIBLE
    end
  end

  test "should update sharing permissions 'with your project and with all SysMO members'" do
    login_as Factory(:user)
    assay= Factory(:assay,
                   :policy => Factory(:private_policy),
                   :contributor => User.current_user.person,
                   :study => (Factory(:study, :investigation => (Factory(:investigation,
                                                                         :projects => [Factory(:project), Factory(:project)])))))

    assert assay.can_manage?
    assert_equal Policy::PRIVATE, assay.policy.sharing_scope
    assert_equal Policy::NO_ACCESS, assay.policy.access_type
    assert assay.policy.permissions.empty?

    assert_difference('ActivityLog.count') do
      put :update, :id => assay, :assay => {}, :sharing => {"access_type_#{Policy::ALL_SYSMO_USERS}"=>Policy::ACCESSIBLE, :sharing_scope => Policy::ALL_SYSMO_USERS, :your_proj_access_type => Policy::EDITING}
    end

    assay.reload
    assert_redirected_to assay_path(assay)
    assert_equal Policy::ALL_SYSMO_USERS, assay.policy.sharing_scope
    assert_equal Policy::ACCESSIBLE, assay.policy.access_type
    assert_equal 2, assay.policy.permissions.length

    assay.policy.permissions.each do |update_permission|
      assert_equal update_permission.contributor_type, 'Project'
      assert assay.projects.map(&:id).include?(update_permission.contributor_id)
      assert_equal update_permission.policy_id, assay.policy_id
      assert_equal update_permission.access_type, Policy::EDITING
    end
  end
end
