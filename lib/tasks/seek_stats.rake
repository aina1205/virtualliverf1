require 'rubygems'
require 'rake'
require 'active_record/fixtures'
require 'uuidtools'

namespace :seek_stats do


  task(:activity=>:environment) do
    actions = ["download","create"]
    types = [nil,"Model","Sop","Presentation","DataFile","Publication","Investigation","Study","Assay"]
    actions.each do |action|
      types.each do |type|
        activity_for_action action,type
      end
    end

  end

  #filesizes and versions across projects
  task(:filesizes_and_versions => :environment) do
    types=[Model, Sop, Presentation, DataFile]

    types.each do |type|
      filename="#{Rails.root}/tmp/filesizes-and-versions-#{type.name}.csv"
      File.open(filename, "w") do |file|
        file << "type,id,created_at,filesize,content-type,version,project_id,project_name\n"
        type.find(:all,:order=>:created_at).each do |asset|
          file << "#{type.name}"
          file << ","
          file << asset.id
          file << ","
          file << %!"#{asset.created_at}"!
          file << ","
          blobs = asset.respond_to?(:content_blobs) ? asset.content_blobs : [asset.content_blob]
          size = blobs.compact.collect{|blob| blob.filesize}.compact.reduce(0,:+)
          c_types = blobs.compact.collect{|blob| blob.content_type}.join(", ")
          file << size
          file << ","
          file << %!"#{c_types}"!
          file << ","
          file << asset.version
          file << ","
          project = asset.projects.first
          file << project.id
          file << ","
          file << %!"#{project.title}"!
          file << "\n"
        end
      end
      puts "csv written to #{filename}"
    end

  end

  #things linked to publications


  def activity_for_action action,type=nil,controller_name=nil

    conditions = {:action=>action,:activity_loggable_type=>type,:controller_name=>controller_name}
    conditions = conditions.delete_if{|k,v| v.nil?}

    filename="#{Rails.root}/tmp/activity-#{action}-#{type || "all"}.csv"
    logs = ActivityLog.find(:all,:conditions=>conditions,:order=>:created_at)
    File.open(filename, "w") do |file|
      file << "date,month,type,id,controller,action,project_id,project_name,person_id,person_projects_ids"
      logs.each do |log|
        file << %!"#{log.created_at}"!
        file << ","
        file << %!"#{Date::MONTHNAMES[log.created_at.month]} #{log.created_at.year}"!
        file << ","
        file << log.activity_loggable_type
        file << ","
        file << log.activity_loggable_id
        file << ","
        file << log.controller_name
        file << ","
        file << action
        file << ","
        project = !log.activity_loggable.nil? && log.activity_loggable.respond_to?(:projects) ? log.activity_loggable.projects.first : nil
        if project
          file << project.id
          file << ","
          file << %!"#{project.title}"!

        else
          file <<%!"",""!
        end
        culprit = log.culprit
        if culprit && culprit.person
          file << culprit.person.id
          file << ","
          file << %!"#{culprit.person.projects.collect{|p| p.id}.join(",")}"!
        else
          file << "anonymous,na"
        end

        file << "\n"
      end
    end

    puts "csv written to #{filename}"
  end

end