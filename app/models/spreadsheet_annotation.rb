class SpreadsheetAnnotation < ActiveRecord::Base
  
  belongs_to :data_file
  
  belongs_to :source,
             :polymorphic => true
             
  acts_as_solr(:fields => [ :content ]) if SOLR_ENABLED
             
  validates_presence_of :content
  #validates_presence_of :annotation_type
  validates_presence_of :source
  validates_presence_of :data_file
  validate :valid_cell_range #FIXME: NEED TO MAKE THIS BETTER, TOO MUCH VALIDATION DONE IN CONTROLLER
  validates_numericality_of :sheet, :allow_nil => false, :only_integer => true, :greater_than_or_equal_to => 0
  
  def cell_coverage
    return SpreadsheetAnnotation.to_alpha(start_column)+start_row.to_s + 
      ((end_column == start_column && end_row == start_row) ? "" : ":" + SpreadsheetAnnotation.to_alpha(end_column)+end_row.to_s)    
  end
  
private

  def self.to_alpha(col)
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split(//)    
    result = ""
    col = col-1
    while (col > -1) do
      letter = (col % 26)
      result = alphabet[letter] + result
      col = (col / 26) - 1
    end
    result
  end
  
  def self.from_alpha(col)
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split(//)    
    result = 0
    col = col.split(//)
    (0..col.length-1).reverse_each do |x|
      result += ((alphabet.index(col[x])+1) * (26 ** ((col.length - 1) - x)))
    end
    result
  end
  
  def valid_cell_range
    [self.start_row, self.start_column, self.end_row, self.end_column].each do |attr|
      if !(attr.kind_of?(Fixnum)) || attr < 0 || attr.nil?
        errors.add_to_base("Invalid cell range")
        break
      end
    end     
  end
  
end