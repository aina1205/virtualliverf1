require 'test_helper'

class ExperimentalConditionsControllerTest < ActionController::TestCase

  fixtures :all

  include AuthenticatedTestHelper

  def setup
    login_as(:quentin)
  end


  test "can only go to the experimental condition if the user can edit the sop" do
    sop=sops(:editable_sop)
    sop.save
    get :index,{:sop_id=>sop.id, :version => sop.version}
    assert_response :success

    sop=sops(:downloadable_sop)
    sop.save
    get :index,{:sop_id=>sop.id, :version => sop.version}
    assert_not_nil flash[:error]

  end

  test 'should create the experimental condition with the concentration of the compound' do
    sop=sops(:editable_sop)
    mi = measured_items(:concentration)
    unit = units(:gram)
    ec = {:measured_item_id => mi.id, :start_value => 1, :end_value => 10, :unit => unit}
    compound_name = 'iron'
    compound_annotation = Seek::SabiorkWebservices.new().get_compound_annotation(compound_name)

    post :create, :experimental_condition => ec, :sop_id => sop.id, :version => sop.version, :substance_autocompleter_unrecognized_items => [compound_name]

    ec = assigns(:experimental_condition)
    assert_not_nil ec
    assert ec.valid?
    assert_equal ec.measured_item, mi
    substance = ec.experimental_condition_links.first.substance
    assert_equal substance.name, compound_annotation['recommended_name']
    mappings = substance.mapping_links.collect{|ml| ml.mapping}
    kegg_ids = []
    mappings.each do |m|
      assert_equal m.sabiork_id, compound_annotation['sabiork_id']
      assert_equal m.chebi_id, compound_annotation['chebi_id']
      kegg_ids.push m.kegg_id
    end
    assert_equal kegg_ids, compound_annotation['kegg_ids']

    synonyms = substance.synonyms.collect{|s| s.name}
    assert_equal synonyms, compound_annotation['synonyms']
  end

  test 'should not create the experimental condition with the concentration of no substance' do
    sop=sops(:editable_sop)
    mi = measured_items(:concentration)
    unit = units(:gram)
    ec = {:measured_item_id => mi.id, :start_value => 1, :end_value => 10, :unit => unit}
    post :create, :experimental_condition => ec, :sop_id => sop.id, :version => sop.version
    ec = assigns(:experimental_condition)
    assert_not_nil ec
    assert !ec.valid?
  end

  test "should create experimental condition with the none concentration item and no substance" do
    sop=sops(:editable_sop)
    mi = measured_items(:time)
    unit = units(:gram)
    ec = {:measured_item_id => mi.id, :start_value => 1, :end_value => 10, :unit => unit}
    post :create, :experimental_condition => ec, :sop_id => sop.id, :version => sop.version
    ec = assigns(:experimental_condition)
    assert_not_nil ec
    assert ec.valid?
    assert_equal ec.measured_item, mi
  end

  test "should create the experimental condition with the concentration of the compound chosen from autocomplete" do
    sop=sops(:editable_sop)
    mi = measured_items(:concentration)
    cp = compounds(:compound_glucose)
    unit = units(:gram)
    ec = {:measured_item_id => mi.id, :start_value => 1, :end_value => 10, :unit => unit}
    post :create, :experimental_condition => ec, :sop_id => sop.id, :version => sop.version, :substance_autocompleter_selected_ids => ["#{cp.id.to_s},Compound"]
    ec = assigns(:experimental_condition)
    assert_not_nil ec
    assert ec.valid?
    assert_equal ec.measured_item, mi
    assert_equal ec.experimental_condition_links.first.substance, cp
  end

  test "should create the experimental condition with the concentration of the compound's synonym" do
    sop=sops(:editable_sop)
    mi = measured_items(:concentration)
    syn = synonyms(:glucose_synonym)
    unit = units(:gram)
    ec = {:measured_item_id => mi.id, :start_value => 1, :end_value => 10, :unit => unit}
    post :create, :experimental_condition => ec, :sop_id => sop.id, :version => sop.version, :substance_autocompleter_selected_ids => ["#{syn.id.to_s},Synonym"]
    ec = assigns(:experimental_condition)
    assert_not_nil ec
    assert ec.valid?
    assert_equal ec.measured_item, mi
    assert_equal ec.experimental_condition_links.first.substance, syn
  end

  test 'should update the experimental condition of concentration to time' do
    ec = experimental_conditions(:experimental_condition_concentration_glucose)
    assert_not_nil ec
    assert_equal ec.measured_item, measured_items(:concentration)
    assert_equal ec.experimental_condition_links.first.substance, compounds(:compound_glucose)

    mi = measured_items(:time)
    put :update, :id => ec.id, :sop_id => ec.sop.id, :experimental_condition => {:measured_item_id => mi.id}
    ec_updated = assigns(:experimental_condition)
    assert_not_nil ec_updated
    assert ec_updated.valid?
    assert_equal ec_updated.measured_item, mi
    assert ec_updated.experimental_condition_links.blank?
  end

  test 'should update the experimental condition of time to concentration' do
    ec = experimental_conditions(:experimental_condition_time)
    assert_not_nil ec
    assert_equal ec.measured_item, measured_items(:time)
    assert ec.experimental_condition_links.blank?

    mi = measured_items(:concentration)
    cp = compounds(:compound_glucose)
    put :update, :id => ec.id, :sop_id => ec.sop.id, :experimental_condition => {:measured_item_id => mi.id},  "#{ec.id}_substance_autocompleter_selected_ids" => ["#{cp.id.to_s},Compound"]
    ec_updated = assigns(:experimental_condition)
    assert_not_nil ec_updated
    assert ec_updated.valid?
    assert_equal ec_updated.measured_item, mi
    assert_equal ec_updated.experimental_condition_links.first.substance, cp
  end

  test 'should update the experimental condition of time to pressure' do
    ec = experimental_conditions(:experimental_condition_time)
    assert_not_nil ec
    assert_equal ec.measured_item, measured_items(:time)
    assert ec.experimental_condition_links.blank?

    mi = measured_items(:pressure)
    put :update, :id => ec.id, :sop_id => ec.sop.id, :experimental_condition => {:measured_item_id => mi.id}
    ec_updated = assigns(:experimental_condition)
    assert_not_nil ec_updated
    assert ec_updated.valid?
    assert_equal ec_updated.measured_item, mi
    assert ec_updated.experimental_condition_links.blank?
  end

  test 'should update the experimental condition of concentration of glucose to concentration of glycine' do
    ec = experimental_conditions(:experimental_condition_concentration_glucose)
    assert_not_nil ec
    assert_equal ec.measured_item, measured_items(:concentration)
    assert_equal ec.experimental_condition_links.first.substance, compounds(:compound_glucose)

    cp = compounds(:compound_glycine)
    put :update, :id => ec.id, :sop_id => ec.sop.id, :experimental_condition => {}, "#{ec.id}_substance_autocompleter_selected_ids" => ["#{cp.id.to_s},Compound"]
    ec_updated = assigns(:experimental_condition)
    assert_not_nil ec_updated
    assert ec_updated.valid?
    assert_equal ec_updated.measured_item, measured_items(:concentration)
    assert_equal ec_updated.experimental_condition_links.count, 1
    assert_equal ec_updated.experimental_condition_links.first.substance, cp
  end

  test 'should update start_value, end_value of the experimental condition' do
    ec = experimental_conditions(:experimental_condition_time)
    assert_not_nil ec

    put :update, :id => ec.id, :sop_id => ec.sop.id, :experimental_condition => {:start_value => 10.02, :end_value => 50}
    fs_updated = assigns(:experimental_condition)
    assert_not_nil fs_updated
    assert fs_updated.valid?
    assert_equal fs_updated.start_value, 10.02
    assert_equal fs_updated.end_value, 50
  end


  test "should not create experimental condition which has fields containing the comma in the decimal number" do
    sop = sops(:editable_sop)
    mi = measured_items(:time)
    unit = units(:gram)
    ec = {:measured_item_id => mi.id, :start_value => "1,5" , :end_value => 10, :unit => unit}
    post :create, :experimental_condition => ec, :sop_id => sop.id, :version => sop.version
    ec = assigns(:experimental_condition)
    assert_nil ec
  end

  test 'should not update experimental condition which has fields containing the comma in the decimal number' do
    ec = experimental_conditions(:experimental_condition_time)
    assert_not_nil ec

    put :update, :id => ec.id, :sop_id => ec.sop.id, :experimental_condition => {:start_value => "10,02", :end_value => 50}
    ec_updated = assigns(:experimental_condition)
    assert_nil ec_updated
  end

  test 'should create ECs from the existing ECs' do
    ec_array = []
    user = Factory(:user)
    login_as(user)
    sop = Factory(:sop, :contributor => user)
    assert_equal sop.experimental_conditions.count, 0
    #create bunch of ECes which are different
    i=0
    while i < 3  do
      ec_array.push Factory(:experimental_condition, :start_value => i)
      i +=1
    end

    post :create_from_existing, :sop_id => sop.id, :version => sop.latest_version, "checkbox_#{ec_array.first.id}" => ec_array.first.id, "checkbox_#{ec_array[1].id}" => ec_array[1].id, "checkbox_#{ec_array[2].id}" => ec_array[2].id

    sop.reload
    assert_equal sop.experimental_conditions.count, 3
    #test substances
    substances_of_new_fses = []
    sop.experimental_conditions.each do |ec|
      assert_not_nil ec.experimental_condition_links
      substances_of_new_fses.push ec.experimental_condition_links.first.substance
    end
    substances_of_existing_fses = []
    ec_array.each do |ec|
      substances_of_existing_fses.push ec.experimental_condition_links.first.substance
    end
    assert_equal substances_of_existing_fses.sort{|a,b| a.id <=> b.id}, substances_of_new_fses.sort{|a,b| a.id <=> b.id}
  end

  test "should destroy EC" do
    ec = experimental_conditions(:experimental_condition_concentration_glucose)
    assert_not_nil ec
    assert_equal ec.measured_item, measured_items(:concentration)
    assert_equal ec.experimental_condition_links.first.substance, compounds(:compound_glucose)

    delete :destroy, :id => ec.id, :sop_id => sops(:editable_sop).id

    assert_nil ExperimentalCondition.find_by_id(ec.id)
    ec.experimental_condition_links.each do |ecl|
      assert_nil ExperimentalConditionLink.find_by_id(ecl.id)
    end
  end
end
