module Seek

  #FIXME: needs consolidating with SpreadsheetUtil
  class SpreadsheetHandler
    include SpreadsheetUtil
    include Seek::MimeTypes
    include SysMODB::SpreadsheetExtractor
    
    def contents_for_search obj=self
      content = Rails.cache.fetch("#{obj.content_blob.cache_key}-ss-content-for-search") do
        begin
          xml=obj.spreadsheet_xml
          unless xml.nil?
            content = extract_content(xml)
            content = humanize_content(content)
            content = filter_content(content)
            content
          else
            []
          end
        rescue Exception=>e
          Rails.logger.error("Error processing spreadsheet for content_blob #{obj.content_blob_id} #{e}")
          raise e unless Rails.env=="Production"
          nil
        end
      end

      content || []
    end

    #pulls out all the content from cells into an array
    def extract_content xml
      doc = LibXML::XML::Parser.string(xml).parse
      doc.root.namespaces.default_prefix="ss"

      content = doc.find("//ss:sheet[@hidden='false' and @very_hidden='false']/ss:rows/ss:row/ss:cell").collect do |cell|
        cell.content
      end
      content
    end

    #does some manipulation of the content, e.g. converting camelcase and converting underscores, whilst preserving the original
    #form
    def humanize_content content
      content.collect do |val|
        [content,val.underscore.humanize.downcase]
      end.flatten.uniq
    end

    #filters out numbers and text declared in a black list
    def filter_content content
      blacklist = ["seek id"] #not yet defined, and should probably be regular expressions
      content = content - blacklist

      #filter out numbers
      content.reject do |val|
        val.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) != nil
      end
    end

  end


end
