module SopsHelper

  def authorised_sops
    sops=Sop.find(:all,:include=>:asset)
    Authorization.authorize_collection("show",sops,current_user)
  end  

  def sops_link_list sops,sorted=true,max_length=75
    sops=sops.sort{|a,b| a.title<=>b.title}
    sops=Authorization.authorize_collection("view", sops, current_user,false)
    return "<span class='none_text'>No sops or non visible to you</span>" if sops.empty?
    result=""
    sops.each do |sop|
      result += link_to h(truncate(sop.title,:length=>max_length)),sop,:title=>h(sop.title)
      result += " | " unless sops.last==sop
    end
    return result
  end
  
  def sop_version_path(sop)
    sop_path(sop, :version => sop.version)
  end
end
