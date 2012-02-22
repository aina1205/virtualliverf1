require 'test_helper'

class PeopleControllerTest < ActionController::TestCase
  
  fixtures :all
  
  include AuthenticatedTestHelper
  include RestTestCases
  
  def setup
    login_as(:quentin)
    @object=people(:quentin_person)
  end
  
  def test_title
    get :index
    assert_select "title", :text=>/The Sysmo SEEK People.*/, :count=>1
  end
  
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:people)
  end
  
  def test_should_get_new
    get :new
    assert_response :success
  end
  
  def test_first_registered_person_is_admin
    Person.destroy_all
    assert_equal 0,Person.count,"There should be no people in the database"
    login_as(:part_registered)
    assert_difference('Person.count') do
      assert_difference('NotifieeInfo.count') do
        post :create, :person => {:first_name=>"test", :email=>"hghg@sdfsd.com" }
      end
    end
    assert assigns(:person)
    person = Person.find(assigns(:person).id)
    assert person.is_admin?
  end
  
  def test_second_registered_person_is_not_admin
    Person.destroy_all
    person = Person.new(:first_name=>"fred",:email=>"fred@dddd.com")
    person.save!
    assert_equal 1,Person.count,"There should be 1 person in the database"
    login_as(:part_registered)
    assert_difference('Person.count') do
      assert_difference('NotifieeInfo.count') do
        post :create, :person => {:first_name=>"test", :email=>"hghg@sdfsd.com" }
      end
    end
    assert assigns(:person)
    person = Person.find(assigns(:person).id)
    assert !person.is_admin?
  end
  
  def test_should_create_person
    assert_difference('Person.count') do
      assert_difference('NotifieeInfo.count') do
        post :create, :person => {:first_name=>"test", :email=>"hghg@sdfsd.com" }
      end
    end
    
    assert_redirected_to person_path(assigns(:person))
    assert_equal "T", assigns(:person).first_letter
    assert_not_nil Person.find(assigns(:person).id).notifiee_info
  end

  def test_should_create_person_with_project
    work_group_id = Factory(:work_group).id
    assert_difference('Person.count') do
      assert_difference('NotifieeInfo.count') do
        post :create, :person => {:first_name=>"test", :email=>"hghg@sdfsd.com", :work_group_ids => [work_group_id] }
      end
    end

    assert_redirected_to person_path(assigns(:person))
    assert_equal "T", assigns(:person).first_letter
    assert_equal [work_group_id], assigns(:person).work_group_ids
    assert_not_nil Person.find(assigns(:person).id).notifiee_info
  end
  
  def test_created_person_should_receive_notifications
    post :create, :person => {:first_name=>"test", :email=>"hghg@sdfsd.com" }
    p=assigns(:person)
    assert_not_nil p.notifiee_info
    assert p.notifiee_info.receive_notifications?
  end
      
  test "non_admin_should_not_create_pal" do
    login_as(:pal_user)
    assert_difference('Person.count') do
      post :create, :person => {:first_name=>"test", :roles_mask => Person::ROLES_MASK_FOR_PAL, :email=>"hghg@sdfsd.com" }
    end

    p=assigns(:person)
    assert_redirected_to person_path(p)
    assert !p.is_pal?
    assert !Person.find(p.id).is_pal?
  end
  
  def test_should_show_person
    get :show, :id => people(:quentin_person)
    assert_response :success
  end
  
  def test_should_get_edit
    get :edit, :id => people(:quentin_person)
    assert_response :success
  end

  def test_non_admin_cant_edit_someone_else
    login_as(:fred)
    get :edit, :id=> people(:aaron_person)
    assert_redirected_to people(:aaron_person)
  end

  def test_project_manager_can_edit_others
    login_as(:project_manager)
    get :edit, :id=> people(:aaron_person)
    assert_response :success
  end
  
  def test_admin_can_edit_others
    get :edit, :id=>people(:aaron_person)
    assert_response :success
  end    
  
  def test_change_notification_settings
    login_as(:quentin)
    p=people(:fred)
    assert p.notifiee_info.receive_notifications?,"should receive noticiations by default in fixtures"
    
    put :update, :id=>p.id, :person=>{:id=>p.id}
    assert !Person.find(p.id).notifiee_info.receive_notifications?
    
    put :update, :id=>p.id, :person=>{:id=>p.id},:receive_notifications=>true
    assert Person.find(p.id).notifiee_info.receive_notifications?
    
  end
  
  def test_admin_can_set_is_admin_flag
    login_as(:quentin)
    p=people(:fred)
    assert !p.is_admin?
    put :update, :id=>p.id, :person=>{:id=>p.id, :roles_mask=>Person::ROLES_MASK_FOR_ADMIN, :email=>"ssfdsd@sdfsdf.com"}
    assert_redirected_to person_path(p)
    assert_nil flash[:error]
    p.reload
    assert p.is_admin?
  end
  
  def test_non_admin_cant_set__is_admin_flag
    login_as(:aaron)
    p=people(:fred)
    assert !p.is_admin?
    put :update, :id=>p.id, :person=>{:id=>p.id, :roles_mask=>Person::ROLES_MASK_FOR_ADMIN, :email=>"ssfdsd@sdfsdf.com"}
    assert_not_nil flash[:error]
    p.reload
    assert !p.is_admin?
  end
  
  def test_admin_can_set_pal_flag
    login_as(:quentin)
    p=people(:fred)
    assert !p.is_pal?
    put :update, :id=>p.id, :person=>{:id=>p.id, :email=>"ssfdsd@sdfsdf.com"}, :roles => {:pal => true}
    assert_redirected_to person_path(p)
    assert_nil flash[:error]
    p.reload
    assert p.is_pal?
  end
  
  def test_non_admin_cant_set_pal_flag
    login_as(:aaron)
    p=people(:fred)
    assert !p.is_pal?
    put :update, :id=>p.id, :person=>{:id=>p.id, :email=>"ssfdsd@sdfsdf.com"}, :roles => {:pal => true}
    assert_not_nil flash[:error]
    p.reload
    assert !p.is_pal?
  end
  
  def test_cant_set_yourself_to_pal
    login_as(:aaron)
    p=people(:aaron_person)
    assert !p.is_pal?
    put :update, :id=>p.id, :person=>{:id=>p.id, :email=>"ssfdsd@sdfsdf.com"}, :roles => {:pal => true}
    p.reload
    assert !p.is_pal?
  end
  
  def test_cant_set_yourself_to_admin
    login_as(:aaron)
    p=people(:aaron_person)
    assert !p.is_admin?
    put :update, :id=>p.id, :person=>{:id=>p.id, :roles_mask=>Person::ROLES_MASK_FOR_ADMIN, :email=>"ssfdsd@sdfsdf.com"}
    p.reload
    assert !p.is_admin?
  end
  
  def test_non_admin_cant_set_can_edit_institutions
    login_as(:aaron)
    p=people(:aaron_person)
    assert !p.can_edit_institutions?
    put :update, :id=>p.id, :person=>{:id=>p.id, :can_edit_institutions=>true, :email=>"ssfdsd@sdfsdf.com"}        
    p.reload
    assert !p.can_edit_institutions?
  end
  
  def test_non_admin_cant_set_can_edit_projects
    login_as(:aaron)
    p=people(:aaron_person)
    assert !p.can_edit_projects?
    put :update, :id=>p.id, :person=>{:id=>p.id, :can_edit_projects=>true, :email=>"ssfdsd@sdfsdf.com"}        
    p.reload
    assert !p.can_edit_projects?
  end
  
  def test_can_edit_person_and_user_id_different
    #where a user_id for a person are not the same
    login_as(:fred)
    get :edit, :id=>people(:fred)
    assert_response :success
  end
  
  def test_not_current_user_doesnt_show_link_to_change_password
    get :edit, :id => people(:aaron_person)
    assert_select "a", :text=>"Change password", :count=>0
  end
  
  def test_current_user_shows_seek_id
    login_as(:quentin)
    get :show, :id=> people(:quentin_person)    
    assert_select ".box_about_actor p", :text=>/Seek ID: /m
    assert_select ".box_about_actor p", :text=>/Seek ID: .*#{people(:quentin_person).id}/m, :count=>1
  end
  
  def test_not_current_user_doesnt_show_seek_id
    get :show, :id=> people(:aaron_person)
    assert_select ".box_about_actor p", :text=>/Seek ID :/, :count=>0
  end

  def test_current_user_shows_login_name
    current_user = Factory(:person).user
    login_as(current_user)
    get :show, :id=> current_user.person
    assert_select ".box_about_actor p", :text=>/Login/m
    assert_select ".box_about_actor p", :text=>/Login.*#{current_user.login}/m
  end

  def test_not_current_user_doesnt_show_login_name
    current_user = Factory(:person).user
    other_person = Factory(:person)
    login_as(current_user)
    get :show, :id=> other_person
    assert_select ".box_about_actor p", :text=>/Login/m,:count=>0
  end

  def test_admin_sees_non_current_user_login_name
    current_user = Factory(:admin).user
    other_person = Factory(:person)
    login_as(current_user)
    get :show, :id=> other_person
    assert_select ".box_about_actor p", :text=>/Login/m
    assert_select ".box_about_actor p", :text=>/Login.*#{other_person.user.login}/m
  end
  
  def test_should_update_person
    put :update, :id => people(:quentin_person), :person => { }
    assert_redirected_to person_path(assigns(:person))
  end
  
  def test_should_not_update_somebody_else_if_not_admin
    login_as(:aaron)
    quentin=people(:quentin_person)
    put :update, :id => people(:quentin_person), :person => {:email=>"kkkkk@kkkkk.com" }    
    assert_not_nil flash[:error]
    quentin.reload
    assert_equal "quentin@email.com",quentin.email
  end
  
  def test_should_destroy_person
    assert_difference('Person.count', -1) do
      delete :destroy, :id => people(:quentin_person)
    end
    
    assert_redirected_to people_path
  end
  
  def test_should_add_nofollow_to_links_in_show_page
    get :show, :id=> people(:person_with_links_in_description)    
    assert_select "div#description" do
      assert_select "a[rel=nofollow]"
    end
  end

  test "filtering by project" do
    project=projects(:sysmo_project)
    get :index, :filter => {:project => project.id}
    assert_response :success
  end

  test "finding by role" do
    role=project_roles(:member)
    get :index,:project_role_id=>role.id
    assert_response :success
    assert assigns(:people)
    assert assigns(:people).include?(people(:person_for_model_owner))
  end

  test "admin can manage person" do
    login_as(:quentin)
    person = people(:aaron_person)
    assert person.can_manage?
  end

  test "non-admin users + anonymous users can not manage person " do
    login_as(:aaron)
    person =  people(:quentin_person)
    assert !person.can_manage?

    logout
    assert !person.can_manage?
  end

  test 'should remove every permissions set on the person before deleting him' do
    login_as(:quentin)
    person = Factory(:person)
    #create bunch of permissions on this person
    i = 0
    while i < 10
      Factory(:permission, :contributor => person, :access_type => rand(5))
      i += 1
    end
    permissions = Permission.find(:all, :conditions => ["contributor_type =? and contributor_id=?", 'Person', person.try(:id)])
    assert_equal 10, permissions.count

    assert_difference('Person.count', -1) do
      delete :destroy, :id => person
    end

    permissions = Permission.find(:all, :conditions => ["contributor_type =? and contributor_id=?", 'Person', person.try(:id)])
    assert_equal 0, permissions.count
  end

  test 'should set the manage right on pi before deleting the person' do
    login_as(:quentin)

    project = Factory(:project)
    work_group = Factory(:work_group, :project => project)
    person = Factory(:person_in_project, :group_memberships => [Factory(:group_membership, :work_group => work_group)])
    user = Factory(:user, :person => person)
    #create a datafile that this person is the contributor
    data_file = Factory(:data_file, :contributor => user, :projects => [project])
    #create pi
    role = ProjectRole.find_by_name('PI')
    pi =  Factory(:person_in_project, :group_memberships => [Factory(:group_membership, :work_group => work_group)])
    pi.group_memberships.first.project_roles << role
    pi.save
    assert_equal pi, project.pis.first

    assert_difference('Person.count', -1) do
      delete :destroy, :id => person
    end

    permissions_on_person = Permission.find(:all, :conditions => ["contributor_type =? and contributor_id=?", 'Person', person.try(:id)])
    assert_equal 0, permissions_on_person.count

    permissions = data_file.policy.permissions

    assert_equal 1, permissions.count
    assert_equal pi.id, permissions.first.contributor_id
    assert_equal Policy::MANAGING, permissions.first.access_type
  end

  test 'should set the manage right on pal (if no pi) before deleting the person' do
    login_as(:quentin)

    project = Factory(:project)
    work_group = Factory(:work_group, :project => project)
    person = Factory(:person_in_project, :group_memberships => [Factory(:group_membership, :work_group => work_group)])
    user = Factory(:user, :person => person)
    #create a datafile that this person is the contributor and with the same project
    data_file = Factory(:data_file, :contributor => user, :projects => [project])
    #create pal
    role = ProjectRole.find_by_name('Sysmo-DB Pal')
    pal =  Factory(:person_in_project, :group_memberships => [Factory(:group_membership, :work_group => work_group)])
    pal.group_memberships.first.project_roles << role
    pal.is_pal = true
    pal.save
    assert_equal pal, project.pals.first
    assert_equal 0, project.pis.count

    assert_difference('Person.count', -1) do
      delete :destroy, :id => person
    end

    permissions_on_person = Permission.find(:all, :conditions => ["contributor_type =? and contributor_id=?", 'Person', person.try(:id)])
    assert_equal 0, permissions_on_person.count

    permissions = data_file.policy.permissions

    assert_equal 1, permissions.count
    assert_equal pal.id, permissions.first.contributor_id
    assert_equal Policy::MANAGING, permissions.first.access_type
  end

  test 'set pal role for a person' do
   work_group_id = Factory(:work_group).id
    assert_difference('Person.count') do
      assert_difference('NotifieeInfo.count') do
        post :create, :person => {:first_name=>"test", :email=>"hghg@sdfsd.com", :work_group_ids => [work_group_id]}, :roles => {:pal => true}
      end
    end
    person = assigns(:person)
    person.reload
    assert_not_nil person
    assert person.is_pal?
  end

  test 'set project_manager role for a person' do
    work_group_id = Factory(:work_group).id
    assert_difference('Person.count') do
      assert_difference('NotifieeInfo.count') do
        post :create, :person => {:first_name=>"test", :email=>"hghg@sdfsd.com", :work_group_ids => [work_group_id]}, :roles => {:project_manager => true}
      end
    end
    person = assigns(:person)
    person.reload
    assert_not_nil person
    assert person.is_project_manager?
  end

  test 'update roles for a person' do
    person = Factory(:pal)
    assert_not_nil person
    assert person.is_pal?

    put :update, :id => person.id, :person => {:id => person.id}, :roles => {:project_manager => true}

    person = assigns(:person)
    person.reload
    assert_not_nil person
    assert person.is_project_manager?
    assert !person.is_pal?
  end

  test 'update roles for yourself, but keep the admin role' do
    person = User.current_user.person
    assert person.is_admin?
    assert_equal 1, person.roles.count

    put :update, :id => person.id, :person => {:id => person.id}, :roles => {:project_manager => true}

    person = assigns(:person)
    person.reload
    assert_not_nil person
    assert person.is_project_manager?
    assert person.is_admin?
    assert_equal 2, person.roles.count
  end

  test 'set the asset manager role for a person' do
   work_group_id = Factory(:work_group).id
    assert_difference('Person.count') do
      assert_difference('NotifieeInfo.count') do
        post :create, :person => {:first_name=>"assert manager", :email=>"asset_manager@sdfsd.com", :work_group_ids => [work_group_id]}, :roles => {:asset_manager => true}
      end
    end
    person = assigns(:person)
    person.reload
    assert_not_nil person
    assert person.is_asset_manager?
  end

  test 'admin should see the session of assigning the asset manager role to a person' do
    person = Factory(:person)
    get :admin, :id => person
    puts @response.body
    assert_select "input#_roles_asset_manager", :count => 1
  end

  test 'non-admin should not see the session of assigning the asset manager role to a person' do
    login_as(:aaron)
    person = Factory(:person)
    get :admin, :id => person
    assert_select "input#_roles_asset_manager", :count => 0
  end

  test 'should show that the person is asset manager for admin' do
    person = Factory(:person)
    person.is_asset_manager = true
    person.save
    get :show, :id => person
    assert_select "li", :text => /This person is an asset manager/, :count => 1
  end

  test 'should not show that the person is asset manager for non-admin' do
    person = Factory(:person)
    person.is_asset_manager = true
    person.save
    login_as(:aaron)
    get :show, :id => person
    assert_select "li", :text => /This person is an asset manager/, :count => 0
  end

   def test_project_manager_can_administer_others
    login_as(:project_manager)
    get :admin, :id=> people(:aaron_person)
    assert_response :success
  end

  def test_admin_can_administer_others
    login_as(:quentin)
    get :admin, :id=>people(:aaron_person)
    assert_response :success

  end

  test 'non-admin can not administer others' do
    login_as(:fred)
    get :admin, :id=> people(:aaron_person)
    assert_redirected_to :root
  end

  test 'can not administer yourself' do
    aaron = people(:aaron_person)
    login_as(aaron.user)
    get :admin, :id=> aaron
    assert_redirected_to :root
  end

end
