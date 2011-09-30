ASSET_ARRAY=[['model_id','Model','models','model_versions'],['sop_id','Sop','sops','sop_versions'],['data_file_id','DataFile','data_files','data_file_versions'],['presentation_id','Presentation','presentations','presentation_versions']]
class MoveOriginalFilenameContentTypeFromAllAssetsToContentBlobs < ActiveRecord::Migration
  def self.up

    add_column :content_blobs,:original_filename,:string
    add_column :content_blobs,:content_type,:string
    add_column :content_blobs,:asset_id,:integer
    add_column :content_blobs,:asset_type,:string
    add_column :content_blobs,:asset_version,:integer

    #copy original_filename,content_type,version from asset_versions to content_blobs
    ASSET_ARRAY.each do |asset|
      copy_to_content_blob asset[0], asset[1],asset[3]
    end


    #remove original_filename,content_types in assets table and asset_versions table
    ASSET_ARRAY.each do |asset|
      remove_column asset[2].to_sym,:original_filename,:content_type,:content_blob_id
      remove_column asset[3].to_sym,:original_filename,:content_type,:content_blob_id
    end

  end

  def self.down

     #add original_filename,content_types in assets table and asset_versions table
    ASSET_ARRAY.each do |asset|
      add_column asset[2].to_sym, :original_filename, :string
      add_column asset[2].to_sym, :content_type, :string
      add_column asset[2].to_sym, :content_blob_id, :integer
      add_column asset[3].to_sym, :original_filename, :string
      add_column asset[3].to_sym, :content_type, :string
      add_column asset[3].to_sym, :content_blob_id, :integer
    end

    #restore data in asset_versions
    restore_asset_versions

    #restore data in assets
    ASSET_ARRAY.each do |asset|
       restore_assets asset[0],asset[2],asset[3]
    end


    remove_column :content_blobs,:original_filename,:content_type,:asset_id,:asset_type,:asset_version


  end

  def self.copy_to_content_blob asset_id,asset_type,asset_versions_table
       execute("SELECT original_filename,content_type,content_blob_id,version,#{asset_id} FROM #{asset_versions_table}").each do |asset_version|
      begin
        execute("UPDATE content_blobs SET original_filename='#{asset_version[0]}' WHERE id=#{asset_version[2]}")
        execute("UPDATE content_blobs SET content_type='#{asset_version[1]}' WHERE id=#{asset_version[2]}")
        execute("UPDATE content_blobs SET asset_version='#{asset_version[3]}' WHERE id=#{asset_version[2]}")
        execute("UPDATE content_blobs SET asset_id=#{asset_version[4]} WHERE id=#{asset_version[2]}")
        execute("UPDATE content_blobs SET asset_type='#{asset_type}' WHERE id=#{asset_version[2]}")
      rescue
        raise
      end
    end
  end

  def self.restore_asset_versions
    execute("SELECT id,asset_id,asset_type,asset_version,original_filename,content_type FROM content_blobs").each do |content_blob|
      asset_type = content_blob[2]
      asset_id = nil
      assets = nil
      asset_versions = nil
      case asset_type
        when "Model"
          asset_id = 'model_id'
          assets = 'models'
          asset_versions = 'model_versions'
        when "Sop"
          asset_id = 'sop_id'
          assets = 'sops'
          asset_versions = 'sop_versions'
        when "DataFile"
          asset_id = 'data_file_id'
          assets = 'data_files'
          asset_versions = 'data_file_versions'
        when "Presentation"
          asset_id = 'presentation_id'
          assets = 'presentations'
          asset_versions = 'presentation_versions'
        else

      end
      unless asset_id.nil? and assets.nil? and asset_versions.nil?
         execute("UPDATE #{asset_versions} SET content_blob_id=#{content_blob[0]} WHERE #{asset_id}=#{content_blob[1]} AND version=#{content_blob[3]}")
         execute("UPDATE #{asset_versions} SET original_filename='#{content_blob[4]}' WHERE #{asset_id}=#{content_blob[1]} AND version=#{content_blob[3]}")
         execute("UPDATE #{asset_versions} SET content_type='#{content_blob[5]}' WHERE #{asset_id}=#{content_blob[1]} AND version=#{content_blob[3]}")
      end

    end


  end

  def self.restore_assets  asset_id_name, assets, asset_versions
    execute("SELECT DISTINCT #{asset_id_name} FROM #{asset_versions}").each do |asset_version|
      versions = execute("SELECT content_blob_id,original_filename,content_type, #{asset_id_name} ,version FROM #{asset_versions} WHERE #{asset_id_name}=#{asset_version[0]}")
      latest_version = versions.all_hashes.last
      if latest_version["version"]=versions.num_rows.to_s
        execute("UPDATE #{assets} SET content_blob_id=#{latest_version["content_blob_id"]} WHERE id=#{latest_version["#{asset_id_name}"]}")
        execute("UPDATE #{assets} SET original_filename='#{latest_version["original_filename"]}' WHERE id=#{latest_version["#{asset_id_name}"]}")
        execute("UPDATE #{assets} SET content_type='#{latest_version["content_type"]}' WHERE id=#{latest_version["#{asset_id_name}"]}")
      end
    end

  end
end
