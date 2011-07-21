class ExperimentalConditionsController < ApplicationController
  before_filter :login_required
  before_filter :find_and_auth_sop  
  before_filter :create_new_condition, :only=>[:index]
  before_filter :no_comma_for_decimal, :only=>[:create, :update]

  def index
    respond_to do |format|
      format.html
      format.xml {render :xml=>@sop.experimental_conditions}
    end
  end

  def create
    @experimental_condition=ExperimentalCondition.new(params[:experimental_condition])
    @experimental_condition.sop=@sop
    @experimental_condition.sop_version = params[:version]
    new_substances = params[:substance_autocompleter_unrecognized_items] || []
    known_substance_ids_and_types = params[:substance_autocompleter_selected_ids] || []
    @experimental_condition.substance = find_or_create_substance new_substances, known_substance_ids_and_types
    
    render :update do |page|
      if @experimental_condition.save
        page.insert_html :bottom,"condition_or_factor_rows",:partial=>"studied_factors/condition_or_factor_row",:object=>@experimental_condition,:locals=>{:asset => 'sop', :show_delete=>true}
        page.visual_effect :highlight,"condition_or_factor_rows"
        # clear the _add_factor form
        page.call "autocompleters['substance_autocompleter'].deleteAllTokens"
        page[:add_condition_or_factor_form].reset
        page[:substance_autocomplete_input].disabled = true
      else
        page.alert(@experimental_condition.errors.full_messages)
      end
    end
  end

  def create_from_existing
    experimental_condition_ids = []
    new_experimental_conditions = []
    #retrieve the selected FSes
    params.each do |key, value|
       if key.match('checkbox_')
         experimental_condition_ids.push value.to_i
       end
    end
    #create the new FSes based on the selected FSes
    experimental_condition_ids.each do |id|
      experimental_condition = ExperimentalCondition.find(id)
      new_experimental_condition = ExperimentalCondition.new(:measured_item_id => experimental_condition.measured_item_id, :unit_id => experimental_condition.unit_id, :start_value => experimental_condition.start_value,
                                             :end_value => experimental_condition.end_value, :substance_type => experimental_condition.substance_type, :substance_id => experimental_condition.substance_id)
      new_experimental_condition.sop=@sop
      new_experimental_condition.sop_version = params[:version]
      new_experimental_conditions.push new_experimental_condition
    end
    #
    render :update do |page|
        new_experimental_conditions.each do  |ec|
          if ec.save
            page.insert_html :bottom,"condition_or_factor_rows",:partial=>"studied_factors/condition_or_factor_row",:object=>ec,:locals=>{:asset => 'sop', :show_delete=>true}
          else
            page.alert("can not create factor studied: item: #{try_block{ec.substance.name}} #{ec.measured_item.title}, values: #{ec.start_value}-#{ec.end_value}#{ec.unit.title}, SD: #{ec.standard_deviation}")
          end
        end
        page.visual_effect :highlight,"condition_or_factor_rows"
    end
  end

  def destroy
    @experimental_condition=ExperimentalCondition.find(params[:id])
    render :update do |page|
      if @experimental_condition.destroy
        page.visual_effect :fade, "condition_or_factor_row_#{@experimental_condition.id}"
        page.visual_effect :fade, "edit_condition_or_factor_#{@experimental_condition.id}_form"
      else
        page.alert(@experimental_condition.errors.full_messages)
      end
    end
  end

  def update
      @experimental_condition = ExperimentalCondition.find(params[:id])

      new_substances = params["#{@experimental_condition.id}_substance_autocompleter_unrecognized_items"] || []
      known_substance_ids_and_types = params["#{@experimental_condition.id}_substance_autocompleter_selected_ids"] || []
      substance = find_or_create_substance new_substances,known_substance_ids_and_types

      params[:experimental_condition][:substance_id] = substance.try :id
      params[:experimental_condition][:substance_type] = substance.class.name == nil.class.name ? nil : substance.class.name

      render :update do |page|
        if  @experimental_condition.update_attributes(params[:experimental_condition])
          page.visual_effect :fade,"edit_condition_or_factor_#{@experimental_condition.id}_form"
          page.replace_html "condition_or_factor_row_#{@experimental_condition.id}", :partial => 'studied_factors/condition_or_factor_row', :object => @experimental_condition, :locals=>{:asset => 'sop', :show_delete=>true}
        else
          page.alert(@experimental_condition.errors.full_messages)
        end
      end
  end


  private

  def find_and_auth_sop
    begin
      sop = Sop.find(params[:sop_id])
      if sop.can_edit? current_user
        @sop = sop
        @display_sop = params[:version] ? @sop.find_version(params[:version]) : @sop.latest_version
      else
        respond_to do |format|
          flash[:error] = "You are not authorized to perform this action"
          format.html { redirect_to sops_path }
        end
        return false
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        flash[:error] = "Couldn't find the SOP or you are not authorized to view it"
        format.html { redirect_to sops_path }
      end
      return false
    end

  end

  def create_new_condition
    @experimental_condition=ExperimentalCondition.new(:sop=>@sop)
  end
end

