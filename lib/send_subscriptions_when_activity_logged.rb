ActivityLog.class_eval do
  after_create :send_notification

  def send_notification
    if Seek::Config.email_enabled && (activity_loggable.subscribable? and activity_loggable.subscribers_are_notified_of?(action))
      SendImmediateEmailsJob.create_job(id)
    end
  end
end