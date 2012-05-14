require "test_helper"

class SamplesControllerTest < ActionController::TestCase
fixtures :all
  include AuthenticatedTestHelper
  include RestTestCases
  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    Seek::Config.is_virtualliver = true
    login_as Factory(:user,:person => Factory(:person,:is_admin=> false))
    @object = Factory(:sample,:contributor => User.current_user,
            :title=> "test1",
            :policy => policies(:policy_for_viewable_data_file))
  end

  test "index xml validates with schema" do
    Factory(:sample,
            :title=> "test2",
            :policy => policies(:policy_for_viewable_data_file))
    Factory :sample, :policy => policies(:editing_for_all_sysmo_users_policy)
    get :index, :format =>"xml"
    assert_response :success
    assert_not_nil assigns(:samples)
    validate_xml_against_schema(@response.body)

  end

  test "show xml validates with schema" do
    s = Factory(:sample,:contributor => Factory(:user,:person => Factory(:person,:is_admin=> true)),
                :title => "test sample",
                :policy => policies(:policy_for_viewable_data_file))
    get :show, :id => s, :format =>"xml"
    assert_response :success
    assert_not_nil assigns(:sample)
    validate_xml_against_schema(@response.body)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:samples)
  end
  test "should get new" do
    get :new
    assert_response :success
    assert_not_nil assigns(:sample)

  end
  test "should create" do
    assert_difference("Sample.count") do
      post :create, :sample => {:title => "test",
                                :lab_internal_number =>"Do232",
                                :donation_date => Date.today,
                                :specimen => Factory(:specimen, :contributor => User.current_user)}
    end
    s = assigns(:sample)
    assert_redirected_to sample_path(s)
    assert_equal "test", s.title
  end

  test "should get show" do
    get :show, :id => Factory(:sample, :title=>"test", :policy =>policies(:editing_for_all_sysmo_users_policy))
    assert_response :success
    assert_not_nil assigns(:sample)
  end

  test "should get edit" do
    get :edit, :id=> Factory(:sample, :policy => policies(:editing_for_all_sysmo_users_policy))
    assert_response :success
    assert_not_nil assigns(:sample)
  end
  test "should update" do
    s = Factory(:sample, :title=>"oneSample", :policy =>policies(:editing_for_all_sysmo_users_policy))
    assert_not_equal "test", s.title
    put "update", :id=>s, :sample =>{:title =>"test"}
    s = assigns(:sample)
    assert_redirected_to sample_path(s)
    assert_equal "test", s.title
  end

  test "should destroy" do
    s = Factory :sample, :contributor => User.current_user
    assert_difference("Sample.count", -1, "A sample should be deleted") do
      delete :destroy, :id => s.id
    end
  end
  test "unauthorized users cannot add new samples" do
    login_as Factory(:user,:person => Factory(:brand_new_person))
    get :new
    assert_response :redirect
  end
  test "unauthorized user cannot edit sample" do
    s = Factory :sample, :policy => Factory(:private_policy), :contributor => Factory(:user)
    get :edit, :id =>s.id
    assert_redirected_to sample_path(s)
    assert flash[:error]
  end
  test "unauthorized user cannot update sample" do
    s = Factory :sample, :policy => Factory(:private_policy), :contributor => Factory(:user)

    put :update, :id=> s.id, :sample =>{:title =>"test"}
    assert_redirected_to sample_path(s)
    assert flash[:error]
  end

  test "unauthorized user cannot delete sample" do
    s = Factory :sample, :policy => Factory(:private_policy), :contributor => Factory(:user)
    assert_no_difference("Sample.count") do
      delete :destroy, :id => s.id
    end
    assert flash[:error]
    assert_redirected_to samples_path
  end

  test "only current user can delete sample" do

    s = Factory :sample, :contributor => User.current_user
    assert_difference("Sample.count", -1, "A sample should be deleted") do
      delete :destroy, :id => s.id
    end
    s = Factory :sample, :contributor => Factory(:user)
    assert_no_difference("Sample.count") do
      delete :destroy, :id => s.id
    end
    assert flash[:error]
    assert_redirected_to samples_path
  end

  test "should not destroy sample related to an existing assay" do
    s = Factory :sample, :assays => [Factory :experimental_assay], :contributor => Factory(:user)
    assert_no_difference("Sample.count") do
      delete :destroy, :id => s.id
    end
    assert flash[:error]
    assert_redirected_to samples_path
  end

  test "associate data files,models,sops" do
      assert_difference("Sample.count") do
      post :create, :sample => {:title=>"test",
                                :lab_internal_number =>"Do232",
                                :donation_date => Date.today,
                                 :project_ids =>[Factory(:project).id],
                                :specimen => Factory(:specimen, :contributor => User.current_user)},
             :sample_data_file_ids => [Factory(:data_file,:title=>"testDF",:contributor=>User.current_user).id],
             :sample_model_ids => [Factory(:model,:title=>"testModel",:contributor=>User.current_user).id],
             :sample_sop_ids => [Factory(:sop,:title=>"testSop",:contributor=>User.current_user).id]

    end
    s = assigns(:sample)
    assert_equal "testDF", s.data_files.first.title
    assert_equal "testModel", s.models.first.title
    assert_equal "testSop", s.sops.first.title
  end
end
