class ProjectSubscription < ActiveRecord::Base
  belongs_to :person
  belongs_to :project

  validates_presence_of :person
  validates_presence_of :project

  validates_inclusion_of :frequency, :in => Subscription::FREQUENCIES, :message => "must be one of: #{Subscription::FREQUENCIES.join(', ')}"

  after_initialize :default_frequency
  def default_frequency
    self.frequency = 'weekly' if self.frequency.blank?
    self.unsubscribed_types = [] if self.unsubscribed_types.nil?
  end

  #store the 'unsubscribed types' instead of the subscribed ones,
  #so that if a new subscribable type is added, people are subscribed to it by default
  serialize :unsubscribed_types

  #accessors for 'subscribed types' which is just the inverse of unsubscribed_types
  def subscribed_types
    subscribable_types - unsubscribed_types
  end

  def subscribed_types= types
    self.unsubscribed_types = (subscribable_types - types)
  end

  def project_name
    project ? project.name : nil
  end

  def self.subscribable_types
    Seek::Util.persistent_classes.select(&:subscribable?).collect &:name
  end

  def subscribable_types
    self.class.subscribable_types
  end

  Subscription::FREQUENCIES.each do |s_type|
    define_method "#{s_type}?" do
      frequency == s_type
    end
  end

  after_create :subscribe_to_all_in_project

  def subscribe_to_all_in_project
    all_in_project.each(&:subscribe).each {|i| i.save if i.changed?}
  end

  def unsubscribe_to_all_in_project
    all_in_project.each(&:unsubscribe).each {|i| i.save if i.changed?}
  end

  private
  def all_in_project
    subscribable_types.map(&:constantize).collect {|klass| if klass.reflect_on_association(:project) then klass.scoped(:include => :project) else klass.find.all end}.flatten.select {|item| item.project == project}
  end
end