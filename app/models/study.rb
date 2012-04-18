require 'acts_as_authorized'
class Study < ActiveRecord::Base  
  acts_as_isa

  attr_accessor :new_link_from_assay

  belongs_to :investigation

  def projects
    investigation.try(:projects) || []
  end

  def project_ids
    projects.map(&:id)
  end

  acts_as_authorized

  has_many :assays

  belongs_to :person_responsible, :class_name => "Person"


  validates_presence_of :investigation

  searchable do
    text :description,:title
  end if Seek::Config.solr_enabled

  def data_files
    assays.collect{|a| a.data_files}.flatten.uniq
  end
  
  def sops
    assays.collect{|a| a.sops}.flatten.uniq
  end

  def models
    assays.collect{|a| a.models}.flatten.uniq
  end

  def can_delete? *args
    assays.empty? && super
  end

  def clone_with_associations
    new_object= self.clone
    new_object.policy = self.policy.deep_copy

    return new_object
  end

end
