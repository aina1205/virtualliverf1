class PeopleController < ApplicationController
  
  before_filter :login_required
  before_filter :profile_belongs_to_current, :only=>[:edit, :update]
  before_filter :is_user_admin_auth, :only=>[:new, :destroy]
  
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
    if (!params[:expertise].nil?)
      @expertise_or_tools=params[:expertise]
      @people=Person.tagged_with(@expertise_or_tools, :on=>:expertise)
    elsif (!params[:tools].nil?)
      @expertise_or_tools=params[:tools]
      @people=Person.tagged_with(@expertise_or_tools, :on=>:tools)
    else
      @people = Person.find(:all, :order=>:last_name)
    end
    
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @people.to_xml}
    end
  end

  # GET /people/1
  # GET /people/1.xml
  def show
    @person = Person.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @person.to_xml}
    end
  end

  # GET /people/new
  # GET /people/new.xml
  def new
    @tags_tools = Person.tool_counts
    @tags_expertise = Person.expertise_counts

    @person = Person.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @person }
    end
  end

  # GET /people/1/edit
  def edit
    @tags_tools = Person.tool_counts
    @tags_expertise = Person.expertise_counts

    @person = Person.find(params[:id])
  end


  # POST /people
  # POST /people.xml
  def create
    @person = Person.new(params[:person])

    if !params[:tool].nil?
      tools_list = params[:tool][:list]
      @person.tool_list=tools_list
    end

    if !params[:expertise].nil?
      expertise_list = params[:expertise][:list]
      @person.expertise_list=expertise_list
    end
    
    respond_to do |format|
      if @person.save
        flash[:notice] = 'Person was successfully created.'
        format.html { redirect_to(@person) }
        format.xml  { render :xml => @person, :status => :created, :location => @person }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @person.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /people/1
  # PUT /people/1.xml
  def update
    @person = Person.find(params[:id])
    
    if !params[:tool].nil?
      tools_list = params[:tool][:list]
      @person.tool_list=tools_list
    end

    if !params[:expertise].nil?
      expertise_list = params[:expertise][:list]
      @person.expertise_list=expertise_list
    end
    
    respond_to do |format|
      if @person.update_attributes(params[:person])
        flash[:notice] = 'Person was successfully updated.'
        format.html { redirect_to(@person) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @person.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /people/1
  # DELETE /people/1.xml
  def destroy
    @person = Person.find(params[:id])
    @person.destroy

    respond_to do |format|
      format.html { redirect_to(people_url) }
      format.xml  { head :ok }
    end
  end
  
  private
  
  def profile_belongs_to_current
    @person=Person.find(params[:id])
    unless @person == current_user.person
      error("Not the current person", "is invalid (not owner)")
      return false
    end
  end
  
end
