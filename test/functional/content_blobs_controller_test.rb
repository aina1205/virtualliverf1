require 'test_helper'
require 'webmock/test_unit'

class ContentBlobsControllerTest < ActionController::TestCase

  fixtures :all

  include AuthenticatedTestHelper

  def setup
    login_as(:quentin)
  end

  test "should find_and_auth_asset for get_pdf" do
    sop1 = Factory(:pdf_sop, :policy => Factory(:all_sysmo_downloadable_policy))

    get :get_pdf, :sop_id => sop1.id, :id => sop1.content_blob.id
    assert_response :success

    sop2 = Factory(:pdf_sop, :policy => Factory(:private_policy))
    get :get_pdf, :sop_id => sop2.id, :id => sop2.content_blob.id
    assert_redirected_to sop2
    assert_not_nil flash[:error]
  end

  test "should find_and_auth_asset for download" do
    sop1 = Factory(:pdf_sop, :policy => Factory(:all_sysmo_downloadable_policy))

    get :download, :sop_id => sop1.id, :id => sop1.content_blob.id
    assert_response :success

    sop2 = Factory(:pdf_sop, :policy => Factory(:private_policy))
    get :download, :sop_id => sop2.id, :id => sop2.content_blob.id
    assert_redirected_to sop2
    assert_not_nil flash[:error]
  end

  test "should find_and_auth_content_blob for get_pdf" do
    sop1 = Factory(:pdf_sop, :policy => Factory(:all_sysmo_downloadable_policy))
    sop2 = Factory(:pdf_sop, :policy => Factory(:private_policy))

    get :get_pdf, :sop_id => sop1.id, :id => sop1.content_blob.id
    assert_response :success

    get :get_pdf, :sop_id => sop1.id, :id => sop2.content_blob.id
    assert_redirected_to :root
    assert_not_nil flash[:error]
  end

  test "should find_and_auth_content_blob for download" do
    sop1 = Factory(:pdf_sop, :policy => Factory(:all_sysmo_downloadable_policy))
    sop2 = Factory(:pdf_sop, :policy => Factory(:private_policy))

    get :download, :sop_id => sop1.id, :id => sop1.content_blob.id
    assert_response :success

    get :download, :sop_id => sop1.id, :id => sop2.content_blob.id
    assert_redirected_to :root
    assert_not_nil flash[:error]
  end

  test 'get_pdf' do
    ms_word_sop = Factory(:doc_sop, :policy => Factory(:all_sysmo_downloadable_policy))
    pdf_path = ms_word_sop.content_blob.filepath('pdf')
    FileUtils.rm pdf_path if File.exists?(pdf_path)
    assert !File.exists?(pdf_path)
    assert ms_word_sop.can_download?

    get :get_pdf, {:sop_id => ms_word_sop.id, :id => ms_word_sop.content_blob.id}
    assert_response :success
    assert File.exists?(ms_word_sop.content_blob.filepath)
    assert File.exists?(pdf_path)
  end

  test 'get_pdf from url' do
    mock_remote_file "#{Rails.root}/test/fixtures/files/a_pdf_file.pdf","http://somewhere.com/piccy.pdf"
    pdf_sop = Factory(:sop,
                      :policy => Factory(:all_sysmo_downloadable_policy),
                      :content_blob => Factory(:pdf_content_blob, :data => nil, :url => "http://somewhere.com/piccy.pdf"))
    assert !pdf_sop.content_blob.file_exists?

    get :get_pdf, {:sop_id => pdf_sop.id, :id => pdf_sop.content_blob.id}

    assert_response :success
    #the file is fetched on fly, instead of saving locally
    assert !File.exists?(pdf_sop.content_blob.filepath)
    assert !File.exists?(pdf_sop.content_blob.filepath('pdf'))
  end

  test 'get_pdf of a doc file from url' do
    mock_remote_file "#{Rails.root}/test/fixtures/files/ms_word_test.doc","http://somewhere.com/piccy.doc"
    doc_sop = Factory(:sop,
                      :policy => Factory(:all_sysmo_downloadable_policy),
                      :content_blob => Factory(:doc_content_blob, :data => nil, :url => "http://somewhere.com/piccy.doc"))

    get :get_pdf, {:sop_id => doc_sop.id, :id => doc_sop.content_blob.id}
    assert_response :success
    #the file is fetched on fly, instead of saving locally
    assert !File.exists?(doc_sop.content_blob.filepath)
    assert !File.exists?(doc_sop.content_blob.filepath('pdf'))
  end

  test "report error when file unavailable for download" do
    df = Factory :data_file, :policy=>Factory(:public_policy)
    df.content_blob.dump_data_to_file
    assert df.content_blob.file_exists?
    FileUtils.rm df.content_blob.filepath
    assert !df.content_blob.file_exists?

    get :download,:data_file_id=>df, :id => df.content_blob

    assert_redirected_to df
    assert flash[:error].match(/Unable to find a copy of the file for download/)
  end


  #This test is quite fragile, because it relies on an external resource
  test "should redirect on download for 302 url" do
    mock_http
    df  = Factory :data_file,
                  :policy => Factory(:all_sysmo_downloadable_policy),
                  :content_blob => Factory(:url_content_blob, :url=>"http://mocked302.com")
    assert !df.content_blob.file_exists?

    get :download, :data_file_id => df, :id => df.content_blob
    assert_redirected_to "http://mocked302.com"
  end

  #This test is quite fragile, because it relies on an external resource
  test "should redirect on download for 401 url" do
    mock_http
    df  = Factory :data_file,
                  :policy => Factory(:all_sysmo_downloadable_policy),
                  :content_blob => Factory(:url_content_blob, :url=>"http://mocked401.com")
    assert !df.content_blob.file_exists?

    get :download, :data_file_id => df, :id => df.content_blob
    assert_redirected_to "http://mocked401.com"
  end

  test "should download" do
    df = Factory :small_test_spreadsheet_datafile,:policy=>Factory(:public_policy), :contributor=>User.current_user
    assert_difference('ActivityLog.count') do
      get :download, :data_file_id => df, :id => df.content_blob
    end
    assert_response :success
    assert_equal "attachment; filename=\"small-test-spreadsheet.xls\"",@response.header['Content-Disposition']
    assert_equal "application/excel",@response.header['Content-Type']
    assert_equal "7168",@response.header['Content-Length']
  end

  test "should download from url" do
    mock_http
    df  = Factory :data_file,
                  :policy => Factory(:all_sysmo_downloadable_policy),
                  :content_blob => Factory(:url_content_blob, :url=>"http://mockedlocation.com/a-piccy.png")
    assert_difference('ActivityLog.count') do
      get :download, :data_file_id => df, :id => df.content_blob
    end
    assert_response :success
  end

  test "should gracefully handle when downloading a unknown host url" do
    WebMock.allow_net_connect!
    df  = Factory :data_file,
                  :policy => Factory(:all_sysmo_downloadable_policy),
                  :content_blob => Factory(:url_content_blob, :url=>"http://sdkfhsdfkhskfj.com/pic.png")

    get :download, :data_file_id => df, :id => df.content_blob

    assert_redirected_to data_file_path(df,:version=>df.version)
    assert_not_nil flash[:error]
  end

  test "should gracefully handle when downloading a url resulting in 404" do
    mock_http
    df  = Factory :data_file,
                  :policy => Factory(:all_sysmo_downloadable_policy),
                  :content_blob => Factory(:url_content_blob, :url=>"http://mocked404.com")

    get :download, :data_file_id => df, :id => df.content_blob
    assert_redirected_to data_file_path(df,:version=>df.version)
    assert_not_nil flash[:error]
  end

  test "should handle inline download when specify the inline disposition" do
    data=File.new("#{Rails.root}/test/fixtures/files/file_picture.png","rb").read
    df = Factory :data_file,
                 :content_blob => Factory(:content_blob, :data => data, :content_type=>"images/png"),
                 :policy => Factory(:downloadable_public_policy)

    get :download, :data_file_id => df, :id => df.content_blob, :disposition => 'inline'
    assert_response :success
    assert @response.header['Content-Disposition'].include?('inline')
  end

  test "should handle normal attachment download" do
    data=File.new("#{Rails.root}/test/fixtures/files/file_picture.png","rb").read
    df = Factory :data_file,
                 :content_blob => Factory(:content_blob, :data => data, :content_type=>"images/png"),
                 :policy => Factory(:downloadable_public_policy)

    get :download, :data_file_id => df, :id => df.content_blob
    assert_response :success
    assert @response.header['Content-Disposition'].include?('attachment')
  end

  test "should download identical file from file list" do
    model = Factory :model_2_files, :policy=>Factory(:public_policy), :contributor=>User.current_user
    first_content_blob = model.content_blobs.first
    assert_difference("ActivityLog.count") do
      get :download, :model_id=>model.id, :id => first_content_blob.id
    end
    assert_response :success
    assert_equal "attachment; filename=\"#{first_content_blob.original_filename}\"",@response.header['Content-Disposition']
    assert_equal first_content_blob.content_type,@response.header['Content-Type']
    assert_equal first_content_blob.filesize.to_s,@response.header['Content-Length']
  end

  private
  def mock_http
    file="#{Rails.root}/test/fixtures/files/file_picture.png"
    stub_request(:get, "http://mockedlocation.com/a-piccy.png").to_return(:body => File.new(file), :status => 200, :headers=>{'Content-Type' => 'image/png'})
    stub_request(:head, "http://mockedlocation.com/a-piccy.png")

    stub_request(:any, "http://mocked302.com").to_return(:status=>302)
    stub_request(:any, "http://mocked401.com").to_return(:status=>401)
    stub_request(:any, "http://mocked404.com").to_return(:status=>404)
  end
end
