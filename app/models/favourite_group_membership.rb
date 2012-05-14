class FavouriteGroupMembership < ActiveRecord::Base
  belongs_to :favourite_group
  belongs_to :person, :touch => true
  
  validates_presence_of :favourite_group_id, :person_id, :access_type
end
