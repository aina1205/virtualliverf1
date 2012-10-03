require 'libxml'

module Seek
  module Models
    module ModelExtraction
      include Seek::Models::ModelTypeHandling


      #return a hash of parameters names as a key, along with their values, extracted from SBML
      def parameters_and_values model=self
        result = {}
        #FIXME: keys/value pairs would be overridden in the case the a model contains multiple overlapping model files
        model.sbml_content_blobs.each do |cb|
          result.merge! parameters_and_values_from_sbml(cb)
        end
        model.jws_dat_content_blobs.each do |cb|
          result.merge! parameters_and_values_from_jws_dat(cb)
        end
        result
      end

      #returns an array of species ID and NAME extracted from SBML or JWS DAT
      def species model=self
        (model.sbml_content_blobs | model.jws_dat_content_blobs).collect do |cb|
          if cb.is_sbml?
            species_from_sbml cb
          elsif cb.is_jws_dat?
            species_from_jws_dat cb
          end
        end.flatten
      end

      private

      def species_from_sbml content_blob
        begin
          parser = LibXML::XML::Parser.file(content_blob.filepath)
          doc = parser.parse
          doc.root.namespaces.default_prefix="sbml"
          species=[]
          doc.find("//sbml:listOfSpecies/sbml:species").each do |node|
            species << node.attributes["name"]
            species << node.attributes["id"]
          end
          species.select { |s| !s.blank? }.uniq
        rescue Exception => e
          Rails.logger.error("Error processing sbml model content for content_blob #{content_blob.id} #{e}")
          []
        end
      end

      def species_from_jws_dat content_blob
        begin
          species = []
          contents = open(content_blob.filepath).read
          start_tag = "begin initial conditions"
          start=contents.index(start_tag)
          unless start.nil?
            last = contents.index("end initial conditions")
            unless last.nil?
              interesting_bit = (contents[start+start_tag.length..last-1]).strip
              unless interesting_bit.blank?
                interesting_bit.each_line do |line|
                  unless line.index("[").nil?
                    species << line.gsub(/\[.*/, "").strip
                  end
                end
              end
            end
          end
          species
        rescue Exception => e
          Rails.logger.error("Error processing dat model content for content_blob #{content_blob.id} #{e}")
          []
        end
      end

      def parameters_and_values_from_sbml content_blob
        begin
          parser = LibXML::XML::Parser.file(content_blob.filepath)
          doc = parser.parse
          doc.root.namespaces.default_prefix="sbml"
          params={}
          doc.find("//sbml:listOfParameters/sbml:parameter").each do |node|
            value = node.attributes["value"] || nil
            params[node.attributes["id"]]=value
          end
          params
        rescue Exception => e
          Rails.logger.error("Error processing sbml model content for content_blob #{content_blob.id} #{e}")
          {}
        end
      end

      def parameters_and_values_from_jws_dat content_blob
        begin
          params_and_values = {}
          contents = open(content_blob.filepath).read
          start_tag = "begin parameters"
          start=contents.index(start_tag)
          unless start.nil?
            last = contents.index("end parameters")
            unless last.nil?
              interesting_bit = (contents[start+start_tag.length..last-1]).strip
              unless interesting_bit.blank?
                interesting_bit.each_line do |line|
                  unless line.index("=").nil?
                    p_and_v = line.split("=")
                    params_and_values[p_and_v[0].strip]=p_and_v[1].strip
                  end
                end
              end
            end
          end
          params_and_values
        rescue Exception => e
          Rails.logger.error("Error processing dat model content for content_blob #{content_blob.id} #{e}")
          {}
        end
      end
    end
  end
end