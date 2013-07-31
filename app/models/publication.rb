require 'acts_as_asset'
require 'grouped_pagination'
require 'title_trimmer'
require 'libxml'

class Publication < ActiveRecord::Base
  
  title_trimmer

  #searchable must come before acts_as_asset is called
  searchable(:ignore_attribute_changes_of=>[:updated_at,:last_used_at]) do
    text :title,:abstract,:journal,:searchable_tags, :pubmed_id, :doi
    text :publication_authors do
      publication_authors.compact.map(&:first_name) + publication_authors.compact.map(&:last_name)
    end
  end if Seek::Config.solr_enabled

  acts_as_asset

  def default_policy
    policy = Policy.new(:name => "publication_policy", :sharing_scope => Policy::EVERYONE, :access_type => Policy::VISIBLE)
    #add managers (authors + contributor)
    creators.each do |author|
      policy.permissions << Permissions.create(:contributor => author, :policy => policy, :access_type => Policy::MANAGING)
    end
    #Add contributor
    c = contributor || default_contributor
    policy.permissions << Permission.create(:contributor => c.person, :policy => policy, :access_type => Policy::MANAGING) if c
    policy
  end

  validate :check_identifier_present
  validate :check_uniqueness_of_identifier_within_project
  validate :check_uniqueness_of_title_within_project
  
  has_many :publication_authors, :dependent => :destroy, :autosave => true

  after_update :update_creators_from_publication_authors
  after_update :update_policy_from_publication_authors

  def update_creators_from_publication_authors
    self.creators = publication_authors.map(&:person).compact
  end

  def update_policy_from_publication_authors
    #Update policy so current authors have manage permissions
    policy.permissions.clear
    creators.each do |author|
      policy.permissions << Permission.create(:contributor => author, :policy => policy, :access_type => Policy::MANAGING)
    end
    #Add contributor
   policy.permissions << Permission.create(:contributor => contributor.person, :policy => policy, :access_type => Policy::MANAGING)
  end
  
  has_many :backwards_relationships, 
    :class_name => 'Relationship',
    :as => :object,
    :dependent => :destroy

  
  if Seek::Config.events_enabled
    has_and_belongs_to_many :events
  else
    def events
      []
    end

    def event_ids
      []
    end

    def event_ids= events_ids

    end
    
  end

  alias :seek_authors :creators

  def non_seek_authors
    publication_authors.find_all_by_person_id nil
  end


  #TODO: refactor to something like 'sorted_by :start_date', which should create the default scope and the sort method. Maybe rename the sort method.
  default_scope :order => "#{self.table_name}.published_date DESC"
  def self.sort publications
    publications.sort_by &:published_date
  end

  def contributor_credited?
    false
  end

  def extract_pubmed_metadata(pubmed_record)
    self.title = pubmed_record.title.chop #remove full stop
    self.abstract = pubmed_record.abstract
    self.published_date = pubmed_record.date_published
    self.journal = pubmed_record.journal
    self.pubmed_id = pubmed_record.pmid
  end
  
  def extract_doi_metadata(doi_record)
    self.title = doi_record.title
    self.published_date = doi_record.date_published
    self.journal = doi_record.journal
    self.doi = doi_record.doi
    self.publication_type = doi_record.publication_type
  end
  
  def related_data_files
    self.backwards_relationships.select {|a| a.subject_type == "DataFile"}.collect { |a| a.subject }
  end
  
  def related_models
    self.backwards_relationships.select {|a| a.subject_type == "Model"}.collect { |a| a.subject }
  end
  
  def related_assays
    self.backwards_relationships.select {|a| a.subject_type == "Assay"}.collect { |a| a.subject }
  end

  #includes those related directly, or through an assay
  def all_related_data_files
    via_assay = related_assays.collect do |assay|
      assay.data_file_masters
    end.flatten.uniq.compact
    via_assay | related_data_files
  end

  #includes those related directly, or through an assay
  def all_related_models
    via_assay = related_assays.collect do |assay|
      assay.model_masters
    end.flatten.uniq.compact
    via_assay | related_models
  end

  #indicates whether the publication has data files or models linked to it (either directly or via an assay)
  def has_assets?
    #FIXME: requires a unit test
    !all_related_data_files.empty? || !all_related_models.empty?
  end

  #returns a list of related organisms, related through either the assay or the model
  def related_organisms
    organisms = related_assays.collect{|a| a.organisms}.flatten.uniq.compact
    organisms = organisms | related_models.collect{|m| m.organism}.uniq.compact
    organisms
  end
  
  def self.subscribers_are_notified_of? action
    action == 'create'
  end

  def endnote
   bio_reference.endnote
  end
  
  private

  def bio_reference
    if pubmed_id
      Bio::MEDLINE.new(Bio::PubMed.efetch(pubmed_id).first).reference
    else
      #TODO: Bio::Reference supports a 'url' option. Should this be the URL on seek, or the URL of the 'View Publication' button, or neither?
      Bio::Reference.new({:title => title, :journal => journal, :abstract => abstract,
                          :authors => publication_authors.map {|e| e.person ? [e.person.last_name, e.person.first_name].join(', ') : [e.last_name, e.first_name].join(', ')},
                          :year => published_date.year}.with_indifferent_access)
    end
  end
  
  def check_identifier_present
    if doi.blank? && pubmed_id.blank?
      self.errors.add_to_base("Please specify either a PubMed ID or DOI")
      return false
    end

    if !doi.blank? && !pubmed_id.blank?
      self.errors.add_to_base("Can't have both a PubMed ID and a DOI")
      return false
    end

    true

  end

  def check_uniqueness_of_identifier_within_project
    if !doi.blank?
      existing = Publication.find_all_by_doi(doi) - [self]
      if !existing.empty?
        matching_projects = existing.collect(&:projects).flatten.uniq & projects
        if !matching_projects.empty?
          self.errors.add_to_base("You cannot register the same DOI within the same project")
          return false
        end
      end
    end
    if !pubmed_id.blank?
      existing = Publication.find_all_by_pubmed_id(pubmed_id) - [self]
      if !existing.empty?
        matching_projects = existing.collect(&:projects).flatten.uniq & projects
        if !matching_projects.empty?
          self.errors.add_to_base("You cannot register the same PubMed ID within the same project")
          return false
        end
      end
    end
    true
  end

  def check_uniqueness_of_title_within_project
    existing = Publication.find_all_by_title(title) - [self]
    if !existing.empty?
      matching_projects = existing.collect(&:projects).flatten.uniq & projects
      if !matching_projects.empty?
        self.errors.add_to_base("You cannot register the same Title within the same project")
        return false
      end
    end
  end

  #defines that this is a user_creatable object type, and appears in the "New Object" gadget
  def self.user_creatable?
    true
  end
end

