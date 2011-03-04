#DO NOT EDIT THIS FILE.
#TO MODIFY THE DEFAULT SETTINGS, COPY seek_local.rb.pre to seek_local.rb AND EDIT THAT FILE INSTEAD

require 'authorization'
require 'save_without_timestamping'
require 'asset'
require 'calendar_date_select'
require 'active_record_extensions'
require 'acts_as_taggable_extensions'

JWS_ENABLED=true unless defined? JWS_ENABLED
JERM_ENABLED=true unless defined? JERM_ENABLED
SOLR_ENABLED=false unless defined? SOLR_ENABLED
ACTIVITY_LOG_ENABLED=true unless defined? ACTIVITY_LOG_ENABLED
EMAIL_ENABLED=false unless defined? EMAIL_ENABLED
ACTIVATION_REQUIRED=false unless defined? ACTIVATION_REQUIRED
EXCEPTION_NOTIFICATION_ENABLED=false unless defined? EXCEPTION_NOTIFICATION_ENABLED
ENABLE_GOOGLE_ANALYTICS=false unless defined? ENABLE_GOOGLE_ANALYTICS
TAG_THRESHOLD=1 unless defined? TAG_THRESHOLD
MAX_VISIBLE_TAGS=20 unless defined? MAX_VISIBLE_TAGS
GLOBAL_PASSPHRASE="ohx0ipuk2baiXah" unless defined? GLOBAL_PASSPHRASE
TYPE_MANAGERS="admins" unless defined? TYPE_MANAGERS
HIDE_DETAILS=false unless defined? HIDE_DETAILS
EVENTS_ENABLED=true unless defined? EVENTS_ENABLED
PUBMED_API_EMAIL = "" unless defined? PUBMED_API_EMAIL
CROSSREF_API_EMAIL = "" unless defined? CROSSREF_API_EMAIL
JWS_ONLINE_ROOT = "http://jjj.mib.ac.uk" unless defined? JWS_ONLINE_ROOT

#this is needed for the xlinks in the REST API.
SITE_BASE_HOST="http://localhost:3000" unless defined? SITE_BASE_HOST

# Set Google Analytics code
if ENABLE_GOOGLE_ANALYTICS
  Rubaidh::GoogleAnalytics.tracker_id = GOOGLE_ANALYTICS_TRACKER_ID
else
  Rubaidh::GoogleAnalytics.tracker_id = "000-000"
end

if EXCEPTION_NOTIFICATION_ENABLED
  ExceptionNotifier.render_only = false
else
  ExceptionNotifier.render_only = true
end


#The order in which asset tabs appear
ASSET_ORDER                = ['Person', 'Project', 'Institution', 'Investigation', 'Study', 'Assay', 'DataFile', 'Model', 'Sop', 'Publication', 'SavedSearch', 'Organism', 'Event']

OpenIdAuthentication.store = :memory

APPLICATION_NAME="SysMO-SEEK" unless defined? APPLICATION_NAME
APPLICATION_TITLE=APPLICATION_NAME unless defined? APPLICATION_TITLE

PROJECT_NAME="SysMO" unless defined? PROJECT_NAME
PROJECT_TITLE="The SysMO Project" unless defined? PROJECT_TITLE
PROJECT_TYPE="Consortium" unless defined? PROJECT_TYPE
PROJECT_LONG_NAME="#{PROJECT_NAME} #{PROJECT_TYPE}" unless defined? PROJECT_LONG_NAME
PROJECT_LINK="http://www.sysmo.net" unless defined? PROJECT_LINK

DM_PROJECT_NAME="SysMO-DB" unless defined? DM_PROJECT_NAME
DM_PROJECT_TITLE=DM_PROJECT_NAME unless defined? DM_PROJECT_TITLE
DM_PROJECT_LINK="http://www.sysmo-db.org/" unless defined? DM_PROJECT_LINK

HEADER_IMAGE="sysmo-db-logo_smaller.png" unless defined? HEADER_IMAGE
HEADER_IMAGE_LINK=DM_PROJECT_LINK unless defined? HEADER_IMAGE_LINK
HEADER_IMAGE_TITLE=DM_PROJECT_NAME unless defined? HEADER_IMAGE_TITLE

NOREPLY_SENDER="no-reply@sysmo-db.org" unless defined? NOREPLY_SENDER

# limit list of the entry in a page
PAGINATE_LATEST_LIMIT= 7 unless defined? PAGINATE_LATEST_LIMIT
