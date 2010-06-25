module IndexPager
  
  def index
    controller = self.controller_name.downcase    
    model_name=controller.classify
    model_class=eval(model_name)
    objects = eval("@"+controller)
    @hidden=0
    params[:page] ||= "latest"
    
    if (model_class.respond_to?("acts_as_resource")) 
      authorized=Authorization.authorize_collection("show",objects,current_user)
      @hidden=objects.size - authorized.size
      objects=authorized
    end
    objects=Sop.paginate_after_fetch(objects, :page=>params[:page]) unless objects.respond_to?("page_totals")
    eval("@"+controller+"= objects")
    
    respond_to do |format|
      format.html
      format.xml
    end
    
  end
  
end