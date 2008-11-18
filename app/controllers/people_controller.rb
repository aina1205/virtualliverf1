class PeopleController < ApplicationController
  
  before_filter :login_required
  before_filter :is_current_user_auth, :only=>[:edit, :update]
  before_filter :is_user_admin_auth, :only=>[:new, :destroy]
  
  fast_auto_complete_for :expertise, :name
  
  protect_from_forgery :only=>[]


  
  # GET /people
  # GET /people.xml
  def index
    @people = Person.find(:all, :order=>:last_name)
    
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
    @person = Person.new
   
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @person }
    end
  end

  # GET /people/1/edit
  def edit
    @person = Person.find(params[:id])
  end

  # POST /people
  # POST /people.xml
  def create
    @person = Person.new(params[:person])
    expertise_list = params[:expertise].nil? ? "" : params[:expertise][:name] 
    update_person_expertise(@person, expertise_list)

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
    
    if !params[:expertise].nil?
      expertise_list = params[:expertise][:name]
      update_person_expertise(@person, expertise_list)
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
  
  def update_person_expertise person, expertise_list
    #FIXME: don't clear them all, check what has been removed. 
    person.expertises.clear
    expertise_list.split(",").each do |exp|
      exp.strip!
      exp.capitalize!
      e=Expertise.find(:first, :conditions=>{:name=>exp})
      if (e.nil?)
        e=Expertise.new(:name=>exp)
        e.save
        person.expertises << e
      else
        person.expertises << e unless person.expertises.include?(e)
      end
    end
  end
  
end
