module Acts #:nodoc:
  module Authorized #:nodoc:
    def self.included(mod)
      mod.extend(ClassMethods)
    end

    def authorization_supported?
      self.class.authorization_supported?
    end

    module ClassMethods
      def acts_as_authorized
        belongs_to :contributor, :polymorphic => true

        #checks a policy exists, and if missing resorts to using a private policy
        before_save :policy_or_default

        belongs_to :project

        belongs_to :policy

        class_eval do
          extend Acts::Authorized::SingletonMethods
        end
        include Acts::Authorized::InstanceMethods

      end

      def authorization_supported?
        include?(Acts::Authorized::InstanceMethods)
      end

    end

    module SingletonMethods
    end

    module InstanceMethods
      # this method will take attributions' association and return a collection of resources,
      # to which the current resource is attributed

      def contributor_credited?
        true
      end

      def policy_or_default
        if self.policy.nil?
          self.policy = Policy.private_policy
        end
      end

      def can_edit? user
        Authorization.is_authorized? "edit", nil, self, user
      end

      def can_view? user
        Authorization.is_authorized? "view", nil, self, user
      end

      def can_download? user
        Authorization.is_authorized? "download", nil, self, user
      end

      def can_delete? user
        Authorization.is_authorized? "destroy", nil, self, user
      end

      def can_manage? user
        Authorization.is_authorized? "manage", nil, self, user
      end

      #returns a list of the people that can manage this file
      #which will be the contributor, and those that have manage permissions
      def managers
        people=[]
        people << self.contributor.person unless self.contributor.nil?
        self.policy.permissions.each do |perm|
          people << (perm.contributor) if perm.contributor.kind_of?(Person) && perm.access_type==Policy::MANAGING
        end
        people.uniq
      end

      # def asset; return self; end
      # def resource; return self; end

    end
  end
end


ActiveRecord::Base.class_eval do
  include Acts::Authorized
  def contributor_credited?
    false
  end
end

