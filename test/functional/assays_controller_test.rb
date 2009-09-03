require 'test_helper'

class AssaysControllerTest < ActionController::TestCase
  fixtures :all

  include AuthenticatedTestHelper

  def setup
    login_as(:aaron)
  end

  test "should show index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:assays)
  end

  test "should show item" do
    get :show, :id=>assays(:metabolomics_assay)
    assert_response :success
    assert_not_nil assigns(:assay)

    assert_select "p#culture_growth_type",:text=>/Chemostat/,:count=>1
    assert_select "p#assay_type",:text=>/Metabalomics/,:count=>1
    assert_select "p#technology_type",:text=>/Gas chromatography/,:count=>1
  end

  test "show culture growth type not specified" do
    get :show, :id=>assays(:metabolomics_assay2)
    assert_response :success
    assert_not_nil assigns(:assay)

    assert_select "p#culture_growth_type",:text=>/Not specified/,:count=>1    
  end

  test "should show new" do
    get :new
    assert_response :success
    assert_not_nil assigns(:assay)
    assert_nil assigns(:assay).study
  end

  test "should show new with study when id provided" do
    s=studies(:metabolomics_study)
    get :new,:study_id=>s
    assert_response :success
    assert_not_nil assigns(:assay)
    assert_equal s,assigns(:assay).study
  end

  test "should show item with no study" do
    get :show, :id=>assays(:assay_with_no_study_or_files)
    assert_response :success
    assert_not_nil assigns(:assay)
  end

  test "should update with study" do
    a=assays(:assay_with_no_study_or_files)
    s=studies(:metabolomics_study)
    put :update,:id=>a,:assay=>{:study=>s}
    assert_redirected_to assay_path(a)
    assert assigns(:assay)
    assert_not_nil assigns(:assay).study
    assert_equal s,assigns(:assay).study
  end

  test "should create" do
    assert_difference("Assay.count") do
      post :create,:assay=>{:title=>"test",
                            :organism_id=>organisms(:yeast).id,
                            :technology_type_id=>technology_types(:gas_chromatography).id,
                            :assay_type_id=>assay_types(:metabolomics).id,
                            :study_id=>studies(:metabolomics_study).id}
    end
    a=assigns(:assay)
    assert_redirected_to assay_path(a)
    assert_equal organisms(:yeast),a.organism
  end

  test "should delete unlinked assay" do
    assert_difference('Assay.count', -1) do
      delete :destroy, :id => assays(:assay_with_no_study_or_files).id
    end
    assert !flash[:error]
    assert_redirected_to assays_path
  end

  test "should not delete assay with study" do
    assert_no_difference('Assay.count') do
      delete :destroy, :id => assays(:assay_with_just_a_study).id
    end
    assert flash[:error]
    assert_redirected_to assays_path
  end

  test "should not delete assay with files" do
    assert_no_difference('Assay.count') do
      delete :destroy, :id => assays(:assay_with_no_study_but_has_some_files).id
    end
    assert flash[:error]
    assert_redirected_to assays_path
  end

  test "should not delete assay with sops" do
    assert_no_difference('Assay.count') do
      delete :destroy, :id => assays(:assay_with_no_study_but_has_some_sops).id
    end
    assert flash[:error]
    assert_redirected_to assays_path
  end

  test "data file list should only include those from project" do
    login_as(:model_owner)
    get :new    
    assert_select "select#possible_data_files" do
      assert_select "option",:text=>/Sysmo Data File/,:count=>1      
      assert_select "option",:text=>/Myexperiment Data File/,:count=>0
    end
  end
  
end
