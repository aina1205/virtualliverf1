require 'test_helper'

class AuthLookupJobTest  < ActiveSupport::TestCase

  def setup
    @val = Seek::Config.auth_lookup_enabled
    Seek::Config.auth_lookup_enabled=true
    AuthLookupUpdateQueue.destroy_all
    Delayed::Job.destroy_all
  end

  def teardown
    Seek::Config.auth_lookup_enabled=@val
  end

  test "exists" do
    assert !AuthLookupUpdateJob.exists?
    assert_difference("Delayed::Job.count",1) do
      Delayed::Job.enqueue AuthLookupUpdateJob.new
    end

    assert AuthLookupUpdateJob.exists?

    job=Delayed::Job.first
    assert_nil job.locked_at
    job.locked_at = Time.now
    job.save!
    assert !AuthLookupUpdateJob.exists?,"Should ignore locked jobs"
  end

  test "count" do
    assert_equal 0,AuthLookupUpdateJob.count

    Delayed::Job.enqueue AuthLookupUpdateJob.new


    assert_equal 1, AuthLookupUpdateJob.count

    job=Delayed::Job.first
    assert_nil job.locked_at
    job.locked_at = Time.now
    job.save!
    assert_equal 0, AuthLookupUpdateJob.count,"Should ignore locked jobs"
    assert_equal 1,AuthLookupUpdateJob.count(false),"Should not ignore locked jobs when requested"
  end

  test "add items to queue" do
    sop = Factory :sop
    data = Factory :data_file

    #need to clear the queue for items added through callbacks in the creation of the test items
    AuthLookupUpdateQueue.destroy_all
    Delayed::Job.destroy_all

    assert_difference("Delayed::Job.count",1) do
      assert_difference("AuthLookupUpdateQueue.count",2) do
        AuthLookupUpdateJob.add_items_to_queue [sop,data,sop]
      end
    end

    assert_equal [data,sop], AuthLookupUpdateQueue.all.collect{|a| a.item}.sort_by{|i| i.class.name}

    AuthLookupUpdateQueue.destroy_all
    Delayed::Job.destroy_all
    assert_difference("Delayed::Job.count",1) do
      assert_difference("AuthLookupUpdateQueue.count",1) do
        AuthLookupUpdateJob.add_items_to_queue nil
      end
    end
    assert_nil AuthLookupUpdateQueue.first.item
  end

  test "perform" do
    user = Factory :user
    other_user = Factory :user
    sop = Factory :sop, :contributor=>user, :policy=>Factory(:publicly_viewable_policy)
    AuthLookupUpdateQueue.destroy_all
    AuthLookupUpdateJob.add_items_to_queue sop
    Sop.clear_lookup_table
    assert_difference("AuthLookupUpdateQueue.count",-1) do
      AuthLookupUpdateJob.new.perform
    end

    c = ActiveRecord::Base.connection.select_one("select count(*) from sop_auth_lookup;").values[0].to_i
    #+1 to User count to include anonymous user
    assert_equal User.count+1, c

    assert_equal sop.perform_auth(user,"view"),sop.can_view?(user)
    assert_equal sop.perform_auth(user,"edit"),sop.can_edit?(user)
    assert_equal sop.perform_auth(user,"manage"),sop.can_manage?(user)
    assert_equal sop.perform_auth(user,"download"),sop.can_download?(user)
    assert_equal sop.perform_auth(user,"delete"),sop.can_delete?(user)

    assert_equal sop.perform_auth(other_user,"view"),sop.can_view?(other_user)
    assert_equal sop.perform_auth(other_user,"edit"),sop.can_edit?(other_user)
    assert_equal sop.perform_auth(other_user,"manage"),sop.can_manage?(other_user)
    assert_equal sop.perform_auth(other_user,"download"),sop.can_download?(other_user)
    assert_equal sop.perform_auth(other_user,"delete"),sop.can_delete?(other_user)
  end

  test "lookup table counts" do
    user = Factory :user
    disable_authorization_checks do
      Sop.clear_lookup_table
      assert_equal 0,Sop.lookup_count_for_user(user.id)
      sop = Factory :sop
      assert_equal 0,Sop.lookup_count_for_user(user.id)
      sop.update_lookup_table(user)
      assert_equal 1,Sop.lookup_count_for_user(user.id)
      assert sop.destroy
      assert_equal 0,Sop.lookup_count_for_user(user.id)
    end
  end

end