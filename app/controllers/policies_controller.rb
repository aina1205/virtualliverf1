require 'white_list_helper'

class PoliciesController < ApplicationController
  include WhiteListHelper
  
  before_filter :login_required
  
  def send_policy_data
    request_type = white_list(params[:policy_type])
    entity_type = white_list(params[:entity_type])
    entity_id = white_list(params[:entity_id])
    
    # NB! default policies now are only suppoted by Projects (but not Institutions / WorkGroups) -
    # so supplying any other type apart from Project will cause the return error message
    if request_type.downcase == "default" && entity_type == "Project" 
      supported = true
      
      # check that current user (the one sending AJAX request to get data from this handler)
      # is a member of the project for which they try to get the default policy
      authorized = current_user.person.projects.include? Project.find(entity_id)
    else
      supported = false
    end
    
    # only fetch all the policy/permissions settings if authorized to do so & only for request types that are supported
    if supported && authorized
      begin
        entity = entity_type.constantize.find entity_id
        found_entity = true
        policy = nil
        
        if entity.default_policy
          # associated default policy exists
          found_exact_match = true
          policy = entity.default_policy
        else
          # no associated default policy - use system default
          found_exact_match = false
          policy = Policy.default()
        end
        
      rescue ActiveRecord::RecordNotFound
        found_entity = false
      end
    end
    
    respond_to do |format|
      format.json {
        if supported && authorized && found_entity
          policy_settings = policy.get_settings
          permission_settings = policy.get_permission_settings
          
          render :json => {:status => 200, :found_exact_match => found_exact_match, :policy => policy_settings, 
                           :permission_count => permission_settings.length, :permissions => permission_settings }
        elsif supported && authorized && !found_entity
          render :json => {:status => 404, :error => "Couldn't find #{entity_type} with ID #{entity_id}."}
        elsif supported && !authorized
          render :json => {:status => 403, :error => "You are not authorized to view policy for that #{entity_type}."}
        else
          render :json => {:status => 400, :error => "Requests for default project policies are only supported at the moment."}
        end
      }
    end
  end

  def preview_permissions
      set_no_layout
      creators = (params["creators"].blank? ? [] : ActiveSupport::JSON.decode(params["creators"])).uniq
      creators.collect!{|c| Person.find(c[1])}
      asset_managers = []
      selected_projects = get_selected_projects
      selected_projects.each do |project|
        asset_managers |= project.asset_managers
      end

      policy = sharing_params_to_policy
      if policy.sharing_scope.blank? && policy.access_type.blank?
        flash[:error] = "Sharing policy is invalid.\nPlease select who may access the item by defining a sharing policy."
      else
        flash[:error] = nil
        if params['is_new_file'] == 'false'
          contributor = try_block{User.find_by_id(params['contributor_id'].to_i).person}
          grouped_people_by_access_type = policy.summarize_permissions creators, asset_managers, contributor
        else
          grouped_people_by_access_type = policy.summarize_permissions creators, asset_managers
        end
      end

      respond_to do |format|
        format.html { render :template=>"layouts/preview_permissions", :locals => {:grouped_people_by_access_type => grouped_people_by_access_type}}
      end
  end

  protected
  def sharing_params_to_policy params=params
      policy =Policy.new()
      policy.sharing_scope = params["sharing_scope"].to_i unless params[:sharing_scope].blank?
      policy.access_type = params["access_type"].to_i unless params[:access_type].blank?
      policy.use_whitelist = params["use_whitelist"] == 'true' ? true : false
      policy.use_blacklist = params["use_blacklist"] == 'true' ? true : false

      #now process the params for permissions
      contributor_types = params["contributor_types"].blank? ? [] : ActiveSupport::JSON.decode(params["contributor_types"])
      new_permission_data = params["contributor_values"].blank? ? {} : ActiveSupport::JSON.decode(params["contributor_values"])

      #if share with your project and with all_sysmo_user is chosen
      if (policy.sharing_scope == Policy::ALL_SYSMO_USERS)
          your_proj_access_type = params["project_access_type"].blank? ? nil : params["project_access_type"].to_i
          project_ids = []
          #when resource is study, id of the investigation is sent, so get the project_ids from the investigation
          if (params["resource_name"] == 'study') and (!params["project_ids"].blank?)
            investigation = Investigation.find_by_id(try_block{params["project_ids"].to_i})
            project_ids = try_block{investigation.projects.collect{|p| p.id}}

          #when resource is assay, id of the study is sent, so get the project_ids from the study
          elsif (params["resource_name"] == 'assay') and (!params["project_ids"].blank?)
            study = Study.find_by_id(try_block{params["project_ids"].to_i})
            project_ids = try_block{study.projects.collect{|p| p.id}}
          #normal case, the project_ids is sent
          else
            project_ids = params["project_ids"].blank? ? [] : params["project_ids"].split(',')
          end
          project_ids.each do |project_id|
            project_id = project_id.to_i
            #add Project to contributor_type
            contributor_types << "Project" if !contributor_types.include? "Project"
            #add one hash {project.id => {"access_type" => sharing[:your_proj_access_type].to_i}} to new_permission_data
            if !new_permission_data.has_key?('Project')
              new_permission_data["Project"] = {project_id => {"access_type" => your_proj_access_type}}
            else
              new_permission_data["Project"][project_id] = {"access_type" => your_proj_access_type}
            end
          end
      end

      #build permissions
      contributor_types.each do |contributor_type|
         new_permission_data[contributor_type].each do |key, value|
           policy.permissions.build(:contributor_type => contributor_type, :contributor_id => key, :access_type => value.values.first)
         end
      end
    policy
  end

  def get_selected_projects params=params
    if (params["resource_name"] == 'study') and (!params["project_ids"].blank?)
      investigation = Investigation.find_by_id(params["project_ids"].to_i)
      projects = investigation.projects

      #when resource is assay, id of the study is sent, so get the project_ids from the study
    elsif (params["resource_name"] == 'assay') and (!params["project_ids"].blank?)
      study = Study.find_by_id(params["project_ids"].to_i)
      projects = study.projects
      #normal case, the project_ids is sent
    else
      project_ids = params["project_ids"].blank? ? [] : params["project_ids"].split(',')
      projects = []
      project_ids.each do |id|
        project = Project.find_by_id(id.to_i)
        projects << project if project
      end
    end
    projects
  end
end


