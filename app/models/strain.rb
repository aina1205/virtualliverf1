class Strain < ActiveRecord::Base
  belongs_to :organism

  named_scope :by_title
end
