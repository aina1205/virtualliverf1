ActionController::Routing::Routes.draw do |map|

  map.resources :site_announcements,:collection=>{:feed=>:get}
  
end