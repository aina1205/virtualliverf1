#DO NOT EDIT THIS FILE TO CHANGE SETTINGS. THESE ARE ONLY USED TO PRE-POPULATE THE DEFAULT VALUES.
#CHANGE THESE VALUES THROUGH THE ADMIN PAGES WHILST RUNNING SEEK.

require 'seek/config'

#Main settings
Seek::Config.default :public_seek_enabled,true
Seek::Config.default :sycamore_enabled,true
Seek::Config.default :events_enabled,true
Seek::Config.default :jerm_enabled,true
Seek::Config.default :email_enabled,false
Seek::Config.default :smtp, {:address => '', :port => '25', :domain => '', :authentication => :plain, :user_name => '', :password => ''}
Seek::Config.default :noreply_sender, 'seek1@virtual-liver.de'
Seek::Config.default :solr_enabled,false
Seek::Config.default :jws_enabled, true
Seek::Config.default :jws_online_root,"http://jjj.mib.ac.uk"
Seek::Config.default :sabiork_ws_base_url, "http://sabiork.h-its.org/sabioRestWebServices/"
Seek::Config.default :exception_notification_enabled,false
Seek::Config.default :exception_notification_recipients,""
Seek::Config.default :hide_details_enabled,false
Seek::Config.default :activation_required_enabled,false
Seek::Config.default :google_analytics_enabled, false
Seek::Config.default :google_analytics_tracker_id, '000-000'
Seek::Config.default :piwik_analytics_enabled, false
Seek::Config.default :piwik_analytics_id_site, 1
Seek::Config.default :piwik_analytics_url, 'localhost/piwik/'
Seek::Config.default :bioportal_api_key,''
Seek::Config.default :project_news_enabled,false
Seek::Config.default :project_news_feed_urls,''
Seek::Config.default :project_news_number_of_entries,10
Seek::Config.default :community_news_enabled,false
Seek::Config.default :community_news_feed_urls,''
Seek::Config.default :community_news_number_of_entries,10
Seek::Config.default :home_description, 'Some (configurable) information about the project and what we do goes here.'
Seek::Config.default :publish_button_enabled,false

Seek::Config.default :presentations_enabled,true
Seek::Config.default :scales,["organism","liver","liverLobule","intercellular","cell"]

# Branding
Seek::Config.default :project_name,'SysMO'
Seek::Config.default :project_type,'Consortium'
Seek::Config.default :project_link,'http://www.sysmo.net'

Seek::Config.default :application_name,"SEEK"
Seek::Config.default :dm_project_name,"SysMO-DB"
Seek::Config.default :dm_project_link,"http://www.sysmo-db.org"
Seek::Config.default :header_image_enabled,true
Seek::Config.default :header_image_title, "SysMO-DB"
Seek::Config.default :header_image_link,"http://www.sysmo-db.org"
Seek::Config.default :header_image,'sysmo-db-logo_smaller.png'
Seek::Config.default :copyright_addendum_enabled,false
Seek::Config.default :copyright_addendum_content,'Additions copyright ...'

Seek::Config.default :is_virtualliver, true

# Pagination
Seek::Config.default :default_pages,{:specimens => 'latest',:samples => 'latest', :people => 'latest', :projects => 'latest', :institutions => 'latest', :investigations => 'latest',:studies => 'latest', :assays => 'latest', :data_files => 'latest', :models => 'latest',:sops => 'latest', :publications => 'latest',:events => 'latest'}
Seek::Config.default :limit_latest,7

# Others
Seek::Config.default :type_managers_enabled,true
Seek::Config.default :type_managers,'users'
Seek::Config.default :tag_threshold,1
Seek::Config.default :max_visible_tags,20
Seek::Config.default :pubmed_api_email,nil
Seek::Config.default :crossref_api_email,nil
Seek::Config.default :site_base_host,"http://localhost:3000"
Seek::Config.default :open_id_authentication_store,:memory
Seek::Config.default :seek_video_link, "http://www.youtube.com/user/elinawetschHITS?feature=mhee#p/u"
Seek::Config.default :max_attachments_num,100

Seek::Config.default :admin_impersonation_enabled, true