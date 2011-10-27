#DO NOT EDIT THIS FILE.
#TO MODIFY THE DEFAULT SETTINGS, COPY seek_local.rb.pre to seek_local.rb AND EDIT THAT FILE INSTEAD

require 'object'
require 'authorization'
require 'save_without_timestamping'
require 'asset'
require 'calendar_date_select'
require 'object'
require 'active_record_extensions'
require 'acts_as_taggable_extensions'
require 'acts_as_isa'
require 'acts_as_yellow_pages'
require 'seek/acts_as_uniquely_identifiable'
require 'acts_as_favouritable'
require 'acts_as_asset'
require 'send_subscriptions_when_activity_logged'
require 'modporter_extensions'
require 'seek/taggable'


GLOBAL_PASSPHRASE="ohx0ipuk2baiXah" unless defined? GLOBAL_PASSPHRASE

ASSET_ORDER                = ['Person', 'Project', 'Institution', 'Investigation', 'Study', 'Assay', 'Sample','Specimen','DataFile', 'Model', 'Sop', 'Publication', 'Presentation','SavedSearch', 'Organism', 'Event']

PORTER_SECRET = "" unless defined? PORTER_SECRET

Seek::Config.propagate_all

Annotations::Config.attribute_names_to_allow_duplicates.concat(["tag"])
Annotations::Config.versioning_enabled = false

