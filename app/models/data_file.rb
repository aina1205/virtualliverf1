require 'acts_as_resource'

class DataFile < ActiveRecord::Base

  acts_as_resource

  has_many :created_datas

  has_many :assays,:through=>:created_datas

  validates_presence_of :title

  has_many :studied_factors

  # allow same titles, but only if these belong to different users
  validates_uniqueness_of :title, :scope => [ :contributor_id, :contributor_type ], :message => "error - you already have a SOP with such title."

  belongs_to :content_blob,
             :dependent => :destroy

  acts_as_solr(:fields=>[:description,:title,:original_filename]) if SOLR_ENABLED  

  # get a list of DataFiles with their original uploaders - for autocomplete fields
  # (authorization is done immediately to save from iterating through the collection again afterwards)
  #
  # Parameters:
  # - user - user that performs the action; this is required for authorization
  def self.get_all_as_json(user)
    all_datafiles = DataFile.find(:all, :order => "ID asc")
    datafiles_with_contributors = all_datafiles.collect{ |d|
        Authorization.is_authorized?("show", nil, d, user) ?
        (p = d.asset.contributor.person;
        { "id" => d.id,
          "title" => d.title,
          "contributor" => "by " +
                           (p.first_name.blank? ? (logger.error("\n----\nUNEXPECTED DATA: person id = #{p.id} doesn't have a first name\n----\n"); "(NO FIRST NAME)") : p.first_name) + " " +
                           (p.last_name.blank? ? (logger.error("\n----\nUNEXPECTED DATA: person id = #{p.id} doesn't have a last name\n----\n"); "(NO LAST NAME)") : p.last_name),
          "type" => self.name } ) :
        nil }

    datafiles_with_contributors.delete(nil)

    return datafiles_with_contributors.to_json
  end

end
