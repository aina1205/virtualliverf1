class Experiment < ActiveRecord::Base


  has_one :project, :through=>:topic

  has_and_belongs_to_many :assays
  belongs_to :experiment_type
  belongs_to :topic
  
  belongs_to :person_responible, :class_name => "Person"

  has_and_belongs_to_many :sops  
  
  validates_presence_of :title
  validates_presence_of :topic

  acts_as_solr(:fields=>[:description,:title]) if SOLR_ENABLED
  
end
