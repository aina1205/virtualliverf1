class PeopleController < ApplicationController
  
  #before_filter :login_required,:except=>[:select,:userless_project_selected_ajax,:create,:new]
  before_filter :find_and_auth, :only => [:show, :edit, :update, :destroy]
  before_filter :current_user_exists,:only=>[:select,:userless_project_selected_ajax,:create,:new]
  before_filter :profile_belongs_to_current_or_is_admin, :only=>[:edit, :update]
  before_filter :profile_is_not_another_admin_except_me, :only=>[:edit,:update]
  before_filter :is_user_admin_auth,:only=>[:destroy]
  before_filter :is_user_admin_or_personless, :only=>[:new]
  before_filter :auth_params,:only=>[:update,:create]

  skip_before_filter :project_membership_required
  skip_before_filter :profile_for_login_required,:only=>[:select,:userless_project_selected_ajax,:create]

  cache_sweeper :people_sweeper,:only=>[:update,:create,:destroy]

  def auto_complete_for_tools_name
    render :json => Person.tool_counts.map(&:name).to_json
  end

  def auto_complete_for_expertise_name
    render :json => Person.expertise_counts.map(&:name).to_json
  end
  
  protect_from_forgery :only=>[]
  
  # GET /people
  # GET /people.xml
  def index
    if (params[:discipline_id])
      @discipline=Discipline.find(params[:discipline_id])
      #FIXME: strips out the disciplines that don't match
      @people=Person.find(:all,:include=>:disciplines,:conditions=>["disciplines.id=?",@discipline.id])
      #need to reload the people to get their full discipline list - otherwise only get those matched above. Must be a better solution to this
      @people.each(&:reload)
    elsif (params[:project_role_id])
      @project_role=ProjectRole.find(params[:project_role_id])
      @people=Person.find(:all,:include=>[:group_memberships])
      #FIXME: this needs double checking, (a) not sure its right, (b) can be paged when using find.
      @people=@people.select{|p| !(p.group_memberships & @project_role.group_memberships).empty?}
    end

    unless @people
      @people = apply_filters(Person.all).select(&:can_view?)
      @people=Person.paginate_after_fetch(@people, :page=>params[:page])
    else
      @people = @people.select(&:can_view?)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml
    end
  end

  # GET /people/1
  # GET /people/1.xml
  def show                
    respond_to do |format|
      format.html # show.html.erb
      format.xml
    end
  end

  # GET /people/new
  # GET /people/new.xml
  def new    
    @person = Person.new

    respond_to do |format|
      format.html { render :action=>"new" }
      format.xml  { render :xml => @person }
    end
  end

  # GET /people/1/edit
  def edit
    possible_unsaved_data = "unsaved_#{@person.class.name}_#{@person.id}".to_sym
    if session[possible_unsaved_data]
      # if user was redirected to this 'edit' page from avatar upload page - use session
      # data; alternatively, user has followed some other route - hence, unsaved session
      # data is most probably not relevant anymore
      if params[:use_unsaved_session_data]
        # NB! these parameters are admin settings and regular users won't (and MUST NOT)
        # be able to use these; admins on the other hand are most likely to never change
        # any avatars - therefore, it's better to hide these attributes so they never get
        # updated from the session
        #
        # this was also causing a bug: when "upload new avatar" pressed, then new picture
        # uploaded and redirected back to edit profile page; at this poing *new* records
        # in the DB for person's work group memberships would already be created, which is an
        # error (if the following 3 lines are ever to be removed, the bug needs investigation)
        session[possible_unsaved_data][:person].delete(:work_group_ids)        
        
        # update those attributes of a person that we want to be updated from the session
        @person.attributes = session[possible_unsaved_data][:person]

        #FIXME: needs updating to handle new tools and expertise tag field
#        @person.tool_list = session[possible_unsaved_data][:tool][:list] if session[]
#        @person.expertise_list = session[possible_unsaved_data][:expertise][:list]
      end
      
      # clear the session data anyway
      session[possible_unsaved_data] = nil
    end
  end

  #GET /people/select
  #
  #Page for after registration that allows you to select yourself from a list of
  #people yet to be assigned, or create a new one if you don't exist
  def select
    @userless_projects=Project.with_userless_people

    #strip out project with no people with email addresses
    #TODO: can be made more efficient by putting into a direct query in Project.with_userless_people - but not critical as this is only used during registration
    @userless_projects = @userless_projects.select do |proj|
      !proj.people.find{|person| !person.email.nil? && person.user.nil?}.nil?
    end

    @userless_projects.sort!{|a,b|a.name<=>b.name}
    @person = Person.new(params[:openid_details]) #Add some default values gathered from OpenID, if provided.

    render :action=>"select"
  end

  # POST /people
  # POST /people.xml
  def create
    @person = Person.new(params[:person])
    redirect_action="new"

    set_tools_and_expertise(@person, params)
    set_roles(@person, params) if User.admin_logged_in?
   
    registration = false
    registration = true if (current_user.person.nil?) #indicates a profile is being created during the registration process  
    
    if registration    
      current_user.person=@person      
      @userless_projects=Project.with_userless_people
      @userless_projects.sort!{|a,b|a.name<=>b.name}
      is_sysmo_member=params[:sysmo_member]

      if (is_sysmo_member)
        member_details = ''
        member_details.concat(project_or_institution_details 'projects')
        member_details.concat(project_or_institution_details 'institutions')
      end

      redirect_action="select"
    end       
    
    respond_to do |format|
      if @person.save && current_user.save
        if (!current_user.active?)
          if_sysmo_member||=false
          Mailer.deliver_contact_admin_new_user_no_profile(member_details,current_user,base_host) if is_sysmo_member
          Mailer.deliver_signup(current_user,base_host)          
          flash[:notice]="An email has been sent to you to confirm your email address. You need to respond to this email before you can login"          
          logout_user
          format.html {redirect_to :controller=>"users",:action=>"activation_required"}
        else
          flash[:notice] = 'Person was successfully created.'
          format.html { redirect_to(@person) }
          format.xml  { render :xml => @person, :status => :created, :location => @person }
        end
        
      else        
        format.html { render :action => redirect_action }
        format.xml  { render :xml => @person.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /people/1
  # PUT /people/1.xml
  def update
    @person.disciplines.clear if params[:discipline_ids].nil?

    # extra check required to see if any avatar was actually selected (or it remains to be the default one)
    
    avatar_id = params[:person].delete(:avatar_id).to_i
    @person.avatar_id = ((avatar_id.kind_of?(Numeric) && avatar_id > 0) ? avatar_id : nil)
    
    set_tools_and_expertise(@person,params)    
    set_roles(@person, params) if User.admin_logged_in?

    if !@person.notifiee_info.nil?
      @person.notifiee_info.receive_notifications = (params[:receive_notifications] ? true : false) 
      @person.notifiee_info.save if @person.notifiee_info.changed?
    end

    
    respond_to do |format|
      if @person.update_attributes(params[:person]) && set_group_membership_project_role_ids(@person,params)
        @person.save #this seems to be required to get the tags to be set correctly - update_attributes alone doesn't [SYSMO-158]
         
        flash[:notice] = 'Person was successfully updated.'
        format.html { redirect_to(@person) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @person.errors, :status => :unprocessable_entity }
      end
    end
  end

  def set_group_membership_project_role_ids person,params
    #FIXME: Consider updating to Rails 2.3 and use Nested forms to handle this more cleanly.
    prefix="group_membership_role_ids_"
    person.group_memberships.each do |gr|
      key=prefix+gr.id.to_s
      gr.project_roles.clear
      if params[key.to_sym]
        params[key.to_sym].each do |r|
          r=ProjectRole.find(r)
          gr.project_roles << r
        end
      end
    end
  end

  # DELETE /people/1
  # DELETE /people/1.xml
  def destroy
    @person.destroy

    respond_to do |format|
      format.html { redirect_to(people_url) }
      format.xml  { head :ok }
    end
  end
  
  def userless_project_selected_ajax
    project_id=params[:project_id]
    unless project_id=="0"
      proj=Project.find(project_id)
      #ignore people with no email address
      @people=proj.userless_people.select{|person| !person.email.blank? }
      @people.sort!{|a,b| a.last_name<=>b.last_name}
      render :partial=>"userless_people_list",:locals=>{:people=>@people}
    else
      render :text=>""
    end
    
  end
  
  def get_work_group
    people = nil
    project_id=params[:project_id]
    institution_id=params[:institution_id]    
    if institution_id == "0"
      project = Project.find(project_id)
      people = project.people
    else
      workgroup = WorkGroup.find_by_project_id_and_institution_id(project_id,institution_id)
      people = workgroup.people
    end
    people_list = people.collect{|p| [p.name, p.email, p.id]}
    respond_to do |format|
      format.json {
        render :json => {:status => 200, :people_list => people_list }
      }
    end
  end

  private
  
  def set_tools_and_expertise person,params

      person.expertise =  params
      person.tools = params

      #FIXME: don't like this, but is a temp solution for handling lack of observer callback when removing a tag. Also should only expire when they have changed.
      expire_fragment("sidebar_tag_cloud")
      expire_fragment("super_tag_cloud")

  end

  def set_roles person, params
    if params[:roles]
      roles = []
      params[:roles].each_key do |key|
        roles << key
      end
      person.roles=roles
    else
      person.roles=[]
    end
  end

  def profile_belongs_to_current_or_is_admin
    @person=Person.find(params[:id])
    unless @person == current_user.person || User.admin_logged_in? || current_user.person.is_project_manager?
      error("Not the current person", "is invalid (not owner)")
      return false
    end
  end

  def profile_is_not_another_admin_except_me
    @person=Person.find(params[:id])
    if !@person.user.nil? && @person.user!=current_user && @person.user.is_admin?
      error("Cannot edit another Admins profile","is invalid(another admin)")
      return false
    end
  end

  def is_user_admin_or_personless
    unless User.admin_logged_in? || current_user.person.nil?
      error("You do not have permission to create new people","Is invalid (not admin)")
      return false
    end
  end

  def current_user_exists
    if !current_user
      redirect_to("/")
    end
    !!current_user
  end

  #checks the params attributes and strips those that cannot be set by non-admins, or other policy
  def auth_params
    # make sure to update people/_form if this changes
    #                   param                 => allowed access?
    restricted_params={:roles                 =>  User.admin_logged_in?,
                       :roles_mask            => User.admin_logged_in?,
                       :can_edit_projects     => (User.admin_logged_in? or current_user.is_project_manager?),
                       :can_edit_institutions => (User.admin_logged_in? or current_user.is_project_manager?)}
    restricted_params.each do |param, allowed|
      params[:person].delete(param) if params[:person] and not allowed
      params.delete param if params and not allowed
    end
  end
  def project_or_institution_details projects_or_institutions
    details = ''
    unless params[projects_or_institutions].blank?
        params[projects_or_institutions].each do |project_or_institution|
          project_or_institution_details= project_or_institution.split(',')
          if project_or_institution_details[0] == 'Others'
             details.concat("Other #{projects_or_institutions}: #{params["other_#{projects_or_institutions}"]}; ")
          else
             details.concat("#{projects_or_institutions.singularize.capitalize}: #{project_or_institution_details[0]}, Id: #{project_or_institution_details[1]}; ")
          end
        end
    end
    details
  end
end
