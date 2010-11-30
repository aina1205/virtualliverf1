module Seek  
  module AssetsCommon
    require 'net/ftp'
    
    #required to get the icon_filename_for_key
    include ImagesHelper
    
    def url_response_code asset_url
      url = URI.parse(asset_url)
      code=""
      if (["http","https"].include?(url.scheme))
        Net::HTTP.start(url.host, url.port) do |http|
          code = http.head(url.request_uri).code        
        end
      elsif (url.scheme=="ftp")        
        username = 'anonymous'
        password = nil
        username, password = url.userinfo.split(/:/) if url.userinfo
        begin
          ftp = Net::FTP.new(url.host)
          ftp.login(username,password)
          ftp.getbinaryfile(url.path, '/dev/null', 20) { break }
          ftp.close
          code="200"
        rescue Net::FTPPermError
          code="401"        
        end                
      else
        raise URI::InvalidURIError.new("Only http, https and ftp are supported")  
      end
      
      return code
    end
    
    def test_asset_url
      c = self.controller_name.downcase
      symb=c.singularize.to_sym
      
      icon_filename=icon_filename_for_key("error")
      code=""
      msg=""
      asset_url=params[symb][:data_url]
      begin        
        code = url_response_code(asset_url)        
        if code == "200"
          icon_filename=icon_filename_for_key("tick")
          msg="The URL was accessed successfully"
        elsif code == "302"
          icon_filename=icon_filename_for_key("warn")
          msg="The url responded with a <b>redirect</b>. It can still be used, but content type and filename may not be recorded.<br/>You will also not be able to make a copy. When a user downloads this file, they will be redirected to the URL."
        elsif code == "401"
          icon_filename=icon_filename_for_key("warn")
          msg="The url responded with <b>unauthorized</b>.<br/> It can still be used, but content type and filename will not be recorded.<br/>You will also not be able to make a copy. When a user downloads this file, they will be redirected to the URL."
        end        
      rescue Exception=>e        
        msg="There was a problem accessing the URL. You can test the link by opening in another window:<br/>"+asset_url
      end
      
      image = "<img src='/images/#{icon_filename}'/>"
      render :update do |page|
        page.replace_html "test_url_result_icon",image
        if msg.length>0
          page.replace_html "test_url_msg",msg
          page.show 'test_url_msg'
          page.visual_effect :highlight,"test_url_msg"
          if code=="302" || code=="401"            
            page['local_copy'].checked=false
            page['local_copy'].disable            
          else
            page['local_copy'].enable
          end
        end
      end
    end
    
    def download_jerm_asset asset
      project=asset.project
      project.decrypt_credentials
      downloader=Jerm::DownloaderFactory.create project.name
      resource_type = resource.class.name.split("::")[0] #need to handle versions, e.g. Sop::Version
      data_hash = downloader.get_remote_data asset.content_blob.url,project.site_username,project.site_password, resource_type
      send_file data_hash[:data_tmp_path], :filename => data_hash[:filename] || resource.original_filename, :content_type => data_hash[:content_type] || asset.content_type, :disposition => 'attachment'
    end
    
    def download_via_url asset    
      code = url_response_code(asset.content_blob.url)
      if (["302","401"].include?(code))
        redirect_to(asset.content_blob.url,:target=>"_blank")
      else
        downloader=RemoteDownloader.new
        data_hash = downloader.get_remote_data asset.content_blob.url
        send_file data_hash[:data_tmp_path], :filename => data_hash[:filename] || asset.original_filename, :content_type => data_hash[:content_type] || asset.content_type, :disposition => 'attachment'
      end      
    end
    
    def handle_data render_action_on_error=:new
      c = self.controller_name.downcase    
      symb=c.singularize.to_sym
      
      if (params[symb][:data]).blank? && (params[symb][:data_url]).blank?
        flash.now[:error] = "Please select a file to upload or provide a URL to the data."
        if render_action_on_error
          respond_to do |format|
            format.html do 
              set_parameters_for_sharing_form
              render :action => render_action_on_error
            end
          end
        end
        return false
      elsif !(params[symb][:data]).blank? && (params[symb][:data]).size == 0 && (params[symb][:data_url]).blank?
        flash.now[:error] = "The file that you are uploading is empty. Please check your selection and try again!"
        if render_action_on_error
          respond_to do |format|          
            format.html do 
              set_parameters_for_sharing_form
              render :action => render_action_on_error
            end
          end
        end
        return false
      else
        #upload takes precendence if both params are present
        begin
          if !(params[symb][:data]).blank?
            # store properties and contents of the file temporarily and remove the latter from params[],
            # so that when saving main object params[] wouldn't contain the binary data anymore
            params[symb][:content_type] = (params[symb][:data]).content_type
            params[symb][:original_filename] = (params[symb][:data]).original_filename
            @data = params[symb][:data].read
          elsif !(params[symb][:data_url]).blank?
            make_local_copy = params[symb][:local_copy]=="1"
            @data_url=params[symb][:data_url]
            code = url_response_code @data_url
            if (code == "200")
              downloader=RemoteDownloader.new
              data_hash = downloader.get_remote_data @data_url,nil,nil,nil,make_local_copy
              if make_local_copy
                file=File.open data_hash[:data_tmp_path],"r"
                #FIXME: this needs changing to avoid holding the data content in memory
                @data=file.read
              end
              params[symb][:content_type] = data_hash[:content_type]
              params[symb][:original_filename] = data_hash[:filename]
            elsif (["302","401"].include?(code))
              params[symb][:content_type] = ""
              params[symb][:original_filename] = ""
            else
              flash.now[:error] = "Processing the URL responded with a response code (#{code}), indicating the URL is inaccessible."
              if render_action_on_error
                respond_to do |format|                  
                  format.html do 
                    set_parameters_for_sharing_form
                    render :action => render_action_on_error
                  end
                end
              end
              return false
            end            
          end        
        rescue Exception=>e    
          raise e
          flash.now[:error] = "Unable to read from the URL."
          if render_action_on_error
            respond_to do |format|            
              format.html do 
                set_parameters_for_sharing_form
                render :action => render_action_on_error
              end
            end
          end
          return false
        end
        params[symb].delete 'data_url'
        params[symb].delete 'data'
        params[symb].delete 'local_copy' 
        return true
      end
    end  
    
    def handle_download asset
      if asset.content_blob.url.blank?
        if asset.content_blob.file_exists?
          send_file asset.content_blob.filepath, :filename => asset.original_filename, :content_type => asset.content_type, :disposition => 'attachment'
        else
          send_data asset.content_blob.data, :filename => asset.original_filename, :content_type => asset.content_type, :disposition => 'attachment'  
        end      
      else
        if asset.contributor.nil? #A jerm generated resource
          download_jerm_resource asset
        else
          if asset.content_blob.file_exists?
            send_file asset.content_blob.filepath, :filename => asset.original_filename, :content_type => asset.content_type, :disposition => 'attachment'
          else
            download_via_url asset
          end
        end
      end
    end    
  end
end