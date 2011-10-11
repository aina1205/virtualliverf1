require 'acts_as_authorized'
class Assay < ActiveRecord::Base
  acts_as_isa

  def projects
    try_block {study.investigation.projects} || []
  end

  def project_ids
    projects.map(&:id)
  end

  alias_attribute :contributor, :owner
  acts_as_authorized

  def default_contributor
    User.current_user.try :person
  end

  acts_as_annotatable :name_field=>:tag
  include Seek::Taggable

  belongs_to :institution
  has_and_belongs_to_many :samples
  belongs_to :assay_type
  belongs_to :technology_type  
  belongs_to :study  
  belongs_to :owner, :class_name=>"Person"
  belongs_to :assay_class
  has_many :assay_organisms, :dependent=>:destroy
  has_many :organisms, :through=>:assay_organisms
  has_many :strains, :through=>:assay_organisms

  has_many :assay_assets, :dependent => :destroy
  
  def self.asset_sql(asset_class)
    asset_class_underscored = asset_class.underscore
    'SELECT '+ asset_class_underscored +'_versions.* FROM ' + asset_class_underscored + '_versions ' +
    'INNER JOIN assay_assets ' + 
    'ON assay_assets.asset_id = ' + asset_class_underscored + '_id ' + 
    'AND assay_assets.asset_type = \'' + asset_class + '\' ' + 
    'WHERE (assay_assets.version = ' + asset_class_underscored + '_versions.version ' +
    'AND assay_assets.assay_id = #{self.id})' 
  end
  
  has_many :data_files, :class_name => "DataFile::Version", :finder_sql => self.asset_sql("DataFile")
  has_many :sops, :class_name => "Sop::Version", :finder_sql => self.asset_sql("Sop")
  has_many :models, :class_name => "Model::Version", :finder_sql => self.asset_sql("Model")
  
  has_many :data_file_masters, :through => :assay_assets, :source => :asset, :source_type => "DataFile"
  has_many :sop_masters, :through => :assay_assets, :source => :asset, :source_type => "Sop"
  has_many :model_masters, :through => :assay_assets, :source => :asset, :source_type => "Model"

  has_one :investigation,:through=>:study    

  has_many :assets,:through=>:assay_assets

  validates_presence_of :assay_type
  validates_presence_of :technology_type, :unless=>:is_modelling?
  validates_presence_of :study, :message=>" must be selected"
  validates_presence_of :owner
  validates_presence_of :assay_class
  validates_presence_of :samples,:if => Proc.new { |assay| assay.is_experimental? && Seek::Config.is_virtualliver}
  has_many :relationships, 
    :class_name => 'Relationship',
    :as => :subject,
    :dependent => :destroy
          
  acts_as_solr(:fields=>[:description,:title,:searchable_tags],:include=>[:assay_type,:technology_type,:organisms,:strains]) if Seek::Config.solr_enabled
  
  def short_description
    type=assay_type.nil? ? "No type" : assay_type.title
   
    "#{title} (#{type})"
  end

  def can_delete? *args
    super && assets.empty? && related_publications.empty?
  end

  #returns true if this is a modelling class of assay
  def is_modelling?
    return !assay_class.nil? && assay_class.key=="MODEL"
  end

  #returns true if this is an experimental class of assay
  def is_experimental?
    return !assay_class.nil? && assay_class.key=="EXP"
  end    
  
  #Create or update relationship of this assay to an asset, with a specific relationship type and version  
  def relate(asset, r_type=nil)
    assay_asset = assay_assets.detect {|aa| aa.asset == asset}

    if assay_asset.nil?
      assay_asset = AssayAsset.new
      assay_asset.assay = self             
    end
    
    assay_asset.asset = asset
    assay_asset.version = asset.version
    assay_asset.relationship_type = r_type unless r_type.nil?
    assay_asset.save if assay_asset.changed?
    
    return assay_asset
  end

  #Associates and organism with the assay
  #organism may be either an ID or Organism instance
  #strain_title should be the String for the strain
  #culture_growth should be the culture growth instance
  def associate_organism(organism,strain_title=nil,culture_growth_type=nil)
    organism = Organism.find(organism) if organism.kind_of?(Numeric) || organism.kind_of?(String)
    assay_organism=AssayOrganism.new
    assay_organism.assay = self
    assay_organism.organism = organism
    strain=nil
    if (strain_title && !strain_title.empty?)
      strain=organism.strains.find_by_title(strain_title)
      if strain.nil?
        strain=Strain.new(:title=>strain_title,:organism_id=>organism.id)
        strain.save!
      end
    end
    assay_organism.culture_growth_type = culture_growth_type unless culture_growth_type.nil?
    assay_organism.strain=strain

   

    existing = AssayOrganism.all.select{|ao|ao.organism==organism and ao.assay == self and ao.strain==strain and ao.culture_growth_type==culture_growth_type}
    if existing.blank?
    self.assay_organisms << assay_organism
    end

  end
  
  def assets
    asset_masters.collect {|a| a.latest_version} |  (data_files + models + sops)
  end

  def asset_masters
    data_file_masters + model_masters + sop_masters
  end
  
  def related_publications
    self.relationships.select {|a| a.object_type == "Publication"}.collect { |a| a.object }
  end

  def related_asset_ids asset_type
    self.assay_assets.select {|a| a.asset_type == asset_type}.collect { |a| a.asset_id }
  end

  def avatar_key
    type = is_modelling? ? "modelling" : "experimental"
    "assay_#{type}_avatar"
  end

  def clone_with_associations
    new_object= self.clone
    new_object.policy = self.policy.deep_copy
    new_object.sop_masters = self.try(:sop_masters)

    new_object.model_masters = self.try(:model_masters)
    new_object.sample_ids = self.try(:sample_ids)
    new_object.assay_organisms = self.try(:assay_organisms)

    return new_object
  end

  def validate
    #FIXME: allows at the moment until fixtures and factories are updated: JIRA: SYSMO-734
    errors.add_to_base "You cannot associate a modelling analysis with a sample" if is_modelling? && !samples.empty?
  end
end
