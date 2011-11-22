module Subscribable
  def self.included klass
    klass.class_eval do
      has_many :subscriptions, :required_access_to_owner => false, :as => :subscribable, :dependent => :destroy, :autosave => true, :before_add => proc {|item, sub| sub.subscribable = item}
      before_create :set_default_subscriptions
      extend ClassMethods
    end
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
    subscriptions.build :person => person unless subscribed?(person)
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

  def set_default_subscriptions
    Person.all.each do |person|
      if project_subscription = person.project_subscriptions.detect {|s| self.projects.include? s.project}
        subscriptions.build :person => person unless project_subscription.unsubscribed_types.include? self.class.name
      end
    end
  end

  module ClassMethods
    def subscribers_are_notified_of? action
      action != 'show' && action != 'download' && action != 'destroy'
    end
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