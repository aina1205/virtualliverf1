module Seek
  class ContentStats
    
    class ProjectStats
      attr_accessor :project,:sops,:data_files,:models,:publications,:people,:assays,:studies,:investigations, :user
      
      def initialize
        @user=User.first
      end
      
      def data_files_size
        assets_size data_files
      end
      
      def sops_size
        assets_size sops
      end
      
      def models_size
        assets_size models
      end
      
      def visible_data_files
        authorised_assets data_files,"view"
      end
      
      def visible_sops
        authorised_assets sops,"view"
      end
      
      def visible_models
        authorised_assets models,"view"
      end
      
      def accessible_data_files
        authorised_assets data_files,"download"
      end
      
      def accessible_sops
        authorised_assets sops,"download"
      end
      
      def accessible_models
        authorised_assets models,"download"
      end
      
      def registered_people
        people.select{|p| !p.user.nil?}
      end
      
      private             
      
      def assets_size assets
        size=0
        assets.each do |asset|
          size += asset.content_blob.data.size unless asset.content_blob.data.nil?
        end
        return size
      end
    end  
    
    
    def self.generate    
      result=[]    
      Project.all.each do |project|
        project_stats=ProjectStats.new
        project_stats.project=project
        project_stats.sops=project.sops
        project_stats.models=project.models
        project_stats.data_files=project.data_files
        project_stats.publications=project.publications
        project_stats.people=project.people
        project_stats.assays=project.assays
        project_stats.studies=project.studies
        project_stats.investigations=project.investigations
        result << project_stats           
      end
      return result
    end
    
  end
end