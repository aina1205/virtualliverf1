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
      policy = sharing_params_to_policy
      current_person = User.current_user.try(:person)
      contributor_person = (params['is_new_file'] == 'false') ?  User.find_by_id(params['contributor_id'].to_i).try(:person) : current_person
      creators = (params["creators"].blank? ? [] : ActiveSupport::JSON.decode(params["creators"])).uniq
      creators.collect!{|c| Person.find(c[1])}

      resource = resource_with_assigned_projects params[:resource_name],params[:resource_id],params[:project_ids]
      resource.policy = policy
      resource.creators = creators if resource.respond_to?:creators
      resource.contributor = contributor_person

      asset_managers = get_asset_managers resource

      privileged_people = {}
      #exclude the current_person from the privileged people
      contributor_person = nil if contributor_person == current_person
      creators.delete(current_person)
      asset_managers.delete(current_person)
      privileged_people['contributor'] = [contributor_person] if contributor_person
      privileged_people['creators'] = creators unless creators.empty?
      privileged_people['asset_managers'] = asset_managers unless asset_managers.empty?

      respond_to do |format|
        format.html { render :template=>"layouts/preview_permissions", :locals => {:policy => policy, :privileged_people => privileged_people, :updated_can_publish => updated_can_publish}}
      end
  end

  #To check where the can_publish? changes when changing the projects associated with the resource
  def updated_can_publish resource_name=params[:resource_name], resource_id=params[:resource_id], project_ids=params[:project_ids]
    resource = resource_with_assigned_projects resource_name, resource_id, project_ids
    if !resource.new_record? && resource.policy.sharing_scope == Policy::EVERYONE
      updated_can_publish = true
    else
      updated_can_publish = resource.can_publish?
    end
    updated_can_publish
  end

  protected
  def get_asset_managers resource
    asset_managers = []
    resource.projects.each do |project|
      asset_managers |= project.asset_managers
    end
    asset_managers.reject! { |am| !resource.perform_auth(am.user, 'manage') }
    asset_managers
  end
  def resource_with_assigned_projects resource_name, resource_id, project_ids
    resource_class = resource_name.camelize.constantize
     resource = resource_class.find_by_id(resource_id) || resource_class.new
     if resource.kind_of?Assay
       resource.study = Study.find_by_id(project_ids.to_i)
     elsif resource.kind_of?Study
        resource.investigation = Investigation.find_by_id(project_ids.to_i)
     else
       selected_projects = get_selected_projects project_ids, resource_name
       resource.projects = selected_projects
     end
     resource
  end

  def sharing_params_to_policy params=params
      policy =Policy.new()
      policy.sharing_scope = params["sharing_scope"].to_i
      policy.access_type = params["access_type"].to_i
      policy.use_whitelist = params["use_whitelist"] == 'true' ? true : false
      policy.use_blacklist = params["use_blacklist"] == 'true' ? true : false

      #now process the params for permissions
      contributor_types = params["contributor_types"].blank? ? [] : ActiveSupport::JSON.decode(params["contributor_types"])
      new_permission_data = params["contributor_values"].blank? ? {} : ActiveSupport::JSON.decode(params["contributor_values"])

      #if share with your project and with all_sysmo_user is chosen
      if (policy.sharing_scope == Policy::ALL_SYSMO_USERS)
          your_proj_access_type = params["project_access_type"].blank? ? nil : params["project_access_type"].to_i
          selected_projects = get_selected_projects params[:project_ids], params[:resource_name]
          selected_projects.each do |selected_project|
            project_id = selected_project.id
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

  def get_selected_projects project_ids, resource_name
    if (resource_name == 'study') and (!project_ids.blank?)
      investigation = Investigation.find_by_id(project_ids.to_i)
      projects = investigation.nil? ? [] : investigation.projects

      #when resource is assay, id of the study is sent, so get the project_ids from the study
    elsif (resource_name == 'assay') and (!project_ids.blank?)
      study = Study.find_by_id(project_ids.to_i)
      projects = study.nil? ? [] : study.projects
      #normal case, the project_ids is sent
    else
      project_ids = project_ids.blank? ? [] : project_ids.split(',')
      projects = []
      project_ids.each do |id|
        project = Project.find_by_id(id.to_i)
        projects << project if project
      end
    end
    projects
  end
end


