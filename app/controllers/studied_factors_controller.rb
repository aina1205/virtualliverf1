class StudiedFactorsController < ApplicationController
  before_filter :login_required
  before_filter :find_data_file_auth
  before_filter :create_new_studied_factor, :only=>[:index]

  def index
    respond_to do |format|
      format.html
      format.xml {render :xml=>@data_file.studied_factors}
    end
  end

  def create
    @studied_factor=StudiedFactor.new(params[:studied_factor])
    @studied_factor.data_file=@data_file
    @studied_factor.data_file_version = params[:version]

    render :update do |page|
      if @studied_factor.save
        page.insert_html :bottom,"studied_factors_rows",:partial=>"factor_row",:object=>@studied_factor,:locals=>{:show_delete=>true}
        page.visual_effect :highlight,"studied_factors"
      else
        page.alert(@studied_factor.errors.full_messages)
      end
    end

  end

  def destroy
    @studied_factor=StudiedFactor.find(params[:id])

    render :update do |page|
      if @studied_factor.destroy
        page.visual_effect :fade,"studied_factor_row_#{@studied_factor.id}"
      else
        page.alert(@studied_factor.errors.full_messages)
      end
    end
  end

  private

  def find_data_file_auth
    begin
      data_file = DataFile.find(params[:data_file_id])
      the_action=action_name
      the_action="edit" if the_action=="destroy" #we are not destroying the sop, just editing its exp conditions
      if data_file.can_perform? translate_action(the_action)
        @data_file = data_file
        @display_data_file = params[:version] ? @data_file.find_version(params[:version]) : @data_file.latest_version
      else
        respond_to do |format|
          flash[:error] = "You are not authorized to perform this action"
          format.html { redirect_to sops_path }
        end
        return false
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        flash[:error] = "Couldn't find the Data file"
        format.html { redirect_to data_files_path }
      end
      return false
    end
  end

  def create_new_studied_factor
    @studied_factor=StudiedFactor.new(:data_file=>@data_file)
  end


  
end
