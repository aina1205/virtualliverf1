 require 'zip/zip'
 require 'zip/zipfilesystem'
 require 'libxml'
class ModelsController < ApplicationController

  include WhiteListHelper
  include IndexPager
  include DotGenerator
  include Seek::AssetsCommon
  include AssetsCommonExtension

  before_filter :pal_or_admin_required,:only=> [:create_model_metadata,:update_model_metadata,:delete_model_metadata ]
  
  before_filter :find_assets, :only => [ :index ]
  before_filter :find_and_auth, :except => [ :build,:index, :new, :create,:create_model_metadata,:update_model_metadata,:delete_model_metadata,:request_resource,:preview,:test_asset_url, :update_annotations_ajax]
  before_filter :find_display_model, :only=>[:show,:download,:execute,:builder,:simulate,:submit_to_jws,:visualise,:export_as_xgmml]
    
  before_filter :jws_enabled,:only=>[:builder,:simulate,:submit_to_jws]

  include Seek::Publishing
  
  @@model_builder = Seek::JWS::OneStop.new


  def export_as_xgmml
      type =  params[:type]
      body = @_request.body.read
      orig_doc = find_xgmml_doc @display_model
      head = orig_doc.to_s.split("<graph").first
      xgmml_doc = head + body

      xgmml_file = "model_#{@display_model.id}_version_#{@display_model.version}_vis_export.xgmml"
      File.open("#{xgmml_file}", 'w') do |f|
        f.puts xgmml_doc
      end

      send_file "#{xgmml_file}", :type=>"#{type}", :disposition=>'attachment'
  end
  def visualise
     # for xgmml file
     doc = find_xgmml_doc @display_model
     # convert " to \" and newline to \n
     #e.g.  "... <att type=\"string\" name=\"canonicalName\" value=\"CHEMBL178301\"/>\n ...  "
    @graph = %Q("#{doc.root.to_s.gsub(/"/, '\"').gsub!("\n",'\n')}")
    render :cytoscape_web,:layout => false
  end
  def send_image
    @model = Model.find params[:id]
    @display_model = @model.find_version params[:version]
    image = @display_model.model_image
      send_file "#{image.file_path  }", :type=>"JPEG", :disposition=>'inline'

  end

  # GET /models
  # GET /models.xml
  
  def new_version
    if (handle_batch_data nil)
      
      comments = params[:revision_comment]

      respond_to do |format|
        create_new_version  comments
        create_content_blobs
        format.html {redirect_to @model }
      end
    else
      flash[:error]=flash.now[:error]
      redirect_to @model
    end
  end    
  
  def delete_model_metadata
    attribute=params[:attribute]
    if attribute=="model_type"
      delete_model_type params
    elsif attribute=="model_format"
      delete_model_format params
    end
  end
  
  def builder
    saved_file=params[:saved_file]
    error=nil
    begin
      if saved_file
        supported=true
        @params_hash,@attribution_annotations,@saved_file,@objects_hash,@error_keys = @@model_builder.saved_file_builder_content saved_file
      else
        supported = @@model_builder.is_supported?(@display_model)
        @params_hash,@attribution_annotations,@saved_file,@objects_hash,@error_keys = @@model_builder.builder_content @display_model if supported
      end
    rescue Exception=>e
      error=e
      logger.error "Error submitting to JWS Online OneStop - #{e.message}"
    end
    
    respond_to do |format|
      if error
        flash[:error]="JWS Online encountered a problem processing this model."
        format.html { redirect_to model_path(@model,:version=>@display_model.version)}
      elsif !supported
        flash[:error]="This model is of neither SBML or JWS Online (Dat) format so cannot be used with JWS Online"
        format.html { redirect_to model_path(@model,:version=>@display_model.version)}        
      else
        format.html
      end
    end
  end    

#  def annotator
#    respond_to do |format|
#      format.html
#    end
#  end

  def submit_to_jws
    following_action=params.delete("following_action")    
    error=nil
    content_blob = @model.content_blob
    begin
      if following_action == "annotate"
        @params_hash,@attribution_annotations,@species_annotations,@reaction_annotations,@search_results,@cached_annotations,@saved_file,@error_keys = @@model_builder.annotate params
      else
        @params_hash,@attribution_annotations,@saved_file,@objects_hash,@error_keys = @@model_builder.construct params
      end
    rescue Exception => e
      error=e
    end

    if (!error && @error_keys.empty?)

      if following_action == "simulate"
        begin
          @applet=@@model_builder.simulate @saved_file
        rescue Exception => e
          error=e
        end
      elsif following_action == "save_new_version"
        model_format=params.delete("saved_model_format") #only used for saving as a new version
        new_version_filename=params.delete("new_version_filename")
        new_version_comments=params.delete("new_version_comments")
        if model_format == "dat"
          url=@@model_builder.saved_dat_download_url @saved_file
        elsif model_format == "sbml"
          url=@@model_builder.sbml_download_url @saved_file
        end
        if url
          downloader=Seek::RemoteDownloader.new
          data_hash = downloader.get_remote_data url
          File.open(data_hash[:data_tmp_path],"r") do |f|
            content_blob = @model.content_blobs.build(:data=>f.read)
          end
          content_blob.content_type=model_format=="sbml" ? "text/xml" : "text/plain"
          content_blob.original_filename=new_version_filename
        end
      end
    end


    respond_to do |format|
      if error
        flash[:error]="JWS Online encountered a problem processing this model."
        format.html { render :action=>"builder" }
      elsif @error_keys.empty? && following_action == "simulate"
        format.html {render :action=>"simulate",:layout=>"no_sidebar"}
      elsif @error_keys.empty? && following_action == "annotate"
        format.html {render :action=>"annotator"}
      elsif @error_keys.empty? && following_action == "save_new_version"
        create_new_version(new_version_comments)
        content_blob.asset_version = @model.version
        content_blob.save!
        format.html {redirect_to  model_path(@model,:version=>@model.version) }
      else
        format.html { render :action=>"builder" }
      end      
    end
    
  end
  
  def simulate
    error=nil
    begin
      supported = @@model_builder.is_supported?(@display_model)
      if supported
        @data_script_hash,attribution_annotations,saved_file,@objects_hash = @@model_builder.builder_content @display_model    
        @applet=@@model_builder.simulate saved_file
      end
    rescue Exception=>e
      error=e
    end
    
    respond_to do |format|
      if error
        flash[:error]="JWS Online encountered a problem processing this model."
        format.html { redirect_to(@model,:version=>@display_model.version)}                      
      elsif !supported
        flash[:error]="This model is of neither SBML or JWS Online (Dat) format so cannot be used with JWS Online"
        format.html { redirect_to(@model,:version=>@display_model.version)}        
      else
        format.html {render :layout=>"no_sidebar"}
      end
    end
    
  end
  
  def update_model_metadata
    attribute=params[:attribute]
    if attribute=="model_type"
      update_model_type params
    elsif attribute=="model_format"
      update_model_format params
    end
  end
  
  def delete_model_type params
    id=params[:selected_model_type_id]
    model_type=ModelType.find(id)
    success=false
    if (model_type.models.empty?)
      if model_type.delete
        msg="OK. #{model_type.title} was successfully removed."
        success=true
      else
        msg="ERROR. There was a problem removing #{model_type.title}"
      end
    else
      msg="ERROR - Cannot delete #{model_type.title} because it is in use."
    end
    
    render :update do |page|
      page.replace_html "model_type_selection",collection_select(:model, :model_type_id, ModelType.find(:all), :id, :title, {:include_blank=>"Not specified"},{:onchange=>"model_type_selection_changed();" })
      page.replace_html "model_type_info","#{msg}<br/>"
      info_colour= success ? "green" : "red"
      page << "$('model_type_info').style.color='#{info_colour}';"
      page.visual_effect :appear, "model_type_info"
    end
    
  end
  
  def delete_model_format params
    id=params[:selected_model_format_id]
    model_format=ModelFormat.find(id)
    success=false
    if (model_format.models.empty?)
      if model_format.delete
        msg="OK. #{model_format.title} was successfully removed."
        success=true
      else
        msg="ERROR. There was a problem removing #{model_format.title}"
      end
    else
      msg="ERROR - Cannot delete #{model_format.title} because it is in use."
    end
    
    render :update do |page|
      page.replace_html "model_format_selection",collection_select(:model, :model_format_id, ModelFormat.find(:all), :id, :title, {:include_blank=>"Not specified"},{:onchange=>"model_format_selection_changed();" })
      page.replace_html "model_format_info","#{msg}<br/>"
      info_colour= success ? "green" : "red"
      page << "$('model_format_info').style.color='#{info_colour}';"
      page.visual_effect :appear, "model_format_info"      
    end    
  end
  
  def create_model_metadata
    attribute=params[:attribute]
    if attribute=="model_type"
      create_model_type params
    elsif attribute=="model_format"
      create_model_format params
    end
  end
  
  def update_model_type params
    title=white_list(params[:updated_model_type])
    id=params[:updated_model_type_id]
    success=false
    model_type_with_matching_title=ModelType.find(:first,:conditions=>{:title=>title})
    if model_type_with_matching_title.nil? || model_type_with_matching_title.id.to_s==id
      m=ModelType.find(id)
      m.title=title
      if m.save
        msg="OK. Model type changed to #{title}."
        success=true
      else
        msg="ERROR - There was a problem changing to #{title}"
      end
    else
      msg="ERROR - Another model type with #{title} already exists"
    end
    
    render :update do |page|
      page.replace_html "model_type_selection",collection_select(:model, :model_type_id, ModelType.find(:all), :id, :title, {:include_blank=>"Not specified"},{:onchange=>"model_type_selection_changed();" })
      page.replace_html "model_type_info","#{msg}<br/>"
      info_colour= success ? "green" : "red"
      page << "$('model_type_info').style.color='#{info_colour}';"
      page.visual_effect :appear, "model_type_info"
    end
    
  end
    
  def create_model_type params
    title=white_list(params[:model_type])
    success=false
    if ModelType.find(:first,:conditions=>{:title=>title}).nil?
      new_model_type=ModelType.new(:title=>title)
      if new_model_type.save
        msg="OK. Model type #{title} added."
        success=true
      else
        msg="ERROR - There was a problem adding #{title}"
      end
    else
      msg="ERROR - Model type #{title} already exists"
    end
    
    
    render :update do |page|
      page.replace_html "model_type_selection",collection_select(:model, :model_type_id, ModelType.find(:all), :id, :title, {:include_blank=>"Not specified"},{:onchange=>"model_type_selection_changed();" })
      page.replace_html "model_type_info","#{msg}<br/>"
      info_colour= success ? "green" : "red"
      page << "$('model_type_info').style.color='#{info_colour}';"
      page.visual_effect :appear, "model_type_info"
      page << "model_types_for_deletion.push(#{new_model_type.id});" if success
      
    end
  end
  
  def create_model_format params
    title=white_list(params[:model_format])
    success=false
    if ModelFormat.find(:first,:conditions=>{:title=>title}).nil?
      new_model_format=ModelFormat.new(:title=>title)
      if new_model_format.save
        msg="OK. Model format #{title} added."
        success=true
      else
        msg="ERROR - There was a problem adding #{title}"
      end
    else
      msg="ERROR - Another model format #{title} already exists"
    end
    
    
    render :update do |page|
      page.replace_html "model_format_selection",collection_select(:model, :model_format_id, ModelFormat.find(:all), :id, :title, {:include_blank=>"Not specified"},{:onchange=>"model_format_selection_changed();" })
      page.replace_html "model_format_info","#{msg}<br/>"
      info_colour= success ? "green" : "red"
      page << "$('model_format_info').style.color='#{info_colour}';"
      page.visual_effect :appear, "model_format_info"
      page << "model_formats_for_deletion.push(#{new_model_format.id});" if success
      
    end
  end
  
  def update_model_format params
    title=white_list(params[:updated_model_format])
    id=params[:updated_model_format_id]
    success=false    
    model_format_with_matching_title=ModelFormat.find(:first,:conditions=>{:title=>title})
    if model_format_with_matching_title.nil? || model_format_with_matching_title.id.to_s==id
      m=ModelFormat.find(id)
      m.title=title
      if m.save
        msg="OK. Model format changed to #{title}."
        success=true
      else
        msg="ERROR - There was a problem changing to #{title}"
      end
    else
      msg="ERROR - Another model format with #{title} already exists"
    end
    
    render :update do |page|
      page.replace_html "model_format_selection",collection_select(:model, :model_format_id, ModelFormat.find(:all), :id, :title, {:include_blank=>"Not specified"},{:onchange=>"model_format_selection_changed();" })
      page.replace_html "model_format_info","#{msg}<br/>"
      info_colour= success ? "green" : "red"
      page << "$('model_format_info').style.color='#{info_colour}';"
      page.visual_effect :appear, "model_format_info"
    end
    
  end
  
  
  # GET /models/1
  # GET /models/1.xml
  def show
    # store timestamp of the previous last usage
    @last_used_before_now = @model.last_used_at


    # update timestamp in the current Model record
    # (this will also trigger timestamp update in the corresponding Asset)
    @model.last_used_at = Time.now
    @model.save_without_timestamping
    
    respond_to do |format|
      format.html # show.html.erb
      format.xml
      format.svg { render :text=>to_svg(@model,params[:deep]=='true',@model)}
      format.dot { render :text=>to_dot(@model,params[:deep]=='true',@model)}
      format.png { render :text=>to_png(@model,params[:deep]=='true',@model)}
    end
  end
  
  # GET /models/new
  # GET /models/new.xml
  def new    
    @model=Model.new
    @content_blob= ContentBlob.new
    respond_to do |format|
      if current_user.person.member?
        format.html # new.html.erb
      else
        flash[:error] = "You are not authorized to upload new Models. Only members of known projects, institutions or work groups are allowed to create new content."
        format.html { redirect_to models_path }
      end
    end
  end
  
  # GET /models/1/edit
  def edit

  end
  
  # POST /models
  # POST /models.xml
  def create
    if handle_batch_data
      @model = Model.new(params[:model])

      @model.policy.set_attributes_with_sharing params[:sharing], @model.projects

      update_annotations @model
      build_model_image @model,params[:model_image]
      assay_ids = params[:assay_ids] || []
      respond_to do |format|
        if @model.save

          create_content_blobs
          # update attributions
          Relationship.create_or_update_attributions(@model, params[:attributions])
          
          # update related publications
          Relationship.create_or_update_attributions(@model, params[:related_publication_ids].collect {|i| ["Publication", i.split(",").first]}, Relationship::RELATED_TO_PUBLICATION) unless params[:related_publication_ids].nil?
          
          #Add creators
          AssetsCreator.add_or_update_creator_list(@model, params[:creators])
          
          flash[:notice] = 'Model was successfully uploaded and saved.'
          format.html { redirect_to model_path(@model) }
          Assay.find(assay_ids).each do |assay|
            if assay.can_edit?
              assay.relate(@model)
            end
          end
        else
          format.html {
            render :action => "new"
          }
        end
      end
    end
    
  end

  # GET /models/1/download
  def download
    # update timestamp in the current Model record
    # (this will also trigger timestamp update in the corresponding Asset)
    @model.last_used_at = Time.now
    @model.save_without_timestamping    

    if @display_model.content_blobs.count==1 and @display_model.model_image.nil?
       handle_download @display_model
    else
      handle_download_zip @display_model
    end

  end

  def download_one_file
    content_blob = ContentBlob.find params[:id]
    if File.file? content_blob.filepath
      send_file content_blob.filepath, :type=>content_blob.content_type, :disposition => 'attachment'
    else
      download_via_url @display_model
    end
  end
  # PUT /models/1
  # PUT /models/1.xml
  def update
    # remove protected columns (including a "link" to content blob - actual data cannot be updated!)
      if params[:model]
        [:contributor_id, :contributor_type, :original_filename, :content_type, :content_blob_id, :created_at, :updated_at, :last_used_at].each do |column_name|
          params[:model].delete(column_name)
        end

        # update 'last_used_at' timestamp on the Model
        params[:model][:last_used_at] = Time.now
      end

    update_annotations @model
      publication_params    = params[:related_publication_ids].nil?? [] : params[:related_publication_ids].collect { |i| ["Publication", i.split(",").first]}

      @model.attributes = params[:model]

      if params[:sharing]
        @model.policy_or_default
        @model.policy.set_attributes_with_sharing params[:sharing], @model.projects
      end

      assay_ids = params[:assay_ids] || []
      respond_to do |format|
        if @model.save

          # update attributions
          Relationship.create_or_update_attributions(@model, params[:attributions])

          # update related publications
          Relationship.create_or_update_attributions(@model,publication_params, Relationship::RELATED_TO_PUBLICATION)

          #update creators
          AssetsCreator.add_or_update_creator_list(@model, params[:creators])

          flash[:notice] = 'Model metadata was successfully updated.'
          format.html { redirect_to model_path(@model) }
          # Update new assay_asset
          Assay.find(assay_ids).each do |assay|
            if assay.can_edit?
              assay.relate(@model)
            end
          end
          #Destroy AssayAssets that aren't needed
          assay_assets = @model.assay_assets
          assay_assets.each do |assay_asset|
            if assay_asset.assay.can_edit? and !assay_ids.include?(assay_asset.assay_id.to_s)
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
  
  # DELETE /models/1
  # DELETE /models/1.xml
  def destroy
    @model.destroy
    
    respond_to do |format|
      format.html { redirect_to(models_path) }
      format.xml  { head :ok }
    end
  end

  def preview
    
    element = params[:element]
    model = Model.find_by_id(params[:id])
    
    render :update do |page|
      if model.try :can_view?
        page.replace_html element,:partial=>"assets/resource_preview",:locals=>{:resource=>model}
      else
        page.replace_html element,:text=>"Nothing is selected to preview."
      end
    end
  end
  
  def request_resource
    resource = Model.find(params[:id])
    details = params[:details]
    
    Mailer.deliver_request_resource(current_user,resource,details,base_host)
    
    render :update do |page|
      page[:requesting_resource_status].replace_html "An email has been sent on your behalf to <b>#{resource.managers.collect{|m| m.name}.join(", ")}</b> requesting the file <b>#{h(resource.title)}</b>."
    end
  end  
  
  protected
  
  def create_new_version comments
    if @model.save_as_new_version(comments)
      flash[:notice]="New version uploaded - now on version #{@model.version}"
    else
      flash[:error]="Unable to save new version"          
    end    
  end
  
  def default_items_per_page
    return 2
  end
  
  def find_display_model
      if @model
      if logged_in? and current_user.person.member? and params[:version]
        @display_model = @model.find_version(params[:version]) ? @model.find_version(params[:version]) : @model.latest_version
      else
        @display_model = @model.latest_version
      end
    end
  end

  def translate_action action
    action="download" if action == "simulate"
    action="edit" if ["submit_to_jws","builder"].include?(action)
    super action
  end
  
  def jws_enabled
    unless Seek::Config.jws_enabled
      respond_to do |format|
        flash[:error] = "Interaction with JWS Online is currently disabled"
        format.html { redirect_to model_path(@model,:version=>@display_model.version) }
      end
      return false
    end
  end

   def build_model_image model_object, params_model_image
      unless params_model_image.blank? || params_model_image[:image_file].blank?

      # the creation of the new Avatar instance needs to have only one parameter - therefore, the rest should be set separately
      @model_image = ModelImage.new(params_model_image)
      @model_image.model_id = model_object.id
      @model_image.original_content_type = params_model_image[:image_file].content_type
      @model_image.original_filename = params_model_image[:image_file].original_filename
      model_object.model_image = @model_image
    end

   end

    def find_xgmml_doc model
      xgmml_file = @@model_builder.is_xgmml? model
      file = open(xgmml_file.filepath)
      doc = LibXML::XML::Parser.string(file.read).parse
      doc
    end

end
