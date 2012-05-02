class AssaysController < ApplicationController

  include DotGenerator
  include IndexPager
  include Seek::AnnotationCommon


  before_filter :find_assets, :only=>[:index]
  before_filter :find_and_auth, :only=>[:edit, :update, :destroy, :show]


   def new_object_based_on_existing_one
    @existing_assay =  Assay.find(params[:id])
    @assay = @existing_assay.clone_with_associations
    params[:data_file_ids]=@existing_assay.data_file_masters.collect{|d|"#{d.id},None"}
    params[:related_publication_ids]= @existing_assay.related_publications.collect{|p| "#{p.id},None"}

    unless @assay.study.can_edit?
      @assay.study = nil
      flash.now[:notice] = "The study of the existing assay cannot be viewed, please specify your own study! <br/>"
    end

    @existing_assay.data_file_masters.each do |d|
      if !d.can_view?
       flash.now[:notice] << "Some or all data files of the existing assay cannot be viewed, you may specify your own! <br/>"
        break
      end
    end
    @existing_assay.sop_masters.each do |s|
       if !s.can_view?
       flash.now[:notice] << "Some or all sops of the existing assay cannot be viewed, you may specify your own! <br/>"
        break
      end
    end
    @existing_assay.model_masters.each do |m|
       if !m.can_view?
       flash.now[:notice] << "Some or all models of the existing assay cannot be viewed, you may specify your own! <br/>"
        break
      end
    end

    render :action=>"new"
   end

  def new
    @assay=Assay.new
    @assay.create_from_asset = params[:create_from_asset]
    study = Study.find(params[:study_id]) if params[:study_id]
    @assay.study = study if params[:study_id] if study.try :can_edit?
    @assay_class=params[:class]
    @assay.assay_class=AssayClass.for_type(@assay_class) unless @assay_class.nil?

    investigations = Investigation.all.select &:can_view?
    studies=[]
    investigations.each do |i|
      studies << i.studies.select(&:can_view?)
    end
    respond_to do |format|
      if investigations.blank?
         flash.now[:notice] = "No study and investigation available, you have to create a new investigation first before creating your study and assay!"
      else
        if studies.flatten.blank?
          flash.now[:notice] = "No study available, you have to create a new study before creating your assay!"
        end
      end

      format.html
      format.xml
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create
    @assay        = Assay.new(params[:assay])

    organisms     = params[:assay_organism_ids] || []
    sop_ids       = params[:assay_sop_ids] || []
    data_file_ids = params[:data_file_ids] || []
    model_ids     = params[:assay_model_ids] || []


#    organism_ids= organisms.collect{|o|o.split(",").first}.to_a
#    @assay.assay_organisms=organism_ids.collect{|o_id|AssayOrganism.new(:organism_id=>o_id,:assay_id=>@assay)}
#    @assay.assay_organisms.each do |ao|
#      ao.mark_for_destruction
#    end
     organisms.each do |text|
      o_id, strain, culture_growth_type_text,t_id,t_title=text.split(",")
      culture_growth=CultureGrowthType.find_by_title(culture_growth_type_text)
      @assay.associate_organism(o_id, strain, culture_growth,t_id,t_title)
    end


    update_annotations @assay

    @assay.owner=current_user.person

    @assay.policy.set_attributes_with_sharing params[:sharing], @assay.projects


      if @assay.save
        data_file_ids.each do |text|
          a_id, r_type = text.split(",")
          d = DataFile.find(a_id)
          @assay.relate(d, RelationshipType.find_by_title(r_type)) if d.can_view?
        end
        model_ids.each do |a_id|
          m = Model.find(a_id)
          @assay.relate(m) if m.can_view?
        end
        sop_ids.each do |a_id|
          s = Sop.find(a_id)
          @assay.relate(s) if s.can_view?
        end

        # update related publications
        Relationship.create_or_update_attributions(@assay, params[:related_publication_ids].collect { |i| ["Publication", i.split(",").first] }, Relationship::RELATED_TO_PUBLICATION) unless params[:related_publication_ids].nil?

        #required to trigger the after_save callback after the assets have been associated
        @assay.save

        if @assay.create_from_asset =="true"
          render :action=>:update_assays_list
        else
          respond_to do |format|
          flash[:notice] = 'Assay was successfully created.'
          format.html { redirect_to(@assay) }
          format.xml { render :xml => @assay, :status => :created, :location => @assay }
          end
        end
      else
        respond_to do |format|
        format.html { render :action => "new" }
        format.xml { render :xml => @assay.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update

    #FIXME: would be better to resolve the differences, rather than keep clearing and reading the assets and organisms
    #DOES resolve differences for assets now
    organisms             = params[:assay_organism_ids]||[]

    organisms             = params[:assay_organism_ids] || []
    sop_ids               = params[:assay_sop_ids] || []
    data_file_ids         = params[:data_file_ids] || []
    model_ids             = params[:assay_model_ids] || []
    publication_params    = params[:related_publication_ids].nil?? [] : params[:related_publication_ids].collect { |i| ["Publication", i.split(",").first]}

    @assay.assay_organisms = []
#    organism_ids= organisms.collect{|o|o.split(",").first}.to_a
#    @assay.assay_organisms=organism_ids.collect{|o_id|AssayOrganism.new(:organism_id=>o_id,:assay_id=>@assay)}
#    @assay.assay_organisms.each do |ao|
#      ao.mark_for_destruction
#    end
    organisms.each do |text|
          o_id, strain, culture_growth_type_text,t_id,t_title=text.split(",")
          culture_growth=CultureGrowthType.find_by_title(culture_growth_type_text)
          @assay.associate_organism(o_id, strain, culture_growth,t_id,t_title)
    end

    update_annotations @assay

    assay_assets_to_keep = [] #Store all the asset associations that we are keeping in this
    @assay.attributes = params[:assay]
    if params[:sharing]
      @assay.policy_or_default
      @assay.policy.set_attributes_with_sharing params[:sharing], @assay.projects
    end

    respond_to do |format|
      if @assay.save
        data_file_ids.each do |text|
          a_id, r_type = text.split(",")
          d = DataFile.find(a_id)
          assay_assets_to_keep << @assay.relate(d, RelationshipType.find_by_title(r_type)) if d.can_view?
        end
        model_ids.each do |a_id|
          m = Model.find(a_id)
          assay_assets_to_keep << @assay.relate(m) if m.can_view?
        end
        sop_ids.each do |a_id|
          s = Sop.find(a_id)
          assay_assets_to_keep << @assay.relate(s) if s.can_view?
        end
        #Destroy AssayAssets that aren't needed
        (@assay.assay_assets - assay_assets_to_keep.compact).each { |a| a.destroy }

        # update related publications

        Relationship.create_or_update_attributions(@assay,publication_params, Relationship::RELATED_TO_PUBLICATION)

        #FIXME: required to update timestamp. :touch=>true on AssayAsset association breaks acts_as_trashable
        @assay.updated_at=Time.now
        @assay.save!

        flash[:notice] = 'Assay was successfully updated.'
        format.html { redirect_to(@assay) }
        format.xml { head :ok }
      else

        format.html { render :action => "edit" }
        format.xml { render :xml => @assay.errors, :status => :unprocessable_entity }
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml
      format.svg { render :text=>to_svg(@assay.study, params[:deep]=='true', @assay) }
      format.dot { render :text=>to_dot(@assay.study, params[:deep]=='true', @assay) }
      format.png { render :text=>to_png(@assay.study, params[:deep]=='true', @assay) }
    end
  end

  def destroy

    respond_to do |format|
      if @assay.can_delete?(current_user) && @assay.destroy
        format.html { redirect_to(assays_url) }
        format.xml { head :ok }
      else
        flash.now[:error]="Unable to delete the assay" if !@assay.study.nil?
        format.html { render :action=>"show" }
        format.xml { render :xml => @assay.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update_types
    render :update do |page|
      page.replace_html "favourite_list", :partial=>"favourites/gadget_list"
    end
  end

  def preview
    element=params[:element]
    assay  =Assay.find_by_id(params[:id])

    render :update do |page|
      if assay.try :can_view?
        page.replace_html element, :partial=>"assays/associate_resource_list_item", :locals=>{:resource=>assay}
      else
        page.replace_html element, :text=>"Nothing is selected to preview."
      end
    end
  end
end
