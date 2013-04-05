require 'test_helper'

class AssetTest < ActiveSupport::TestCase
  fixtures :all
  include ApplicationHelper

  test "default contributor or nil" do
    User.current_user = users(:owner_of_my_first_sop)
    model = Model.new(Factory.attributes_for(:model).tap{|h|h[:contributor] = nil})
    assert_equal users(:owner_of_my_first_sop),model.contributor
    model.contributor = nil
    model.save!
    assert_equal nil,model.contributor
    model = Model.find(model.id)
    assert_equal nil,model.contributor
  end

  test "assay type titles" do
    df = Factory :data_file
    assay = Factory :experimental_assay,:assay_type=>Factory(:assay_type,:title=>"aaa")
    assay2 = Factory :modelling_assay,:assay_type=>Factory(:assay_type,:title=>"bbb")

    disable_authorization_checks do
      assay.relate(df)
      assay2.relate(df)
      assay.reload
      assay2.reload
      df.reload
    end

    assert_equal ["aaa","bbb"],df.assay_type_titles.sort
    m=Factory :model
    assert_equal [],m.assay_type_titles

  end

  test "contains_downloadable_items?" do

    mock_remote_file "#{Rails.root}/test/fixtures/files/html_file.html","http://webpage.com",{'Content-Type' => 'text/html'}
    mock_remote_file "#{Rails.root}/test/fixtures/files/html_file.html","http://webpage2.com",{'Content-Type' => 'text/html'}

    df = Factory :data_file
    assert df.contains_downloadable_items?
    assert df.latest_version.contains_downloadable_items?

    df = Factory :data_file,:content_blob=>Factory(:content_blob,:url=>"http://webpage.com")
    assert !df.contains_downloadable_items?
    assert !df.latest_version.contains_downloadable_items?

    Factory.define(:model_with_urls,:parent=>:model) do |f|
      f.after_create do |model|
        model.content_blobs = [
            Factory.create(:content_blob, :url=>"http://webpage.com", :asset => model,:asset_version=>model.version),
            Factory.create(:content_blob, :url=>"http://webpage2.com", :asset => model,:asset_version=>model.version)
        ]
      end
    end

    model = Factory :model_with_urls
    assert !model.contains_downloadable_items?
    assert !model.latest_version.contains_downloadable_items?

    model = Factory :teusink_model
    assert model.contains_downloadable_items?
    assert model.latest_version.contains_downloadable_items?

    Factory.define(:model_with_urls_and_files,:parent=>:model) do |f|
      f.after_create do |model|
        model.content_blobs = [
            Factory.create(:content_blob, :url=>"http://webpage.com", :asset => model,:asset_version=>model.version),
            Factory.create(:cronwright_model_content_blob, :asset => model,:asset_version=>model.version)
        ]
      end
    end

    model = Factory :model_with_urls_and_files
    assert model.contains_downloadable_items?
    assert model.latest_version.contains_downloadable_items?

    df = DataFile.new
    assert !df.contains_downloadable_items?

    model = Model.new
    assert !model.contains_downloadable_items?

  end

  test "tech type titles" do
    df = Factory :data_file
    assay = Factory :experimental_assay,:technology_type=>Factory(:technology_type,:title=>"aaa")
    assay2 = Factory :modelling_assay,:technology_type=>Factory(:technology_type,:title=>"bbb")
    assay3 = Factory :modelling_assay,:technology_type=>nil

    disable_authorization_checks do
      assay.relate(df)
      assay2.relate(df)
      assay3.relate(df)
      assay.reload
      assay2.reload
      df.reload
    end

    assert_equal ["aaa","bbb"],df.technology_type_titles.sort
    m=Factory :model
    assert_equal [],m.technology_type_titles

  end

  test "content type from filename" do
    #to allow us to test the private method in isolation
    class TTT
      include AssetsCommonExtension
      def content_type_for_test filename
        content_type_from_filename filename
      end
    end

    ttt=TTT.new
    type = ttt.content_type_for_test "test.jpg"
    checks = [
        {:f=>"test.jpg",:t=>"image/jpeg"},
        {:f=>"test.JPG",:t=>"image/jpeg"},
        {:f=>"test.png",:t=>"image/png"},
        {:f=>"test.PNG",:t=>"image/png"},
        {:f=>"test.jpeg",:t=>"image/jpeg"},
        {:f=>"test.JPEG",:t=>"image/jpeg"},
        {:f=>"test.xls",:t=>"application/excel"},
        {:f=>"test.doc",:t=>"application/msword"},
        {:f=>"test.xlsx",:t=>"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"},
        {:f=>"test.docx",:t=>"application/vnd.openxmlformats-officedocument.wordprocessingml.document"},
        {:f=>"test.XLs",:t=>"application/excel"},
        {:f=>"test.Doc",:t=>"application/msword"},
        {:f=>"test.XLSX",:t=>"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"},
        {:f=>"test.dOCx",:t=>"application/vnd.openxmlformats-officedocument.wordprocessingml.document"},
        {:f=>"unknown.xxx",:t=>"application/octet-stream"},
        {:f=>nil,:t=>"text/html"}
    ]
    checks.each do |check|
      assert_equal check[:t],ttt.content_type_for_test(check[:f]),"Expected #{check[:t]} for #{check[:f]}"
    end

  end

  test "classifying and authorizing resources" do
    resource_array = []
    sop=sops(:my_first_sop)
    model=models(:teusink)
    data_file=data_files(:picture)
    user=users(:owner_of_my_first_sop)        
    
    sop_version1 = sop.find_version(1)
    model_version2 = model.find_version(2)
    
    resource_array << sop_version1
    resource_array << model_version2
    resource_array << data_file
    
    assert_equal 1, sop.version
    assert_equal 2, model.version
    assert_equal 1, data_file.version
    
        
    result = Asset.classify_and_authorize_resources(resource_array, true, user)    
    
    assert_equal 3, result.length
    
    assert result["Sop"].include?(sop_version1)    
    assert result["Model"].include?(model_version2)
    assert result["DataFile"].include?(data_file)
  end

  test "is_published?" do
    User.with_current_user Factory(:user) do
      public_sop=Factory(:sop,:policy=>Factory(:public_policy,:access_type=>Policy::ACCESSIBLE))
      private_model=Factory(:model,:policy=>Factory(:public_policy,:access_type=>Policy::VISIBLE))
      public_datafile=Factory(:data_file,:policy=>Factory(:public_policy))
      registered_only_assay=Factory(:assay,:policy=>Factory(:public_policy, :sharing_scope=>Policy::ALL_SYSMO_USERS))

      assert public_sop.is_published?
      assert !private_model.is_published?
      assert public_datafile.is_published?
      assert !registered_only_assay.is_published?
    end
  end

  test "publish" do
    user = Factory(:user)
    private_model=Factory(:model,:contributor=>user,:policy=>Factory(:public_policy,:access_type=>Policy::VISIBLE))
    User.with_current_user user do
      assert private_model.can_manage?,"Should be able to manage this model for the test to work"
      assert private_model.publish!
    end
    private_model.reload
    assert_equal Policy::ACCESSIBLE,private_model.policy.access_type
    assert_equal Policy::EVERYONE,private_model.policy.sharing_scope

  end

  test "is publishable" do
    assert Factory(:sop).is_publishable?
    assert Factory(:model).is_publishable?
    assert Factory(:data_file).is_publishable?
    assert !Factory(:assay).is_publishable?
    assert !Factory(:investigation).is_publishable?
    assert !Factory(:study).is_publishable?
    assert !Factory(:event).is_publishable?
    assert !Factory(:publication).is_publishable?
  end

  test "managers" do
    person=Factory(:person)
    person2=Factory(:person,:first_name=>"fred",:last_name=>"bloggs")
    user=Factory(:user)
    sop=Factory(:sop,:contributor=>person)
    assert_equal 1,sop.managers.count
    assert sop.managers.include?(person)

    df=Factory(:data_file,:contributor=>user)
    assert_equal 1,df.managers.count
    assert df.managers.include?(user.person)

    policy=Factory(:private_policy)
    policy.permissions << Factory(:permission, :contributor => user, :access_type => Policy::MANAGING, :policy => policy)
    policy.permissions << Factory(:permission, :contributor => person, :access_type => Policy::EDITING, :policy => policy)
    assay=Factory(:assay,:policy=>policy,:contributor=>person2)
    assert_equal 2,assay.managers.count
    assert assay.managers.include?(user.person)
    assert assay.managers.include?(person2)

    #this is liable to change when Project contributors are handled
    p1=Factory(:project)
    p2=Factory(:project)
    policy=Factory(:private_policy)
    policy.permissions << Factory(:permission, :contributor => p1, :access_type => Policy::MANAGING, :policy => policy)
    model=Factory(:model,:policy=>policy,:contributor=>p2)
    assert model.managers.empty?
  end

  test "tags as text array" do
    model = Factory :model
    u = Factory :user
    Factory :tag,:annotatable=>model,:source=>u,:value=>"aaa"
    Factory :tag,:annotatable=>model,:source=>u,:value=>"bbb"
    Factory :tag,:annotatable=>model,:source=>u,:value=>"ddd"
    Factory :tag,:annotatable=>model,:source=>u,:value=>"ccc"
    assert_equal ["aaa","bbb","ccc","ddd"],model.tags_as_text_array.sort

    p = Factory :person
    Factory :expertise,:annotatable=>p,:source=>u,:value=>"java"
    Factory :tool,:annotatable=>p,:source=>u,:value=>"trowel"
    assert_equal ["java","trowel"],p.tags_as_text_array.sort
  end

  test "related people" do
    df = Factory :data_file
    sop = Factory :sop
    model = Factory :model
    presentation = Factory :presentation
    publication = Factory :publication
    df.creators = [Factory(:person),Factory(:person)]
    sop.creators = [Factory(:person),Factory(:person)]
    model.creators = [Factory(:person),Factory(:person)]
    presentation.creators = [Factory(:person),Factory(:person)]
    publication.creators = [Factory(:person),Factory(:person)]

    assert_equal df.creators,df.related_people
    assert_equal sop.creators,sop.related_people
    assert_equal model.creators,model.related_people
    assert_equal presentation.creators,presentation.related_people
    assert_equal publication.creators,publication.related_people
  end

end
