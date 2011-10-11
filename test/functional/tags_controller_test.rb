require 'test_helper'

class TagsControllerTest < ActionController::TestCase
  
  include AuthenticatedTestHelper

  def setup
    login_as Factory(:user,:person => Factory(:person))
  end

  test "show for expertise tag" do
    p=Factory :person
    exp=Factory :expertise,:value=>"golf",:source=>p.user,:annotatable=>p
    get :show,:id=>exp.value
    assert_response :success
    assert_select "div.list_items_container" do
      assert_select "a",:text=>p.name,:count=>1
    end
  end

  test "show for tools tag" do
    p=Factory :person
    tool=Factory :tool,:value=>"spade",:source=>p.user,:annotatable=>p
    get :show,:id=>tool.value
    assert_response :success
    assert_select "div.list_items_container" do
      assert_select "a",:text=>p.name,:count=>1
    end
  end

  test "show for general tag" do
    df=Factory :data_file,:policy=>Factory(:public_policy)
    private_df = Factory :data_file,:policy=>Factory(:private_policy)
    tag=Factory :tag,:value=>"a tag",:source=>User.current_user,:annotatable=>df
    get :show,:id=>tag.value
    assert_response :success
    assert_select "div.list_items_container" do
      assert_select "a",:text=>df.title,:count=>1
      assert_select "a",:text=>private_df.title,:count=>0
    end
  end

  test "index" do
    p=Factory :person

    df=Factory :data_file,:contributor=>p
    df2=Factory :data_file,:contributor=>p
    p2=Factory :person
    tool=Factory :tool,:value=>"fork",:source=>p.user,:annotatable=>p
    exp=Factory :expertise,:value=>"fishing",:source=>p.user,:annotatable=>p
    tag=Factory :tag,:value=>"twinkle",:source=>p.user,:annotatable=>df

    #to make sure tags only appear once
    tag2=Factory :tag,:value=>tag.value,:source=>p2.user,:annotatable=>df2

    #to make sure only tools, tags and expertise are included
    bogus=Factory :tag,:value=>"frog",:source=>p.user,:annotatable=>df,:attribute_name=>"bogus"

    login_as p.user
    get :index
    assert_response :success

    assert_select "div#super_tag_cloud a[href=?]",show_ann_path(tag.value),:text=>"twinkle",:count=>1
    assert_select "div#super_tag_cloud a[href=?]",show_ann_path(tool.value),:text=>"fork",:count=>1
    assert_select "div#super_tag_cloud a[href=?]",show_ann_path(exp.value),:text=>"fishing",:count=>1

    #this shouldn't show up because its not a tag,tool or expertise attribute
    assert_select "div#super_tag_cloud a[href=?]",show_ann_path(bogus.value),:text=>"frog",:count=>0
  end

  test "dont show duplicates for same tag for expertise and tools" do
    p=Factory :person
    tool=Factory :tool,:value=>"xxxxx",:source=>p.user,:annotatable=>p
    exp=Factory :expertise,:value=>"xxxxx",:source=>p.user,:annotatable=>p

    login_as p.user
    get :index
    assert_response :success


    get :show,:id=>tool.value
    assert_response :success
    assert_select "div.list_items_container" do
      assert_select "a",:text=>p.name,:count=>1
    end
  end
end
