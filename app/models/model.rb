require 'acts_as_asset'
require 'acts_as_versioned_resource'
require 'explicit_versioning'
require 'grouped_pagination'
require 'title_trimmer'

class Model < ActiveRecord::Base

  title_trimmer
  acts_as_asset
  acts_as_trashable

  include Seek::ModelProcessing
  
  validates_presence_of :title
  
  # allow same titles, but only if these belong to different users
  # validates_uniqueness_of :title, :scope => [ :contributor_id, :contributor_type ], :message => "error - you already have a Model with such title."

  belongs_to :content_blob #don't add a dependent=>:destroy, as the content_blob needs to remain to detect future duplicates    

  belongs_to :organism
  belongs_to :recommended_environment,:class_name=>"RecommendedModelEnvironment"
  belongs_to :model_type
  belongs_to :model_format
  
  searchable do
    text :description,:title,:original_filename,:organism_name,:searchable_tags
  end if Seek::Config.solr_enabled

  explicit_versioning(:version_column => "version") do
    include Seek::ModelProcessing
    acts_as_versioned_resource
    
    belongs_to :content_blob             
    belongs_to :organism
    belongs_to :recommended_environment,:class_name=>"RecommendedModelEnvironment"
    belongs_to :model_type
    belongs_to :model_format
  end

  def studies
    assays.collect{|a| a.study}.uniq
  end  

  # get a list of Models with their original uploaders - for autocomplete fields
  # (authorization is done immediately to save from iterating through the collection again afterwards)
  #
  # Parameters:
  # - user - user that performs the action; this is required for authorization
  def self.get_all_as_json(user)
    all_models = Model.find(:all, :order => "ID asc",:include=>[:policy,{:policy=>:permissions}])

    models_with_contributors = all_models.collect{ |m|
      m.can_view?(user) ?
        (contributor = m.contributor;
        { "id" => m.id,
          "title" => m.title,
          "contributor" => contributor.nil? ? "" : "by " + contributor.person.name,
          "type" => self.name } ) :
        nil }

    models_with_contributors.delete(nil)

    return models_with_contributors.to_json
  end

  def organism_name
    organism.title unless organism.nil?
  end

  #defines that this is a user_creatable object, and appears in the "New Object" gadget
  def self.user_creatable?
    true
  end

  #return a hash where the data file id is the key, and the matching terms/values are the values
  def matching_data_files
    files = {}

    if Seek::Config.solr_enabled && is_sbml?
      params_and_values = extract_model_parameters_and_values self
      params_and_values.keys.each do |key|
        DataFile.search do |query|
          query.keywords key, :fields=>[:fs_search_fields, :spreadsheet_contents_for_search,:title,:description]
        end.hits.each do |result|
          files[result.primary_key]||=[]
          files[result.primary_key] << key
        end
      end
    end

    files
  end
  
end
