require 'grouped_pagination'

class Person < ActiveRecord::Base

  acts_as_yellow_pages
  default_scope :order => "last_name, first_name"

  before_save :first_person_admin

  acts_as_notifiee

  #grouped_pagination :pages=>("A".."Z").to_a #shouldn't need "Other" tab for people
  #load the configuration for the pagination
  grouped_pagination :pages=>("A".."Z").to_a, :default_page => Seek::Config.default_page(self.name.underscore.pluralize)

  validates_presence_of :email

  #FIXME: consolidate these regular expressions into 1 holding class
  validates_format_of :email,:with=>RFC822::EmailAddress
  validates_format_of :web_page, :with=>/(^$)|(^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$)/ix,:allow_nil=>true,:allow_blank=>true

  validates_uniqueness_of :email,:case_sensitive => false

  has_and_belongs_to_many :disciplines

  has_many :group_memberships

  has_many :favourite_group_memberships, :dependent => :destroy
  has_many :favourite_groups, :through => :favourite_group_memberships

  has_many :work_groups, :through=>:group_memberships, :before_add => proc {|person, wg| person.project_subscriptions.build :project => wg.project unless person.project_subscriptions.detect {|ps| ps.project == wg.project}}
  has_many :studies, :foreign_key => :person_responsible_id
  has_many :assays,:foreign_key => :owner_id

  acts_as_taggable_on :tools, :expertise

  has_one :user, :dependent=>:destroy

  has_many :assets_creators, :dependent => :destroy, :foreign_key => "creator_id"
  has_many :created_data_files, :through => :assets_creators, :source => :asset, :source_type => "DataFile"
  has_many :created_models, :through => :assets_creators, :source => :asset, :source_type => "Model"
  has_many :created_sops, :through => :assets_creators, :source => :asset, :source_type => "Sop"
  has_many :created_publications, :through => :assets_creators, :source => :asset, :source_type => "Publication"
  has_many :created_presentations,:through => :assets_creators,:source=>:asset,:source_type => "Presentation"

  acts_as_solr(:fields => [ :first_name, :last_name,:expertise,:tools,:locations, :roles ],:include=>[:disciplines]) if Seek::Config.solr_enabled

  named_scope :without_group, :include=>:group_memberships, :conditions=>"group_memberships.person_id IS NULL"
  named_scope :registered,:include=>:user,:conditions=>"users.person_id != 0"
  named_scope :pals,:conditions=>{:is_pal=>true}
  named_scope :admins,:conditions=>{:is_admin=>true}

  alias_attribute :webpage,:web_page

  has_many :project_subscriptions, :before_add => proc {|person, ps| ps.person = person},:dependent => :destroy
  accepts_nested_attributes_for :project_subscriptions, :allow_destroy => true

  has_many :subscriptions,:dependent => :destroy
  before_create :set_default_subscriptions

  def set_default_subscriptions
    projects.each do |proj|
      project_subscriptions.build :project => proj
    end
  end

  #FIXME: change userless_people to use this scope - unit tests
  named_scope :not_registered,:include=>:user,:conditions=>"users.person_id IS NULL"

  def self.userless_people
    p=Person.find(:all)
    return p.select{|person| person.user.nil?}
  end

  #returns an array of Person's where the first and last name match
  def self.duplicates
    people=Person.all
    dup=[]
    people.each do |p|
      peeps=people.select{|p2| p.name==p2.name}
      dup = dup | peeps if peeps.count>1
    end
    return dup
  end

  # get a list of people with their email for autocomplete fields
  def self.get_all_as_json
    all_people = Person.find(:all, :order => "ID asc")
    names_emails = all_people.collect{ |p| {"id" => p.id,
        "name" => (p.first_name.blank? ? (logger.error("\n----\nUNEXPECTED DATA: person id = #{p.id} doesn't have a first name\n----\n"); "(NO FIRST NAME)") : p.first_name) + " " +
                  (p.last_name.blank? ? (logger.error("\n----\nUNEXPECTED DATA: person id = #{p.id} doesn't have a last name\n----\n"); "(NO LAST NAME)") : p.last_name),
        "email" => (p.email.blank? ? "unknown" : p.email) } }
    return names_emails.to_json
  end

  def validates_associated(*associations)
    associations.each do |association|
      class_eval do
        validates_each(associations) do |record, associate_name, value|
          associates = record.send(associate_name)
          associates = [associates] unless associates.respond_to?('each')
          associates.each do |associate|
            if associate && !associate.valid?
              associate.errors.each do |key, value|
                record.errors.add(key, value)
              end
            end
          end
        end
      end
    end
  end

  def people_i_may_know
    res=[]
    institutions.each do |i|
      i.people.each do |p|
        res << p unless p==self or res.include? p
      end
    end

    projects.each do |proj|
      proj.people.each do |p|
        res << p unless p==self or res.include? p
      end
    end
    return  res
  end

  def institutions
    work_groups.scoped(:include => :institution).collect {|wg| wg.institution }.uniq
  end

  def projects
    #updating workgroups doesn't change groupmemberships until you save. And vice versa.
    work_groups.collect {|wg| wg.project }.uniq | group_memberships.collect{|gm| gm.work_group.project}
  end

  def member?
    !projects.empty?
  end

  def member_of?(item_or_array)
    array = [item_or_array].flatten
    array.detect {|item| projects.include?(item)}
  end

  def locations
    # infer all person's locations from the institutions where the person is member of
    locations = self.institutions.collect { |i| i.country unless i.country.blank? }

    # make sure this list is unique and (if any institutions didn't have a country set) that 'nil' element is deleted
    locations = locations.uniq
    locations.delete(nil)

    return locations
  end

  def email_with_name
    name + " <" + email + ">"
  end

  def name
    firstname=first_name
    firstname||=""
    lastname=last_name
    lastname||=""
    #capitalize, including double barrelled names
    #TODO: why not just store them like this rather than processing each time? Will need to reprocess exiting entries if we do this.
    return (firstname.gsub(/\b\w/) {|s| s.upcase} + " " + lastname.gsub(/\b\w/) {|s| s.upcase}).strip
  end

  def roles
    roles = []
    group_memberships.each do |gm|
      roles = roles | gm.roles
    end
    roles
  end



  def update_first_letter
    no_last_name=last_name.nil? || last_name.strip.blank?
    first_letter = strip_first_letter(last_name) unless no_last_name
    first_letter = strip_first_letter(name) if no_last_name
    #first_letter = "Other" unless ("A".."Z").to_a.include?(first_letter)
    self.first_letter=first_letter
  end

  def project_roles(project)
    #Get intersection of all project memberships + person's memberships to find project membership
    memberships = group_memberships.select{|g| g.work_group.project == project}
    return memberships.collect{|m| m.roles}.flatten
  end

  def assets
    created_data_files | created_models | created_sops | created_publications | created_presentations
  end

  def can_be_edited_by?(subject)
    subject == nil ? false : ((subject.is_admin? || subject.is_project_manager?) && (self.user.nil? || !self.is_admin?))
  end

  def subscriptions_setting  subscriptions_attributes
       subscriptions_attributes.reject{|s|s["subscribed_resource_types"].blank?}.each do |st|
          subscription = self.subscriptions.detect{|s|s.project_id==st["project_id"].to_i}
          if subscription
            subscription.subscribed_resource_types = st["subscribed_resource_types"]
            subscription.subscription_type = st["subscription_type"]
            subscription.subscribed_resource_types.each do |srt|
               eval(srt).find(:all).select(&:can_edit?).each do |object|
                 object.current_user_subscribed= true
                 object.subscription_type= subscription.subscription_type
               end
            end
            subscription.save!
          end
       end
  end

  def can_view? user = User.current_user
    not user.nil?
  end

  def can_edit? user = User.current_user
    new_record? or user && (user.is_admin? || user.is_project_manager? || user == self.user)
  end

  does_not_require_can_edit :is_admin
  requires_can_manage :is_admin, :can_edit_projects, :can_edit_institutions

  def can_manage? user = User.current_user
    user.is_admin?
  end

  def can_destroy? user = User.current_user
    can_manage? user
  end

  def title_is_public?
    true
  end

  private

  #a before_save trigger, that checks if the person is the first one created, and if so defines it as admin
  def first_person_admin
    self.is_admin=true if Person.count==0
  end
end
