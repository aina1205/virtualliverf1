class SpecimensController < ApplicationController
  # To change this template use File | Settings | File Templates.


  before_filter :find_assets, :only => [:index]
  before_filter :find_and_auth, :only => [:show, :update, :edit, :destroy]

  include IndexPager

  def new
    @specimen = Specimen.new
    respond_to do |format|

      format.html # new.html.erb
    end
  end

  def create
    @specimen = Specimen.new(params[:specimen])
    @specimen.contributor = current_user
    @specimen.project_id = params[:project_id]

    policy_err_msg = Policy.create_or_update_policy(@specimen, current_user, params)
    #Add creators
    AssetsCreator.add_or_update_creator_list(@specimen, params[:creators])

    respond_to do |format|
      if @specimen.save
        if policy_err_msg.blank?
          flash[:notice] = 'Specimen was successfully created.'
          format.html { redirect_to(@specimen) }
          format.xml  { head :ok }
        else
          flash[:notice] = "Specimen metadata was successfully updated. However some problems occurred, please see these below.</br></br><span style='color: red;'>" + policy_err_msg + "</span>"
        end
      else
       # Policy.create_or_update_policy(@specimen, current_user, params)
        format.html { render :action => "new" }
      end
    end
  end

  def update

    #update project
    @specimen.project_id = params[:project_id]

   policy_err_msg = Policy.create_or_update_policy(@specimen, current_user, params)
    #update creators
    AssetsCreator.add_or_update_creator_list(@specimen, params[:creators])
     respond_to do |format|
      if @specimen.update_attributes params[:specimen]
        if policy_err_msg.blank?
          flash[:notice] = 'Specimen was successfully updated.'
          format.html { redirect_to(@specimen) }
          format.xml  { head :ok }
        else
          flash[:notice] = "Specimen metadata was successfully updated. However some problems occurred, please see these below.</br></br><span style='color: red;'>" + policy_err_msg + "</span>"
        end
      else
        format.html { render :action => "edit" }
      end

    end
  end

  def destroy
    respond_to do |format|
      if @specimen.destroy
        format.html { redirect_to(specimens_path) }
        format.xml { head :ok }
      else
        flash.now[:error]="Unable to delete the specimen" if !@specimen.institution.nil?
        format.html { render :action=>"show" }
        format.xml { render :xml => @specimen.errors, :status => :unprocessable_entity }
      end
    end
  end


  def project_selected_ajax

    if params[:project_id] && params[:project_id]!="0"
      ins=Project.find(params[:project_id]).institutions

    end
    ins||=[]

    render :update do |page|

      page.replace_html "institution_collection", :partial=>"specimens/institutions_list", :locals=>{:ins=>ins, :project_id=>params[:project_id]}
    end

  end


end
