class AssayOrganism < ActiveRecord::Base
  belongs_to :assay
  belongs_to :organism
  belongs_to :culture_growth_type
  belongs_to :strain

  validates_presence_of :assay
  validates_presence_of :organism
end
