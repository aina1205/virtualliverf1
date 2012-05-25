require 'grouped_pagination'
require 'acts_as_authorized'
require "acts_as_scalable"
class Sample < ActiveRecord::Base
 include Subscribable

  acts_as_scalable
  acts_as_authorized
  acts_as_favouritable

  attr_accessor :from_new_link
  attr_accessor :from_biosamples

  belongs_to :specimen

  accepts_nested_attributes_for :specimen

 has_and_belongs_to_many :tissue_and_cell_types

  belongs_to :institution
  has_and_belongs_to_many :assays

  has_many :assets_creators, :dependent => :destroy, :as => :asset, :foreign_key => :asset_id
  has_many :creators, :class_name => "Person", :through => :assets_creators, :order=>'assets_creators.id', :after_add => :update_timestamp, :after_remove => :update_timestamp
  has_many :assets,:through => :sample_assets
  has_many :sample_assets,:dependent => :destroy
  validates_numericality_of :age_at_sampling, :only_integer => true, :greater_than=> 0, :allow_nil=> true, :message => "is not a positive integer" if !Seek::Config.is_virtualliver
  validates_presence_of :projects unless Seek::Config.is_virtualliver


  has_and_belongs_to_many :tissue_and_cell_types

  def self.sop_sql()
  'SELECT sop_versions.* FROM sop_versions ' +
  'INNER JOIN sample_sops ' +
  'ON sample_sops.sop_id = sop_versions.sop_id ' +
  'WHERE (sample_sops.sop_version = sop_versions.version ' +
  'AND sample_sops.sample_id = #{self.id})'
  end

  def self.asset_sql(asset_class)
    asset_class_underscored = asset_class.underscore
    'SELECT ' + asset_class_underscored + '_versions.* FROM ' + asset_class_underscored + '_versions ' +
    'INNER JOIN sample_assets ' +
    'ON sample_assets.asset_id= '+ asset_class_underscored + '_id ' +
    'AND sample_assets.asset_type=\'' + asset_class + '\' ' +
    'WHERE (sample_assets.version= ' + asset_class_underscored + '_versions.version ' +
    'AND sample_assets.sample_id= #{self.id})'
  end

  has_many :data_files, :class_name => "DataFile::Version", :finder_sql => self.asset_sql("DataFile")
  has_many :models, :class_name => "Model::Version", :finder_sql => self.asset_sql("Model")
  has_many :sops, :class_name => "Sop::Version", :finder_sql => self.asset_sql("Sop")

  has_many :data_file_masters, :through => :sample_assets, :source => :asset, :source_type => 'DataFile'
  has_many :model_masters, :through => :sample_assets, :source => :asset, :source_type => 'Model'
  has_many :sop_masters, :through => :sample_assets, :source => :asset, :source_type => 'Sop'
  #has_many :sop_masters,:class_name => "SampleSop"


  alias_attribute :description, :comments
  validates_presence_of :title
  validates_uniqueness_of :title
  validates_presence_of :specimen,:lab_internal_number
  validates_presence_of :donation_date if Seek::Config.is_virtualliver

  grouped_pagination :pages=>("A".."Z").to_a, :default_page => Seek::Config.default_page(self.name.underscore.pluralize)

  HUMANIZED_COLUMNS = {:title => "Sample name", :lab_internal_number=> "Sample lab internal identifier", :provider_id => "Provider's sample identifier"}

  searchable do
    text :searchable_terms
  end if Seek::Config.solr_enabled


  def searchable_terms
    text=[]
    text << title
    text << description
    text << lab_internal_number
    text << provider_name
    text << provider_id
    if (specimen)
      text << specimen.lab_internal_number
      text << specimen.provider_id
      text << specimen.title
      text << specimen.provider_id
      if (specimen.strain)
        text << specimen.try(:strain).try(:info).to_s
        text << specimen.try(:strain).try(:organism).try(:title).to_s
      end
    end
    text
  end

 def can_delete? *args
   assays.empty? && super
 end

 def self.user_creatable?
   true
 end

  def associate_tissue_and_cell_type tissue_and_cell_type_id,tissue_and_cell_type_title
       tissue_and_cell_type=nil
    if !tissue_and_cell_type_title.blank?
      if ( tissue_and_cell_type_id =="0" )
          found = TissueAndCellType.find(:first,:conditions => {:title => tissue_and_cell_type_title})
          unless found
          tissue_and_cell_type = TissueAndCellType.create!(:title=> tissue_and_cell_type_title)
          end
      else
          tissue_and_cell_type = TissueAndCellType.find_by_id(tissue_and_cell_type_id)
      end

      if tissue_and_cell_type
       existing = false
       self.tissue_and_cell_types.each do |t|
         if t == tissue_and_cell_type
           existing = true
           break
         end
       end
       unless existing
         self.tissue_and_cell_types << tissue_and_cell_type
       end
      end
    end
  end

 def associate_asset asset
   sample_asset = sample_assets.detect { |sa| sa.asset == asset }

   unless sample_asset
     sample_asset = SampleAsset.new
     sample_asset.sample = self
     sample_asset.asset = asset
   end

   sample_asset.version = asset.version
   sample_asset.save if sample_asset.changed?

   return sample_asset
 end

 def create_or_update_assets asset_ids, asset_class_name
   asset_class = eval asset_class_name
   existing_sample_assets = sample_assets.select {|sa| sa.asset_type == asset_class_name}
   asset_ids_to_destroy = existing_sample_assets.map(&:asset_id) - asset_ids.map(&:to_i)

   #destroy old,redundant sample_assets
   existing_sample_assets.select{|sa| asset_ids_to_destroy.include? sa.asset_id}.each &:destroy

   #update/create new sample assets
   asset_ids.each do |id|
     asset = asset_class.find id
     associate_asset asset if asset.can_view?
   end

 end

 def clone_with_associations
   new_object= self.clone
   new_object.policy = self.policy.deep_copy
   new_object.data_file_masters = self.data_file_masters.select(&:can_view?)
   new_object.model_masters = self.model_masters.select(&:can_view?)  
   new_object.sop_masters = self.sop_masters.select(&:can_view?)
   new_object.tissue_and_cell_types = self.try(:tissue_and_cell_types)
   new_object.project_ids = self.project_ids
    new_object.scale_ids = self.scale_ids
   return new_object
  end

  def self.human_attribute_name(attribute)
    HUMANIZED_COLUMNS[attribute.to_sym] || super
  end

  def sampling_date_info
    if sampling_date.nil?
      ''
    else
      if try(:sampling_date).hour == 0 and try(:sampling_date).min == 0 and try(:sampling_date).sec == 0 then
        try(:sampling_date).strftime('%d/%m/%Y')
      else
        try(:sampling_date).strftime('%d/%m/%Y @ %H:%M:%S')
      end

    end
  end

  def provider_name_info
    provider_name.blank? ? contributor.try(:person).try(:name) : provider_name
  end

  def specimen_info
    specimen.nil? ? '' : CELL_CULTURE_OR_SPECIMEN.capitalize + ' ' + specimen.title
 end
end
