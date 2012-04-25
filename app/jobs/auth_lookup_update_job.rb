class AuthLookupUpdateJob

  @@my_yaml = AuthLookupUpdateJob.new.to_yaml

  BATCHSIZE=3

  def perform
    process_queue

    if AuthLookupUpdateQueue.count>0 && !AuthLookupUpdateJob.exists?
      Delayed::Job.enqueue(AuthLookupUpdateJob.new,0,1.seconds.from_now)
    end
  end

  def process_queue
    #including item_type in the order, encourages assets to be processed before users (since they are much quicker), due to tha happy coincidence
    #that User falls last alphabetically. Its not that important if a new authorized type is added after User in the future.
    todo = AuthLookupUpdateQueue.all(:limit=>BATCHSIZE,:order=>"priority,item_type,id").collect do |queued|
      todo = queued.item
      queued.destroy
      todo
    end
    todo.uniq.each do |item|
      Delayed::Job.logger.error("About to process '#{item.class.name}:#{item.id}'")
      begin
        if item.authorization_supported?
          update_for_each_user item
        elsif item.is_a?(User)
          update_assets_for_user item
        elsif item.is_a?(Person)
          update_assets_for_user item.user unless item.user.nil?
        else
          #should never get here
          Delayed::Job.logger.error("Unexecpted type encountered: #{item.class.name}")
        end
      rescue Exception=>e
        Delayed::Job.logger.error("Error occurred handing #{item.class.name}:#{item.id} - #{e.message}")
        AuthLookupUpdateJob.add_items_to_queue(item)
      end
    end
  end

  def update_for_each_user item
    User.transaction(:requires_new=>:true) do
       item.update_lookup_table(nil)
      User.all.each do |user|
        item.update_lookup_table(user)
      end
    end
    GC.start
  end

  def update_assets_for_user user
    User.transaction(:requires_new=>:true) do
      Seek::Util.authorized_types.each do |type|
        type.all.each do |item|
            item.update_lookup_table(user)
        end
      end
    end
    GC.start
  end

  def self.add_items_to_queue items, t=5.seconds.from_now, priority=0
    if Seek::Config.auth_lookup_enabled
      items = Array(items)
      disable_authorization_checks do
        items.uniq.each do |item|
          #immediately update for the current user
          if item.authorization_supported?
            item.update_lookup_table(User.current_user)
          end
          AuthLookupUpdateQueue.create(:item=>item, :priority=>priority) unless AuthLookupUpdateQueue.exists?(item)
        end
        Rails.logger.warn "#{AuthLookupUpdateQueue.count} items in AuthLookupUpdateQueue"
        Delayed::Job.enqueue(AuthLookupUpdateJob.new, 0, t) unless AuthLookupUpdateJob.exists?
      end
    end
  end

  def self.exists?
    Delayed::Job.find(:first,:conditions=>['handler = ? AND locked_at IS ?',@@my_yaml,nil]) != nil
  end

  
end