module Subscribable
  def self.included klass
    klass.class_eval do
      has_many :subscriptions, :required_access_to_owner => false, :as => :subscribable, :dependent => :destroy, :autosave => true, :before_add => proc {|item, sub| sub.subscribable = item}
      after_create :set_subscription_job if self.subscribable?
      after_update :update_subscription_job if self.subscribable?
      attr_accessor :current_project_ids
      after_save :assign_current_project_ids
      extend ClassMethods
    end
  end

  def assign_current_project_ids
    self.current_project_ids = self.project_ids
  end

  def current_users_subscription
    subscriptions.detect { |ss| ss.person == User.current_user.person }
  end

  def subscribed? person=User.current_user.person
    !subscriptions.detect{|sub| sub.person == person}.nil?
  end

  def subscribed= subscribed
    if subscribed
      subscribe
    else
      unsubscribe
    end
  end

  def subscribe person=User.current_user.person
    subscriptions << Subscription.new(:person => person) unless subscribed?(person)
  end

  def unsubscribe person=User.current_user.person
    subscriptions.detect{|sub| sub.person == person}.try(:destroy)
  end

  def send_immediate_subscriptions activity_log

    if Seek::Config.email_enabled && subscribers_are_notified_of?(activity_log.action)
      subscriptions.each do |subscription|
        if !subscription.person.user.nil? && subscription.person.receive_notifications? && subscription.immediately? && can_view?(subscription.person.user)
          SubMailer.deliver_send_immediate_subscription subscription.person, activity_log
        end
      end
    end
    
  end

  def subscribers_are_notified_of? action
    self.class.subscribers_are_notified_of? action
  end

  def set_default_subscriptions projects
    unless projects.empty?
      Person.scoped(:include => :project_subscriptions).each do |person|
        project_subscriptions = person.project_subscriptions
        project_subscriptions.each do |ps|
          if projects.include? ps.project
            subscriptions.create(:person => person, :project_subscription_id => ps.id) if !ps.unsubscribed_types.include?(self.class.name) && !self.subscribed?(person)
          end
        end
      end
    end
  end

  def remove_subscriptions projects
    unless projects.empty?
      project_subscription_ids = projects.collect{|project| project.project_subscriptions}.flatten.collect(&:id)
      subscriptions = Subscription.find(:all, :conditions => ['subscribable_type=? AND subscribable_id=? AND project_subscription_id IN (?)', self.class.name, self.id, project_subscription_ids])
      subscriptions.each{|s| s.destroy}
    end
  end

  def set_subscription_job
      SetSubscriptionsForItemJob.create_job(self.class.name, self.id, self.projects.collect(&:id))
  end

  def update_subscription_job
    current_project_ids = self.current_project_ids.to_a
    if self.kind_of?(Study) && self.investigation_id_changed?
      #update subscriptions for study
      old_investigation_id = self.investigation_id_was
      old_investigation = Investigation.find_by_id old_investigation_id
      project_ids_to_remove = old_investigation.nil? ? [] : old_investigation.projects.collect(&:id)
      project_ids_to_add = self.investigation.projects.collect(&:id)
      update_subscriptions_for self, project_ids_to_add, project_ids_to_remove
      #update subscriptions for assays associated with this study
      self.assays.each do |assay|
        update_subscriptions_for assay, project_ids_to_add, project_ids_to_remove
      end
    elsif self.kind_of?(Assay) && self.study_id_changed?
      old_study_id = self.study_id_was
      old_study = Study.find_by_id old_study_id
      project_ids_to_remove = old_study.nil? ? [] : old_study.projects.collect(&:id)
      project_ids_to_add = self.study.projects.collect(&:id)
      update_subscriptions_for self, project_ids_to_add, project_ids_to_remove
    elsif (!self.kind_of?(Study) && !self.kind_of?(Assay) && !(self.projects.collect(&:id) - current_project_ids).empty?)
      project_ids_to_add = self.projects.collect(&:id) - current_project_ids
      project_ids_to_remove = current_project_ids - self.projects.collect(&:id)
      update_subscriptions_for self, project_ids_to_add, project_ids_to_remove
      #update for associated studies and assays
      if self.kind_of?(Investigation)
        self.studies.each do |study|
          update_subscriptions_for study, project_ids_to_add, project_ids_to_remove
          study.assays.each do |assay|
            update_subscriptions_for assay, project_ids_to_add, project_ids_to_remove
          end
        end
      end
    end
  end

  module ClassMethods
    def subscribers_are_notified_of? action
      action!="show" && action!="download" && action!="destroy"
    end
  end

  private

  def update_subscriptions_for item, project_ids_to_add, project_ids_to_remove
    SetSubscriptionsForItemJob.create_job(item.class.name, item.id, project_ids_to_add)
    RemoveSubscriptionsForItemJob.create_job(item.class.name, item.id, project_ids_to_remove)
  end
end

ActiveRecord::Base.class_eval do
  def self.subscribable?
    include? Subscribable
  end

  def subscribable?
    self.class.subscribable?
  end
end
