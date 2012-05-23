require 'test_helper'
#Authorization tests that are specific to public access
class SubscriptionTest < ActiveSupport::TestCase

  def setup
    User.current_user = Factory(:user)
  end

  

  test 'subscribing and unsubscribing toggle subscribed?' do
    s = Factory(:subscribable)

    assert !s.subscribed?
    s.subscribe; s.save!; s.reload
    assert s.subscribed?

    s.unsubscribe; s.save!; s.reload
    assert !s.subscribed?

    another_person = Factory(:person)
    assert !s.subscribed?(another_person)
    s.subscribe(another_person); s.save!; s.reload
    assert s.subscribed?(another_person)
    s.unsubscribe(another_person); s.save!; s.reload
    assert !s.subscribed?(another_person)
  end

  test 'can subscribe to someone elses subscribable' do
    s = Factory(:subscribable, :contributor => Factory(:user))
    assert !s.subscribed?
    s.subscribe
    assert s.save
    assert s.subscribed?
  end

  test 'subscribers with a frequency of immediate are sent emails when activity is logged' do
    proj = Factory(:project)
    current_person.project_subscriptions.create :project => proj, :frequency => 'immediately'
    s = Factory(:subscribable, :projects => [Factory(:project), proj], :policy => Factory(:public_policy))
    s.subscribe; s.save!
    
    assert_emails(1) do
      Factory(:activity_log, :activity_loggable => s, :action => 'update')
    end


    other_guy = Factory(:person)
    other_guy.project_subscriptions.create :project => proj, :frequency => 'immediately'
    s.subscribe(other_guy); s.save!

    assert_emails(2) do
      Factory(:activity_log, :activity_loggable => s, :action => 'update')
    end
  end

  test 'subscribers without a frequency of immediate are not sent emails when activity is logged' do
    proj = Factory(:project)
    current_person.project_subscriptions.create :project => proj, :frequency => 'weekly'
    s = Factory(:subscribable, :projects =>[proj], :policy => Factory(:public_policy))
    s.subscribe; s.save!

    assert_no_emails do
      Factory(:activity_log, :activity_loggable => s, :action => 'update')
    end
  end

  test 'subscribers are not sent emails for items they cannot view' do
    proj = Factory(:project)
    current_person.project_subscriptions.create :project => proj, :frequency => 'immediately'
    s = Factory(:subscribable, :policy => Factory(:private_policy), :contributor => Factory(:user), :projects => [proj])

    assert_no_emails do
      User.with_current_user(s.contributor) do
        Factory(:activity_log, :activity_loggable => s, :action => 'update')
      end
    end
  end

  test 'wonky people' do
    Person.all.each do |p|
      unless p.valid?
        puts p.inspect
        puts p.errors.full_messages
      end
    end
  end

  test 'subscribers who do not receive notifications dont receive emails' do
    current_person.reload
    current_person.notifiee_info.receive_notifications = false
    current_person.notifiee_info.save!
    current_person.reload

    assert !current_person.receive_notifications?
    
    proj = Factory(:project)
    current_person.project_subscriptions.create :project => proj, :frequency => 'immediately'
    s = Factory(:subscribable, :projects => [proj], :policy => Factory(:public_policy))
    s.subscribe; s.save!

    assert_no_emails do
      Factory(:activity_log, :activity_loggable => s, :action => 'update')
    end

  end

  test 'subscribers who are not registered dont receive emails' do
    person = Factory(:person_in_project)
    proj = Factory(:project)
    s = Factory(:subscribable, :projects => [proj], :policy => Factory(:public_policy))    

    disable_authorization_checks do
      person.project_subscriptions.create :project => proj, :frequency => 'immediately'
      s.subscribe; s.save!
    end

    assert_no_emails do
      Factory(:activity_log, :activity_loggable => s, :action => 'update')
    end

  end

  private

  def current_person
    User.current_user.person
  end
end
