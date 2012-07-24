require 'test_helper'

class SendPeriodicEmailsJobTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @val = Seek::Config.email_enabled
    Seek::Config.email_enabled=true
    Delayed::Job.destroy_all
  end

  def teardown
    Delayed::Job.destroy_all
    Seek::Config.email_enabled=@val
  end

  test "exists" do
    assert !SendPeriodicEmailsJob.daily_exists?
    assert_difference("Delayed::Job.count",1) do
      Delayed::Job.enqueue SendPeriodicEmailsJob.new('daily')
    end

    assert SendPeriodicEmailsJob.daily_exists?

    job=Delayed::Job.first
    assert_nil job.locked_at
    job.locked_at = Time.now
    job.save!
    assert SendPeriodicEmailsJob.daily_exists?,"Should not ignore locked jobs"

    job.locked_at=nil
    job.failed_at = Time.now
    job.save!
    assert !SendPeriodicEmailsJob.daily_exists?,"Should ignore failed jobs"

    job.failed_at = nil
    job.save!
    assert SendPeriodicEmailsJob.daily_exists?

    assert !SendPeriodicEmailsJob.weekly_exists?
    assert_difference("Delayed::Job.count",1) do
      Delayed::Job.enqueue SendPeriodicEmailsJob.new("weekly")
    end
    assert SendPeriodicEmailsJob.weekly_exists?

    assert !SendPeriodicEmailsJob.monthly_exists?
    assert_difference("Delayed::Job.count",1) do
      Delayed::Job.enqueue SendPeriodicEmailsJob.new("monthly")
    end
    assert SendPeriodicEmailsJob.monthly_exists?

  end

  test "create job" do
      assert_equal 0,Delayed::Job.count
      SendPeriodicEmailsJob.create_job('daily', Time.now)
      assert_equal 1,Delayed::Job.count

      job = Delayed::Job.first
      assert_equal 1,job.priority

      SendPeriodicEmailsJob.create_job('daily', Time.now)
      assert_equal 1,Delayed::Job.count
  end


  test "perform" do
    Delayed::Job.destroy_all
    person1 = Factory(:person)
    person2 = Factory(:person)
    person3 = Factory(:person)
    person4 = Factory(:person)
    sop = Factory(:sop, :policy => Factory(:public_policy))
    project_subscription1 = ProjectSubscription.create(:person_id => person1.id, :project_id => sop.projects.first.id, :frequency => 'daily')
    project_subscription2 = ProjectSubscription.create(:person_id => person2.id, :project_id => sop.projects.first.id, :frequency => 'weekly')
    project_subscription3 = ProjectSubscription.create(:person_id => person3.id, :project_id => sop.projects.first.id, :frequency => 'monthly')
    project_subscription4 = ProjectSubscription.create(:person_id => person4.id, :project_id => sop.projects.first.id, :frequency => 'monthly')
    ProjectSubscriptionJob.new(project_subscription1.id).perform
    ProjectSubscriptionJob.new(project_subscription2.id).perform
    ProjectSubscriptionJob.new(project_subscription3.id).perform
    ProjectSubscriptionJob.new(project_subscription4.id).perform
    sop.reload

    SendPeriodicEmailsJob.create_job('daily', 15.minutes.from_now)
    SendPeriodicEmailsJob.create_job('weekly', 15.minutes.from_now)
    SendPeriodicEmailsJob.create_job('monthly', 15.minutes.from_now)

    Factory :activity_log,:activity_loggable => sop, :culprit => Factory(:user), :action => 'create'

    assert_emails 1 do
      SendPeriodicEmailsJob.new('daily').perform
    end
    assert_emails 1 do
      SendPeriodicEmailsJob.new('weekly').perform
    end
    assert_emails 2 do
      SendPeriodicEmailsJob.new('monthly').perform
    end
  end

  test "perform ignores unwanted actions" do
    Delayed::Job.destroy_all
    person1 = Factory(:person)
    person2 = Factory(:person)
    person3 = Factory(:person)
    sop = Factory(:sop, :policy => Factory(:public_policy))
    project_subscription1 = ProjectSubscription.create(:person_id => person1.id, :project_id => sop.projects.first.id, :frequency => 'daily')
    project_subscription2 = ProjectSubscription.create(:person_id => person2.id, :project_id => sop.projects.first.id, :frequency => 'weekly')
    project_subscription3 = ProjectSubscription.create(:person_id => person3.id, :project_id => sop.projects.first.id, :frequency => 'monthly')
    ProjectSubscriptionJob.new(project_subscription1.id).perform
    ProjectSubscriptionJob.new(project_subscription2.id).perform
    ProjectSubscriptionJob.new(project_subscription3.id).perform
    sop.reload

    SendPeriodicEmailsJob.create_job('daily', 15.minutes.from_now)
    SendPeriodicEmailsJob.create_job('weekly', 15.minutes.from_now)
    SendPeriodicEmailsJob.create_job('monthly', 15.minutes.from_now)

    assert_emails 0 do

      Factory :activity_log,:activity_loggable => sop, :culprit => Factory(:user), :action => 'show'
      Factory :activity_log,:activity_loggable => sop, :culprit => Factory(:user), :action => 'download'
      Factory :activity_log,:activity_loggable => sop, :culprit => Factory(:user), :action => 'destroy'

      SendPeriodicEmailsJob.new('daily').perform
      SendPeriodicEmailsJob.new('weekly').perform
      SendPeriodicEmailsJob.new('monthly').perform
    end
  end

  test "perform2" do
    Delayed::Job.destroy_all

    person1 = Factory :person
    person2 = Factory :person
    person3 = Factory :person, :group_memberships=>person2.group_memberships
    person4 = Factory :person, :group_memberships=>person2.group_memberships
    person4.notifiee_info.receive_notifications=false
    person4.notifiee_info.save!
    project1 = person1.projects.first
    project2 = person2.projects.first
    project3 = person3.projects.first
    assert_not_equal project1,project2
    assert_equal project2,project3

    sop = Factory(:sop, :policy=>Factory(:private_policy),:contributor=>person1,:projects=>[project1])
    model = Factory(:model, :policy=>Factory(:private_policy),:contributor=>person2,:projects=>[project2])
    data_file = Factory(:data_file,:policy=>Factory(:private_policy),:contributor=>person3,:projects=>[project2])
    data_file2 = Factory(:data_file, :policy=>Factory(:public_policy),:contributor=>person3,:projects=>[project2])

    ProjectSubscription.destroy_all
    Subscription.destroy_all

    ps = []
    ps << ProjectSubscription.create(:person_id=>person1.id,:project_id=>project1.id, :frequency=>'daily')
    ps << Factory(:project_subscription, :person_id=>person1.id,:project_id=>project2.id, :frequency=>"daily")
    ps << Factory(:project_subscription, :person_id=>person2.id,:project_id=>project1.id, :frequency=>"daily")
    ps << Factory(:project_subscription, :person_id=>person3.id,:project_id=>project1.id, :frequency=>"daily")
    ps << Factory(:project_subscription, :person_id=>person4.id,:project_id=>project1.id, :frequency=>"daily")
    ps << ProjectSubscription.create(:person_id=>person4.id,:project_id=>project2.id, :frequency=>'daily')

    ps.each {|p| ProjectSubscriptionJob.new(p.id).perform}

    disable_authorization_checks do
      Factory :activity_log, :activity_loggable=>sop, :culprit=>Factory(:user),:action=>"update"
      Factory :activity_log, :activity_loggable=>model, :culprit=>Factory(:user),:action=>"update"
      Factory :activity_log, :activity_loggable=>data_file, :culprit=>Factory(:user),:action=>"update"
      Factory :activity_log, :activity_loggable=>data_file2, :culprit=>Factory(:user),:action=>"update"
    end

    assert_emails 1 do
      SendPeriodicEmailsJob.new('daily').perform
    end


  end
end