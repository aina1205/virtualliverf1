module Seek
  module ModelTypeDetection
    
    def is_dat? model
      model.content_blobs.detect{|content_blob| check_content content_blob.filepath,"begin name",25000}
    end                      
    
    def is_sbml? model                        
       model.content_blobs.detect{|content_blob| check_content content_blob.filepath,"<sbml" }
    end

    def is_jws_supported? model
      is_dat?(model) || is_sbml?(model)
    end
    
    def check_content filepath, str, max_length=1500      
      char_count=0      
      begin
        f = File.open(filepath, "r") 
        f.each_line do |line|
          char_count += line.length
          return true  if line.downcase.include?(str)
          break if char_count>=max_length        
        end 
      rescue
    end
    
      false
    end
    
  end
end