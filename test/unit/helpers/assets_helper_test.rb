require 'test_helper'

class AssetsHelperTest < ActionView::TestCase

  def setup
    User.destroy_all
    assert_blank User.all
    @user = Factory :user
    @project = Factory :project
  end

  def test_asset_version_links
    admin = Factory(:admin)
    User.with_current_user admin.user do
      model = Factory(:teusink_model, :contributor=>admin.user,:title=>"Teusink")
      v = Factory(:model_version, :model=>model)
      model.reload
      model_versions = model.versions
      assert_equal 2, model_versions.count
      model_version_links = asset_version_links model_versions
      assert_equal 2, model_version_links.count
      link1 = link_to('Teusink', "/models/#{model.id}" + "?version=1")
      link2 = link_to('Teusink', "/models/#{model.id}" + "?version=2")
      puts model_version_links
      assert model_version_links.include?link1
      assert model_version_links.include?link2
    end
  end

  test "authorised assets" do
    @assets = create_a_bunch_of_assets
    with_auth_lookup_disabled do
      check_expected_authorised
    end
  end

  test "authorised assets with lookup" do
    @assets = create_a_bunch_of_assets
    with_auth_lookup_enabled do

      assert_not_equal Sop.count,Sop.lookup_count_for_user(@user)
      assert !Sop.lookup_table_consistent?(@user.id)

      update_lookup_tables

      assert_equal DataFile.count,DataFile.lookup_count_for_user(@user.id)
      assert_equal Sop.count,Sop.lookup_count_for_user(@user.id)
      assert_equal Sop.count,Sop.lookup_count_for_user(@user)
      assert Sop.lookup_table_consistent?(@user.id)
      assert Sop.lookup_table_consistent?(nil)

      check_expected_authorised
    end
  end

  def check_expected_authorised
    User.current_user = @user
    authorised = authorised_assets Sop
    assert_equal 4,authorised.count
    assert_equal ["A","B","D","E"],authorised.collect{|a| a.title}.sort

    authorised = authorised_assets Sop,@project
    assert_equal 1,authorised.count
    assert_equal "A",authorised.first.title

    authorised = authorised_assets Sop,@user.person.projects
    assert_equal 1,authorised.count
    assert_equal "E",authorised.first.title

    authorised = authorised_assets Sop,nil,"manage"
    assert_equal 3,authorised.count
    assert_equal ["A","B","D"],authorised.collect{|a| a.title}.sort

    User.current_user = nil
    authorised = authorised_assets Sop
    assert_equal 3,authorised.count
    assert_equal ["A","D","E"],authorised.collect{|a| a.title}.sort

    User.current_user = Factory(:user)
    authorised = authorised_assets DataFile,nil,"download"
    assert_equal 2,authorised.count
    assert_equal ["A","B"],authorised.collect{|a| a.title}.sort

    authorised = authorised_assets DataFile,@project,"download"
    assert_equal 1,authorised.count
    assert_equal ["B"],authorised.collect{|a| a.title}

    User.current_user = nil
    authorised = authorised_assets DataFile
    assert_equal 2,authorised.count
    assert_equal ["A","B"],authorised.collect{|a| a.title}.sort
  end

  private

  def update_lookup_tables
    User.all.push(nil).each do |u|
      @assets.each{|a| a.update_lookup_table(u)}
    end

  end

  def create_a_bunch_of_assets
    disable_authorization_checks do
      Sop.delete_all
      DataFile.delete_all
    end
    assert_blank Sop.all
    assert_blank DataFile.all
    assets = []
    assets << Factory(:sop, :title=>"A",:policy=>Factory(:public_policy),:projects=>[@project])
    assets << Factory(:sop, :title=>"B",:contributor=>@user,:policy=>Factory(:private_policy))
    assets << Factory(:sop, :title=>"C",:policy=>Factory(:private_policy))
    assets << Factory(:sop, :title=>"D",:contributor=>@user,:policy=>Factory(:publicly_viewable_policy))
    assets << Factory(:sop, :title=>"E",:policy=>Factory(:publicly_viewable_policy),:projects=>@user.person.projects)

    assets << Factory(:data_file,:title=>"A",:contributor=>@user,:policy=>Factory(:downloadable_public_policy))
    assets << Factory(:data_file,:title=>"B",:policy=>Factory(:downloadable_public_policy),:projects=>[@project,Factory(:project)])
    assets
  end
end