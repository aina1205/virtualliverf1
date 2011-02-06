module Sergey
  module Acts #:nodoc:
    module Editable #:nodoc:
      def self.included(base)
        base.extend ClassMethods  
      end

      module ClassMethods
        def acts_as_editable
          include Sergey::Acts::Editable::InstanceMethods
          extend Sergey::Acts::Editable::SingletonMethods
        end
      end

      module SingletonMethods
      end

      module InstanceMethods
        # anything which is "editable" will inherit this method
        def can_be_edited_by?(subject)
          # NB!
          # assumption is made that check if the object in "self" is "mine"
          # was already made and was unsuccessful
          
          case self.class.name
            when "Person"
              # authorised to admins and project managers if the "person" doesn't have a user or the associated user is not an admin
              return((subject.is_admin? || subject.is_project_manager?) && (self.user.nil? || !self.is_admin?))
            when "Project"
              # authorised to admins and selected people within the project
              return(subject.is_admin? || (self.people.include?(subject.person) && subject.can_edit_projects?))
            when "Institution"
              # authorised to admins, selected people within the project, and people with a project management role in the institution
              return(subject.is_admin? ||
                  (self.people.include?(subject.person) && subject.can_edit_institutions?) ||
                  !self.work_groups.reduce([]){|sum,wg|sum + wg.group_memberships}.select{|gm| gm.person == subject.person and gm.roles.map{|r|r.name}.include?"Project Management"}.empty?)
            else
              # don't know what kind of object that is, not authorised
              return false
          end
        end
        
      end
      
    end
  end
end

ActiveRecord::Base.class_eval do
  include Sergey::Acts::Editable
end
