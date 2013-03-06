class ProjectSubscriptionJob < Struct.new(:project_subscription_id)

  DEFAULT_PRIORITY=2

  def perform
    ps = ProjectSubscription.find_by_id(project_subscription_id)
    if ps
      project = ps.project
      all_in_project(project).each do |item|
        item.subscriptions << Subscription.new(:person => ps.person, :project_subscription_id => project_subscription_id) unless item.subscribed?(ps.person)
      end
      project.ancestors.each do |parent_project|
        all_in_project(parent_project).each do |item|
          item.subscriptions << Subscription.new(:person => ps.person) unless item.subscribed?(ps.person)
        end
      end
    end
  end

  def self.exists? project_subscription_id
    Delayed::Job.find(:first, :conditions => ['handler = ? AND locked_at IS ? AND failed_at IS ?', ProjectSubscriptionJob.new(project_subscription_id).to_yaml, nil, nil]) != nil
  end

  def self.create_job project_subscription_id, t=15.seconds.from_now, priority=DEFAULT_PRIORITY
    Delayed::Job.enqueue(ProjectSubscriptionJob.new(project_subscription_id), priority, t) unless exists? project_subscription_id
  end

  def all_in_project project
    assets = []
    assets |= project.studies
    assets |= project.assays

    #assay and study dont have project association table
    subscribable_types = Seek::Util.persistent_classes.select(&:subscribable?).collect(&:name).reject{|t| t=='Assay' || t=='Study'}

    assets |= subscribable_types.collect do |type|
      # e.g.: 'data_files_projects'
      assets_projects_table = ["#{type.underscore.pluralize}", 'projects'].sort.join('_')
      assets_for_project project, type, assets_projects_table
    end.flatten.uniq
    assets
    assets
  end

  def assets_for_project project, asset_type, assets_projects_table
    asset_id = asset_type.underscore + "_id"
    klass =  asset_type.constantize
    table = assets_projects_table
    sql = "select #{asset_id} from #{table}"
    sql << " where #{table}.project_id = #{project.id}"
    ids = ActiveRecord::Base.connection.select_all(sql).collect{|k| k["#{asset_id}"]}
    klass.find_all_by_id(ids)
  end
end
