require 'acts_as_authorized'
class Subscription < ActiveRecord::Base
  belongs_to :person, :required_access => false
  belongs_to :subscribable, :required_access => false, :polymorphic => true
  belongs_to :project_subscription

  validates_presence_of :person
  validates_presence_of :subscribable

  named_scope :for_subscribable, lambda {|item|
    {
        :conditions=>["subscribable_id=? and subscribable_type=?",item.id,item.class.name]
    }
  }

  #these should be ordered fastest to slowest
  FREQUENCIES = ['immediately', 'daily', 'weekly', 'monthly']

  FREQUENCIES.each do |s_type|
    define_method "#{s_type}?" do
      frequency == s_type
    end
  end

  #TODO: add a way for the user to set a frequency for projects they don't subscribe to.
  def generic_frequency
    ProjectSubscription.find_all_by_person_id(person_id).map(&:frequency).inject('weekly') {|slowest, current|  FREQUENCIES.index(current) > FREQUENCIES.index(slowest) ? current : slowest}
  end

  def frequency
    project_subscription.try(:frequency) || generic_frequency
  end
end