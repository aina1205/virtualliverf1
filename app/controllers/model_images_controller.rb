class ModelImagesController < ApplicationController
  before_filter :check_model_specified
  before_filter :find_model_images, :only=>[:index]
  before_filter :find_model_image_auth,:only=>[:show,:select,:edit,:update,:destroy]

  include Seek::BreadCrumbs

  def new
    @model_image = ModelImage.new
  end


   def create
       unless params[:model_image].blank? || params[:model_image][:image_file].blank?
         file_specified = true
         @model_image = ModelImage.new params[:model_image]
         @model_image.model_id = params[:model_id]
         @model_image.original_content_type = params[:model_image][:image_file].content_type
         @model_image.original_filename =  params[:model_image][:image_file].original_filename
       else
         file_specified = false
       end

       respond_to do |format|
         if file_specified && @model_image.save

           if @model_image.model.model_image_id.nil?
             @model_instance.update_attribute(:model_image_id,@model_image.id)
           end

           flash[:notice] = 'Image was successfully uploaded'
           format.html {redirect_to params[:return_to]}
         else
           @model_image = ModelImage.new
           unless file_specified
             flash.now[:error]= "You haven't specified the filename. Please choose the image file to upload."
           else
             flash.now[:error] = "The image format is unreadable. Please try again or select a different image."
           end
           format.html { render :action => 'new'}
         end
       end

   end


  def show
    params[:size] ||='200x200'

    if params[:size]=='large'
      size = ModelImage::LARGE_SIZE
    else
      size = params[:size]
    end
    size = size[0..-($1.length.to_i + 2)] if size =~ /[0-9]+x[0-9]+\.([a-z0-9]+)/ # trim file extension

    id = params[:id].to_i

    if !cache_exists?(id, size) # look in file system cache before attempting db access
      # resize (keeping image side ratio), encode and cache the picture
      @model_image.operate do |image|
        image.resize size
        @image_binary = image.image.to_blob
      end
      # cache data
      cache_data!(@model_image, @image_binary, size)
    end

    respond_to do |format|
      format.html do
        send_file(full_cache_path(id, size), :type => 'image/jpeg', :disposition => 'inline')
      end
      format.xml do
        @cache_file=full_cache_path(id, size)
        @type='image/jpeg'
      end
    end

  end

  def index
    respond_to do |format|
      format.html
    end
  end

  def destroy
     model = @model_image.model
     @model_image.destroy
     respond_to do |format|
       format.html { redirect_to model_model_images_url model.id}
     end
  end


  def select
     if @model_image.select!

       @model_image.save
       respond_to do |format|
         flash[:notice]= 'Model image was successfully updated.'
         format.html { redirect_to model_model_image_url @model_instance.id}
       end
     else
       respond_to do |format|
         flash[:error] = 'Image was already selected.'
         format.html { redirect_to url_for(@model_instance)}
       end
     end
  end


  private

  def check_model_specified
    @image_for = 'Model'
    @image_for_id = params[:model_id]

    begin
      @model_instance = Model.find(@image_for_id)
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "Could not find the #{@image_for.downcase} for this image."
      redirect_to(root_path)
      return false
    end
  end


  def find_model_images
      if @model_instance.can_view? current_user
        @model_images = ModelImage.find(:all,:conditions=>{:model_id=>@image_for_id})
      else
       flash[:error] = "You can only view images that belong to you"
       redirect_to model_path @model_instance
      end
  end


  def find_model_image_auth
     unless @model_instance.can_edit? current_user
       flash[:error] = "You can only view and, possibly, manage images of models when you can edit this model."
       redirect_to url_for @model_instance
       return false
     end

     begin

       @model_image = ModelImage.find params[:id],:conditions => { :model_id => @image_for_id}
     rescue ActiveRecord::RecordNotFound
       flash[:error] = "Image not found or belongs to a different model."
       redirect_to root_path
       return false
     end
  end

  # caches data (where size = #{size}x#{size})
  def cache_data!(image, image_binary, size=nil)
    FileUtils.mkdir_p(cache_path(image, size))
    File.open(full_cache_path(image, size), "wb+") { |f| f.write(image_binary) }
  end

  def cache_path(image, size=nil, include_local_name=false)

    id = image.kind_of?(Integer) ? image : image.id
    rtn = "#{RAILS_ROOT}/tmp/model_images"
    rtn = "#{rtn}/#{size}" if size
    rtn = "#{rtn}/#{id}.#{ModelImage.image_storage_format}" if include_local_name

    return rtn
  end

  def full_cache_path(image, size=nil)
    cache_path(image, size, true)
  end

  def cache_exists?(image, size=nil)
    File.exists?(full_cache_path(image, size))
  end

end
