require 'test_helper'
require 'time_test_helper'

class MailerTest < ActionMailer::TestCase
  fixtures :all

  test "signup" do
    @expected.subject = 'SEEK account activation'
    @expected.to = "Aaron Spiggle <aaron@email.com>"
    @expected.from    = "no-reply@sysmo-db.org"
    @expected.date    = Time.now

    @expected.body    = read_fixture('signup')
    
    force_now_is(@expected.date) do
      assert_equal @expected.encoded, Mailer.create_signup(users(:aaron),"localhost").encoded
    end
    
  end
  
  test "signup_open_id" do
    @expected.subject = 'SEEK account activation'
    @expected.to = "Aaron Openid Spiggle <aaron_openid@email.com>"
    @expected.from    = "no-reply@sysmo-db.org"
    @expected.date    = Time.now

    @expected.body    = read_fixture('signup_openid')
    
    force_now_is(@expected.date) do
      assert_equal @expected.encoded, Mailer.create_signup(users(:aaron_openid),"localhost").encoded
    end
    
  end
  
  test "announcement notification" do
    announcement = site_announcements(:mail)
    @expected.subject = "SEEK Announcement: #{announcement.title}"
    @expected.to = "Fred Blogs <fred@email.com>"
    @expected.from    = "no-reply@sysmo-db.org"
    @expected.date    = Time.now

    @expected.body    = read_fixture('announcement_notification')
    
    person=people(:fred)
    force_now_is(@expected.date) do
      assert_equal @expected.encoded, Mailer.create_announcement_notification(announcement,person.notifiee_info,"localhost").encoded
    end    
  end

  test "feedback anonymously" do
    @expected.subject = 'SEEK Feedback provided - This is a test feedback'
    @expected.to = "Quentin Jones <quentin@email.com>"
    @expected.from    = "no-reply@sysmo-db.org"    
    @expected.date    = Time.now

    @expected.body    = read_fixture('feedback_anon')
    force_now_is(@expected.date) do
      assert_equal @expected.encoded,Mailer.create_feedback(users(:aaron),"This is a test feedback","testing the feedback message",true,"localhost").encoded
    end
  end

  test "feedback non anonymously" do
    @expected.subject = 'SEEK Feedback provided - This is a test feedback'
    @expected.to = "Quentin Jones <quentin@email.com>"
    @expected.from    = "no-reply@sysmo-db.org"
    @expected.reply_to = "Aaron Spiggle <aaron@email.com>"
    @expected.date    = Time.now

    @expected.body    = read_fixture('feedback_non_anon')
    force_now_is(@expected.date) do
      assert_equal @expected.encoded,Mailer.create_feedback(users(:aaron),"This is a test feedback","testing the feedback message",false,"localhost").encoded
    end
  end

  test "request resource" do
    @expected.subject = "A SEEK member requested a protected file: Picture"
    #TODO: hardcoding the formating rather than passing an array was require for rails 2.3.8 upgrade
    @expected.to = "Datafile Owner <data_file_owner@email.com>,\r\n\t OwnerOf MyFirstSop <owner@sop.com>"
    @expected.from = "no-reply@sysmo-db.org"
    @expected.reply_to = "Aaron Spiggle <aaron@email.com>"
    @expected.date = Time.now

    @expected.body = read_fixture('request_resource')

    resource=data_files(:picture)
    user=users(:aaron)
    details="here are some more details"
    force_now_is(@expected.date) do
      assert_equal @expected.encoded,Mailer.create_request_resource(user,resource,details,"localhost").encoded
    end
  end

  test "request publish approval" do
    resource = data_files(:picture)
    gatekeeper = people(:gatekeeper_person)
    @expected.subject = "A SEEK member requested your approval to publish: #{resource.title}"
    #TODO: hardcoding the formating rather than passing an array was require for rails 2.3.8 upgrade
    @expected.to = gatekeeper.email_with_name
    @expected.from = "no-reply@sysmo-db.org"
    @expected.reply_to = "Aaron Spiggle <aaron@email.com>"
    @expected.date = Time.now

    @expected.body = read_fixture('request_publish_approval')
    user=users(:aaron)
    pretend_now_is(@expected.date) do
      assert_equal @expected.encoded,Mailer.create_request_publish_approval([gatekeeper],user,resource,"localhost").encoded
    end
  end

  test "request publishing" do

    @expected.subject = "A SEEK member requests you make some items public"
    @expected.to = "Datafile Owner <data_file_owner@email.com>"
    @expected.from = "no-reply@sysmo-db.org"
    @expected.reply_to = "Aaron Spiggle <aaron@email.com>"
    @expected.date = Time.now
    @expected.body = read_fixture('request_publishing')

    publisher = people(:aaron_person)
    owner = people(:person_for_datafile_owner)

    resources=[assays(:metabolomics_assay),data_files(:picture),models(:teusink),assays(:metabolomics_assay2),data_files(:sysmo_data_file)]

    force_now_is(@expected.date) do
      assert_equal @expected.encoded,Mailer.create_request_publishing(publisher,owner,resources,"localhost").encoded
    end
  end

  test "request resource no details" do
    @expected.subject = "A SEEK member requested a protected file: Picture"
    #TODO: hardcoding the formating rather than passing an array was require for rails 2.3.8 upgrade
    @expected.to = "Datafile Owner <data_file_owner@email.com>,\r\n\t OwnerOf MyFirstSop <owner@sop.com>"
    @expected.from = "no-reply@sysmo-db.org"
    @expected.reply_to = "Aaron Spiggle <aaron@email.com>"
    @expected.date = Time.now

    @expected.body = read_fixture('request_resource_no_details')

    resource=data_files(:picture)
    user=users(:aaron)
    details=""
    force_now_is(@expected.date) do
      assert_equal @expected.encoded,Mailer.create_request_resource(user,resource,details,"localhost").encoded
    end
  end

  test "forgot_password" do
    @expected.subject = 'SEEK - Password reset'
    @expected.to = "Aaron Spiggle <aaron@email.com>"
    @expected.from    = "no-reply@sysmo-db.org"
    @expected.date    = Time.now

    @expected.body    = read_fixture('forgot_password')
    
    u=users(:aaron)
    u.reset_password_code_until = 1.day.from_now
    u.reset_password_code="fred"
    
    force_now_is(@expected.date) do
      assert_equal @expected.encoded, Mailer.create_forgot_password(users(:aaron),"localhost").encoded
    end    
  end

  test "contact_admin_new_user_no_profile" do
    recipients = ["Quentin Jones <quentin@email.com>","\r\nProject Manager <project_manager@email.com>"]
    @expected.subject = 'SEEK member signed up'
    @expected.to =  recipients
    @expected.from    = "no-reply@sysmo-db.org"
    @expected.reply_to = "Aaron Spiggle <aaron@email.com>"
    @expected.date    = Time.now

    @expected.body    = read_fixture('contact_admin_new_user_no_profile')
    
    force_now_is(@expected.date) do
      assert_equal @expected.encoded, 
        Mailer.create_contact_admin_new_user_no_profile("test message",users(:aaron),"localhost").encoded
    end
    
  end

  test "contact_project_manager_new_user_no_profile" do
    project_manager = Factory(:project_manager)
    @expected.subject = 'SEEK member signed up, please assign this person to the projects which you are project manager'
    @expected.to = project_manager.email_with_name
    @expected.from    = "no-reply@sysmo-db.org"
    @expected.reply_to = "Aaron Spiggle <aaron@email.com>"
    @expected.date    = Time.now

    @expected.body    = read_fixture('contact_project_manager_new_user_no_profile')

    force_now_is(@expected.date) do
      assert_equal @expected.encoded,
        Mailer.create_contact_project_manager_new_user_no_profile(project_manager,"test message",users(:aaron),"localhost").encoded
    end

  end

  test "welcome" do
    @expected.subject = 'Welcome to SEEK'
    @expected.to = "Quentin Jones <quentin@email.com>"
    @expected.from    = "no-reply@sysmo-db.org"
    @expected.date = Time.now
    
    @expected.body = read_fixture('welcome')
    
    force_now_is(@expected.date) do
      assert_equal @expected.encoded, Mailer.create_welcome(users(:quentin),"localhost").encoded
    end
  end

end
