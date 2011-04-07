
require 'simple-spreadsheet-extractor'

class DataFilesController < ApplicationController
  
  include IndexPager
  include SysMODB::SpreadsheetExtractor
  include MimeTypesHelper  
  include DotGenerator  
  include Seek::AssetsCommon

  before_filter :login_required
  
  before_filter :find_assets, :only => [ :index ]
  before_filter :find_and_auth, :except => [ :index, :new, :upload_for_tool, :create, :request_resource, :preview, :test_asset_url, :update_tags_ajax]
  before_filter :find_display_data_file, :only=>[:show,:download]
    
  def new_version
    if (handle_data nil)          
      comments=params[:revision_comment]
      @data_file.content_blob = ContentBlob.new(:tmp_io_object => @tmp_io_object, :url=>@data_url)      
      @data_file.content_type = params[:data_file][:content_type]
      @data_file.original_filename=params[:data_file][:original_filename]
      factors = @data_file.studied_factors
      respond_to do |format|
        if @data_file.save_as_new_version(comments)
          #Duplicate studied factors
          factors.each do |f|
            new_f = f.clone
            new_f.data_file_version = @data_file.version
            new_f.save
          end
          flash[:notice]="New version uploaded - now on version #{@data_file.version}"
        else
          flash[:error]="Unable to save new version"          
        end
        format.html {redirect_to @data_file }
      end
    else
      flash[:error]=flash.now[:error]
      redirect_to @data_file
    end
  end
  
  # DELETE /models/1
  # DELETE /models/1.xml
  def destroy
    #FIXME: Double check auth is working for deletion. Also, maybe should only delete if not associated with any assays.
    @data_file.destroy
    
    respond_to do |format|
      format.html { redirect_to(data_files_path) }
      format.xml  { head :ok }
    end
  end
  
  def new
    @data_file = DataFile.new
    respond_to do |format|
      if current_user.person.member?
        format.html # new.html.erb
      else
        flash[:error] = "You are not authorized to upload new Data files. Only members of known projects, institutions or work groups are allowed to create new content."
        format.html { redirect_to data_files_path }
      end
    end
  end

  def upload_for_tool

    if handle_data

      @data_file = DataFile.new params[:data_file]

      @data_file.contributor  = current_user
      @data_file.content_blob = ContentBlob.new :tmp_io_object => @tmp_io_object, :url=>@data_url
      Policy.new_for_upload_tool(@data_file, params[:recipient_id])

      if @data_file.save
        @data_file.creators = [current_user.person]
        ############################################
        #send email to the file uploader and receiver

        Mailer.deliver_file_uploaded(current_user,Person.find(params[:recipient_id]),@data_file,base_host)

        ############################################
        flash.now[:notice] ="Data file was successfully uploaded and saved." if flash.now[:notice].nil?
        render :text => flash.now[:notice]
      else
        errors = (@data_file.errors.map { |e| e.join(" ") }.join("\n"))
        render :text => errors, :status => 500
      end
    end
  end
  
  def create
    if handle_data
      
      @data_file = DataFile.new params[:data_file]
      @data_file.event_ids = params[:event_ids] || []
      @data_file.contributor=current_user
      @data_file.content_blob = ContentBlob.new :tmp_io_object => @tmp_io_object, :url=>@data_url

      update_tags @data_file

      assay_ids = params[:assay_ids] || []
      respond_to do |format|
        if @data_file.save
          # the Data file was saved successfully, now need to apply policy / permissions settings to it
          policy_err_msg = Policy.create_or_update_policy(@data_file, current_user, params)
          
          # update attributions
          Relationship.create_or_update_attributions(@data_file, params[:attributions])
          
          # update related publications
          Relationship.create_or_update_attributions(@data_file, params[:related_publication_ids].collect {|i| ["Publication", i.split(",").first]}.to_json, Relationship::RELATED_TO_PUBLICATION) unless params[:related_publication_ids].nil?
          
          #Add creators
          AssetsCreator.add_or_update_creator_list(@data_file, params[:creators])
          
          if policy_err_msg.blank?
            flash.now[:notice] = 'Data file was successfully uploaded and saved.' if flash.now[:notice].nil?
            format.html { redirect_to data_file_path(@data_file) }
          else
            flash[:notice] = "Data file was successfully created. However some problems occurred, please see these below.</br></br><span style='color: red;'>" + policy_err_msg + "</span>"
            format.html { redirect_to :controller => 'data_files', :id => @data_file, :action => "edit" }
          end

          assay_ids.each do |text|
            a_id, r_type = text.split(",")
            @assay = Assay.find(a_id)
            @assay.relate(@data_file, RelationshipType.find_by_title(r_type))
          end
        else
          format.html {
            render :action => "new"
          }
        end
      end   
    end
  end
  
  def show
    # store timestamp of the previous last usage
    @last_used_before_now = @data_file.last_used_at
    
    # update timestamp in the current Data file record
    # (this will also trigger timestamp update in the corresponding Asset)
    @data_file.last_used_at = Time.now
    @data_file.save_without_timestamping
    
    respond_to do |format|
      format.html # show.html.erb
      format.xml
      format.svg { render :text=>to_svg(@data_file,params[:deep]=='true',@data_file)}
      format.dot { render :text=>to_dot(@data_file,params[:deep]=='true',@data_file)}
      format.png { render :text=>to_png(@data_file,params[:deep]=='true',@data_file)}
    end
  end
  
  def edit
    
  end
  
  def update
    # remove protected columns (including a "link" to content blob - actual data cannot be updated!)
    if params[:data_file]
      [:contributor_id, :contributor_type, :original_filename, :content_type, :content_blob_id, :created_at, :updated_at, :last_used_at].each do |column_name|
        params[:data_file].delete(column_name)
      end
      
      # update 'last_used_at' timestamp on the DataFile
      params[:data_file][:last_used_at] = Time.now
    end

    update_tags @data_file
    assay_ids = params[:assay_ids] || []
    respond_to do |format|
      data_file_params = params[:data_file]
      data_file_params[:event_ids] = params[:event_ids]
      if @data_file.update_attributes(data_file_params)
        # the Data file was updated successfully, now need to apply updated policy / permissions settings to it
        policy_err_msg = Policy.create_or_update_policy(@data_file, current_user, params)
        
        # update attributions
        Relationship.create_or_update_attributions(@data_file, params[:attributions])
        
        # update related publications        
        Relationship.create_or_update_attributions(@data_file, params[:related_publication_ids].collect {|i| ["Publication", i.split(",").first]}.to_json, Relationship::RELATED_TO_PUBLICATION) unless params[:related_publication_ids].nil?
        
        
        #update creators
        AssetsCreator.add_or_update_creator_list(@data_file, params[:creators])
        
        if policy_err_msg.blank?
          flash[:notice] = 'Data file metadata was successfully updated.'
          format.html { redirect_to data_file_path(@data_file) }
        else
          flash[:notice] = "Data file metadata was successfully updated. However some problems occurred, please see these below.</br></br><span style='color: red;'>" + policy_err_msg + "</span>"
          format.html { redirect_to :controller => 'data_files', :id => @data_file, :action => "edit" }
        end

        # Update new assay_asset
        assay_ids.each do |text|
          a_id, r_type = text.split(",")
          @assay = Assay.find(a_id)
          @assay.relate(@data_file, RelationshipType.find_by_title(r_type))
        end
        #Destroy AssayAssets that aren't needed
        assay_assets = AssayAsset.find_all_by_asset_id(@data_file.id)
        assay_assets.each do |assay_asset|
          flag = false
          assay_ids.each do |text|
            a_id, r_type = text.split(",")
            if assay_asset.assay_id.to_s == a_id
              flag = true
            end
          end
          if flag == false
             AssayAsset.destroy(assay_asset.id)
          end
        end
      else
        format.html {
          render :action => "edit"
        }
      end
    end
end

  
  # GET /data_files/1/download
  def download
    # update timestamp in the current data file record
    # (this will also trigger timestamp update in the corresponding Asset)
    @data_file.last_used_at = Time.now
    @data_file.save_without_timestamping    
    
    handle_download @display_data_file
  end 
  
  def data
    @data_file =  DataFile.find(params[:id])
    sheet = params[:sheet] || 1
    if ["xls","xlsx"].include?(mime_extension(@data_file.content_type))

      respond_to do |format|
        format.html #currently complains about a missing template, but we don't want people using this for now - its purely XML
        format.xml {render :xml=>spreadsheet_to_xml(open(@data_file.content_blob.filepath)) }
        format.csv {render :text=>spreadsheet_to_csv(open(@data_file.content_blob.filepath),sheet) }
      end
    else
      respond_to do |format|
        flash[:error] = "Unable to view contents of this data file"
        format.html { redirect_to @data_file,:format=>"html" }
      end
    end
  end
  
  def preview
    element=params[:element]
    data_file=DataFile.find_by_id(params[:id])
    
    render :update do |page|
      if data_file.try :can_view?
        page.replace_html element,:partial=>"assets/resource_preview",:locals=>{:resource=>data_file}
      else
        page.replace_html element,:text=>"Nothing is selected to preview."
      end
    end
  end  
  
  def request_resource
    resource = DataFile.find(params[:id])
    details = params[:details]
    
    Mailer.deliver_request_resource(current_user,resource,details,base_host)
    
    render :update do |page|
      page[:requesting_resource_status].replace_html "An email has been sent on your behalf to <b>#{resource.managers.collect{|m| m.name}.join(", ")}</b> requesting the file <b>#{h(resource.title)}</b>."
    end
  end  
  
  protected    
  
  def find_display_data_file
    if @data_file
      @display_data_file = params[:version] ? @data_file.find_version(params[:version]) : @data_file.latest_version
    end
  end

  def translate_action action
    action="download" if action=="data"
    super action
  end

end
