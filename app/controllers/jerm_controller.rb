class JermController < ApplicationController
  before_filter :login_required
  before_filter :is_user_admin_auth

  @@harvesters=nil

  def index
    
  end

  def test
    Sop.destroy_all
    Model.destroy_all
    DataFile.destroy_all

    project_id=params[:project]
    username=params[:name]
    password=params[:pwd]

    @project=Project.find(project_id)
    @project.decrypt_credentials
    
    begin
      harvester = construct_project_harvester(@project.title,@project.site_root_uri,@project.site_username,@project.site_password)
      @responses = harvester.update
      response_order=[:success,:fail,:skipped]
      @responses=@responses.sort_by{|a| response_order.index(a[:response])}
    rescue Exception => @exception
      puts @exception
    end

    render :update do |page|
      if @exception
        page.replace_html :results,:partial=>"exception",:object=>@exception
      else
        page.replace_html :results,:partial=>"results",:object=>@responses
      end
      
    end

  end

  private

  def construct_project_harvester project_name,root_uri,uname,pwd
    #removes hyphens from project name
    clean_project_name=project_name.gsub("-","")
    discover_harvesters if @@harvesters.nil?
    
    harvester_class=@@harvesters.find do |h|
      puts "comparing #{h.name.downcase} with #{clean_project_name.downcase}"
      h.name.downcase.starts_with?("jerm::"+clean_project_name.downcase)
    end
    raise Exception.new("Unable to find Harvester for project #{project_name}") if harvester_class.nil?
    return harvester_class.new(root_uri,uname,pwd)
  end

  def discover_harvesters
    Dir.chdir(File.join(RAILS_ROOT, "lib/jerm")) do
      Dir.glob("*harvester.rb").each do |f|
        ("jerm/" + f.gsub(/.rb/, '')).camelize.constantize
      end
    end
    harvesters=[]
    ObjectSpace.each_object(Class) do |c|
      harvesters << c if c < Jerm::Harvester
    end
    
    @@harvesters=harvesters
  end
end
