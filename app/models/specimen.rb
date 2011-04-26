require 'grouped_pagination'
require 'acts_as_asset'

class Specimen < ActiveRecord::Base


  has_many :samples

  has_many :assets_creators, :dependent => :destroy, :as => :asset, :foreign_key => :asset_id
  has_many :creators, :class_name => "Person", :through => :assets_creators, :order=>'assets_creators.id'
  belongs_to :contributor, :polymorphic => true
  belongs_to :policy

  belongs_to :institution
  belongs_to :organism
  belongs_to :strain
  belongs_to :project

  alias_attribute :description, :comments
  alias_attribute :title, :donor_number



  validates_numericality_of :age, :only_integer => true, :greater_than=> 0, :allow_nil=> true, :message => "is not a positive integer"
  validates_presence_of :donor_number


  grouped_pagination :pages=>("A".."Z").to_a, :default_page => Seek::Config.default_page(self.name.underscore.pluralize)

  #acts_as_asset

  def age_in_weeks
    if !age.nil?
      age.to_s + " (weeks)"
    end

  end

end
