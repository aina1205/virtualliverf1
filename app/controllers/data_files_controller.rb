
require 'simple-spreadsheet-extractor'

class DataFilesController < ApplicationController

  include IndexPager
  include SysMODB::SpreadsheetExtractor
  include MimeTypesHelper
  include DotGenerator

  include Seek::AssetsCommon
  include AssetsCommonExtension
  include Seek::ContentBlobCommon

  include Seek::AnnotationCommon

  #before_filter :login_required

  before_filter :find_assets, :only => [ :index ]
  before_filter :find_and_auth, :except => [ :index, :new, :upload_for_tool, :upload_from_email, :create, :request_resource, :preview, :test_asset_url, :update_annotations_ajax]
  before_filter :find_display_asset, :only=>[:show,:explore,:download,:matching_models]
  skip_before_filter :verify_authenticity_token, :only => [:upload_for_tool, :upload_from_email]
  before_filter :xml_login_only, :only => [:upload_for_tool, :upload_from_email]

  #has to come after the other filters
  include Seek::Publishing
  include Seek::BreadCrumbs


  def convert_to_presentation
    @data_file = DataFile.find params[:id]
    @presentation = @data_file.to_presentation

    respond_to do |format|

      if !@presentation.new_record?
        disable_authorization_checks do
          # first reload all associations which are already assigned to the presentation. Otherwise, all associations will be destroyed when data file is destroyed
          @data_file.reload
          @data_file.destroy
        end

        ActivityLog.create :action=>"create",:culprit=>User.current_user,:activity_loggable=>@presentation,:controller_name=>controller_name.downcase
        flash[:notice]="Data File '#{@presentation.title}' is successfully converted to Presentation"
        format.html { redirect_to presentation_path(@presentation) }
      else
        flash[:error] = "Data File failed to convert to Presentation!!"
        format.html {
          redirect_to data_file_path @data_file
        }
      end
    end
  end

  def download
    @asset = @data_file

    @asset_version = @display_data_file
    @content_blob = @asset_version.content_blob
    @asset.last_used_at = Time.now
    @asset.save_without_timestamping

    disposition = params[:disposition] || 'attachment'

    respond_to do |format|
      format.html {handle_download disposition}
      format.pdf {get_pdf}
    end
  end

  def plot
    sheet = params[:sheet] || 2
    @csv_data = spreadsheet_to_csv(open(@data_file.content_blob.filepath),sheet,true)
    respond_to do |format|
      format.html
    end
  end
    
  def new_version
    if (handle_data nil)          
      comments=params[:revision_comment]

      factors = @data_file.studied_factors
      respond_to do |format|
        if @data_file.save_as_new_version(comments)
          create_content_blobs
          #Duplicate studied factors
          factors.each do |f|
            new_f = f.clone
            new_f.data_file_version = @data_file.version
            new_f.save
          end
          flash[:notice] = "New version uploaded - now on version #{@data_file.version}"
          if @data_file.is_with_sample?
            bio_samples = @data_file.bio_samples_population
            unless bio_samples.errors.blank?
              flash[:notice] << "<br/> However, Sample database population failed."
              flash[:error] = bio_samples.errors.html_safe
            end
          end
        else
          flash[:error] = "Unable to save new version"
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
    @data_file.parent_name = params[:parent_name]
    @data_file.is_with_sample= params[:is_with_sample]
    @page_title = params[:page_title]
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
      params[:data_file][:project_ids] = [params[:data_file].delete(:project_id)] if params[:data_file][:project_id]
      @data_file = DataFile.new params[:data_file]

      #@data_file.content_blob = ContentBlob.new :tmp_io_object => @tmp_io_object, :url=>@data_url
      Policy.new_for_upload_tool(@data_file, params[:recipient_id])

      if @data_file.save
        @data_file.creators = [current_user.person]
        create_content_blobs
        #send email to the file uploader and receiver
        Mailer.deliver_file_uploaded(current_user,Person.find(params[:recipient_id]),@data_file,base_host)

        flash.now[:notice] ="Data file was successfully uploaded and saved." if flash.now[:notice].nil?
        render :text => flash.now[:notice]
      else
        errors = (@data_file.errors.map { |e| e.join(" ") }.join("\n"))
        render :text => errors, :status => 500
      end
    end
  end

  def upload_from_email
    if current_user.is_admin? && Seek::Config.admin_impersonation_enabled
      User.with_current_user Person.find(params[:sender_id]).user do
        if handle_data
          @data_file = DataFile.new params[:data_file]

          Policy.new_from_email(@data_file, params[:recipient_ids], params[:cc_ids])

          if @data_file.save
            @data_file.creators = [User.current_user.person]
            create_content_blobs

            flash.now[:notice] ="Data file was successfully uploaded and saved." if flash.now[:notice].nil?
            render :text => flash.now[:notice]
          else
            errors = (@data_file.errors.map { |e| e.join(" ") }.join("\n"))
            render :text => errors, :status => 500
          end
        end
      end
    else
      render :text => "This user is not permitted to act on behalf of other users", :status => :forbidden
    end
  end

  def create
    if handle_data

      @data_file = DataFile.new params[:data_file]
      #@data_file.content_blob = ContentBlob.new :tmp_io_object => @tmp_io_object, :url=>@data_url


      @data_file.policy.set_attributes_with_sharing params[:sharing], @data_file.projects

      assay_ids = params[:assay_ids] || []


      if @data_file.save
        update_annotations @data_file

        create_content_blobs

        # update attributions
        Relationship.create_or_update_attributions(@data_file, params[:attributions])

        # update related publications
        Relationship.create_or_update_attributions(@data_file, params[:related_publication_ids].collect { |i| ["Publication", i.split(",").first] }, Relationship::RELATED_TO_PUBLICATION) unless params[:related_publication_ids].nil?

        #Add creators
        AssetsCreator.add_or_update_creator_list(@data_file, params[:creators])
        if @data_file.parent_name=="assay"
          render :partial => "assets/back_to_fancy_parent", :locals => {:child => @data_file, :parent_name => @data_file.parent_name, :is_not_fancy => true}
        else
          respond_to do |format|
            flash[:notice] = 'Data file was successfully uploaded and saved.' if flash.now[:notice].nil?
            #parse the data file if it is with sample data
            if @data_file.is_with_sample
              bio_samples = @data_file.bio_samples_population params[:institution_id]
              #@bio_samples = bio_samples
              #Rails.logger.warn "BIO SAMPLES ::: " + @bio_samples.treatments_text
              unless  bio_samples.errors.blank?
                flash[:notice] << "<br/> However, Sample database population failed."
                flash[:error] = bio_samples.errors.html_safe
                #respond_to do |format|
                #  format.html{
                #    render :action => "new"
                #  }
                # end
              end
            end
            assay_ids.each do |text|
              a_id, r_type = text.split(",")
              @assay = Assay.find(a_id)
              if @assay.can_edit?
                @assay.relate(@data_file, RelationshipType.find_by_title(r_type))
              end
            end
            format.html { redirect_to data_file_path(@data_file) }
          end
        end
        deliver_request_publish_approval params[:sharing], @data_file

      else
        respond_to do |format|
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

    #Rails.logger.warn "template in data_files_controller/show : #{params[:parsing_template]}"

    respond_to do |format|
      format.html #{render :locals => {:template => params[:parsing_template]}}# show.html.erb
      format.xml
      format.rdf { render :text=>@data_file.to_rdf }
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

    publication_params    = params[:related_publication_ids].nil?? [] : params[:related_publication_ids].collect { |i| ["Publication", i.split(",").first]}

    update_annotations @data_file

    assay_ids = params[:assay_ids] || []
    respond_to do |format|
      @data_file.attributes = params[:data_file]

      if params[:sharing]
        @data_file.policy_or_default
        @data_file.policy.set_attributes_with_sharing params[:sharing], @data_file.projects
      end

      if @data_file.save

        # update attributions
        Relationship.create_or_update_attributions(@data_file, params[:attributions])
        
        # update related publications        
        Relationship.create_or_update_attributions(@data_file, publication_params, Relationship::RELATED_TO_PUBLICATION)
        
        
        #update creators
        AssetsCreator.add_or_update_creator_list(@data_file, params[:creators])

        flash[:notice] = 'Data file metadata was successfully updated.'
        format.html { redirect_to data_file_path(@data_file) }


        # Update new assay_asset
        a_ids = []
        assay_ids.each do |text|
          a_id, r_type = text.split(",")
          a_ids.push(a_id)
          @assay = Assay.find(a_id)
          if @assay.can_edit?
            @assay.relate(@data_file, RelationshipType.find_by_title(r_type))
          end
        end

        #Destroy AssayAssets that aren't needed
        assay_assets = @data_file.assay_assets
        assay_assets.each do |assay_asset|
          if assay_asset.assay.can_edit? and !a_ids.include?(assay_asset.assay_id.to_s)
            AssayAsset.destroy(assay_asset.id)
          end
        end
        deliver_request_publish_approval params[:sharing], @data_file

      else
        format.html {
          render :action => "edit"
        }
      end
    end
  end

  def data
    @data_file =  DataFile.find(params[:id])
    sheet = params[:sheet] || 1
    trim = params[:trim]
    trim ||= false
    if ["xls","xlsx"].include?(mime_extension(@data_file.content_blob.content_type))

      respond_to do |format|
        format.html #currently complains about a missing template, but we don't want people using this for now - its purely XML
        format.xml {render :xml=>spreadsheet_to_xml(open(@data_file.content_blob.filepath)) }
        format.csv {render :text=>spreadsheet_to_csv(open(@data_file.content_blob.filepath),sheet,trim) }
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
  
  def explore
    if @display_data_file.contains_extractable_spreadsheet?
      #Generate Ruby spreadsheet model from XML
      @spreadsheet = @display_data_file.spreadsheet

      #FIXME: Annotations need to be specific to version
      @spreadsheet.annotations = @display_data_file.spreadsheet_annotations
      respond_to do |format|
        format.html
      end
    else
     respond_to do |format|
        flash[:error] = "Unable to view contents of this data file"
        format.html { redirect_to data_file_path(@data_file,:version=>@display_data_file.version) }
      end
    end
  end

  def clear_population bio_samples
      specimens = Specimen.find_all_by_title bio_samples.instance_values["specimen_names"].values
      samples = Sample.find_all_by_title bio_samples.instance_values["sample_names"].values
      samples.each do |s|
        s.assays.clear
        s.destroy
      end
      specimens.each &:destroy
  end
  
  def matching_models
    #FIXME: should use the correct version
    matching_models = @data_file.matching_models

    render :update do |page|
      page.visual_effect :toggle_blind,"matching_models"
      page.visual_effect :toggle_blind,'matching_results'
      html = ""
      matching_models.each do |match|
        model = Model.find(match.primary_key)
        if (model.can_view?)
          html << "<div>"
          html << "<div class='matchmake_result'>Matched with <b>#{match.search_terms.join(', ')}</b></div>"
          html << render(:partial=>"layouts/resource_list_item", :object=>model)
          html << "</div>"
        end
      end
      page.replace_html "matching_results",:text=>html
    end
  end
  
  protected

  def translate_action action
    action="download" if action=="data"
    action="view" if ["matching_models"].include?(action)
    super action
  end

  def xml_login_only
    unless session[:xml_login]
      flash[:error] = "Only available when logged in via xml"
      redirect_to root_url
    end
  end

end
