require 'acts_as_asset'
require 'acts_as_versioned_resource'
require 'explicit_versioning'
require 'grouped_pagination'
require 'title_trimmer'

class Model < ActiveRecord::Base

  title_trimmer

  #searchable must come before acts_as_asset call
  searchable(:auto_index=>false) do
    text :description,:title,:organism_terms,:searchable_tags, :model_contents,:assay_type_titles,:technology_type_titles
    text :content_blobs do
       content_blobs.compact.map(&:original_filename).compact
    end
  end if Seek::Config.solr_enabled

  acts_as_asset
  acts_as_trashable

  include Seek::ModelProcessing

  validates_presence_of :title

  after_save :queue_background_reindexing if Seek::Config.solr_enabled
  
  # allow same titles, but only if these belong to different users
  # validates_uniqueness_of :title, :scope => [ :contributor_id, :contributor_type ], :message => "error - you already have a Model with such title."
  has_many :sample_assets,:dependent=>:destroy,:as => :asset
  has_many :samples, :through => :sample_assets

  has_many :model_images
  belongs_to :model_image

  has_many :content_blobs, :as => :asset, :foreign_key => :asset_id,:conditions => 'asset_version= #{self.version}'

  belongs_to :organism
  belongs_to :recommended_environment,:class_name=>"RecommendedModelEnvironment"
  belongs_to :model_type
  belongs_to :model_format


  explicit_versioning(:version_column => "version") do
    include Seek::ModelProcessing
    acts_as_versioned_resource

    belongs_to :model_image
    belongs_to :organism
    belongs_to :recommended_environment,:class_name=>"RecommendedModelEnvironment"
    belongs_to :model_type
    belongs_to :model_format

    def content_blobs
      ContentBlob.find(:all, :conditions => ["asset_id =? and asset_type =? and asset_version =?", self.parent.id, self.parent.class.name, self.version])
    end

    def content_blob
      result = Class.new.extend(Seek::ModelTypeDetection).is_jws_supported? self
      result.nil?? content_blobs.first : result
    end
  end

  def content_blob
    # return the first content blob which is jws supported (is_dat? or is_sbml?)
      result = Class.new.extend(Seek::ModelTypeDetection).is_jws_supported? self
      result.nil?? content_blobs.first : result
  end

  # get a list of Models with their original uploaders - for autocomplete fields
  # (authorization is done immediately to save from iterating through the collection again afterwards)
  #
  # Parameters:
  # - user - user that performs the action; this is required for authorization
  def self.get_all_as_json(user)
    all = Model.all_authorized_for "view",user
    with_contributors = all.collect{ |d|
        contributor = d.contributor;
        { "id" => d.id,
          "title" => d.title,
          "contributor" => contributor.nil? ? "" : "by " + contributor.person.name,
          "type" => self.name
        }
    }
    return with_contributors.to_json
  end

  def organism_terms
    if organism
      organism.searchable_terms
    else
      []
    end
  end

  #defines that this is a user_creatable object, and appears in the "New Object" gadget
  def self.user_creatable?
    true
  end

  def model_contents
    if content_blob.try(:file_exists?)
      species | parameters_and_values.keys
    else
      Rails.logger.error("Unable to find data contents for Model #{self.id}")
      []
    end
  end

  #a simple container for handling the matching results returned from #matching_data_files
  class DataFileMatchResult < Struct.new(:search_terms,:score,:primary_key);end

  #return a an array of DataFileMatchResult where the data file id is the key, and the matching terms/values are the values
  def matching_data_files params_only=false
    
    results = {}

    if Seek::Config.solr_enabled && is_jws_supported?
      search_terms = parameters_and_values.keys
      unless params_only
        search_terms = search_terms | species | searchable_tags | organism_terms
      end
      #make the array uniq! case-insensistive whilst mainting the original case
      dc = []
      search_terms = search_terms.inject([]) do |r,v|
        unless dc.include?(v.downcase)
          r << v
          dc << v.downcase
        end
        r
      end

      fields = [:fs_search_fields, :spreadsheet_contents_for_search,:spreadsheet_annotation_search_fields, :searchable_tags]

      search_terms.each do |key|
        DataFile.search do |query|
          query.keywords key, :fields=>fields
        end.hits.each do |hit|
          unless hit.score.nil?
            results[hit.primary_key]||=DataFileMatchResult.new([],0,hit.primary_key)
            results[hit.primary_key].search_terms << key
            results[hit.primary_key].score += (0.75 + hit.score)
          end
        end
      end
    end

    results.values.sort_by{|a| -a.score}
  end
  
end
