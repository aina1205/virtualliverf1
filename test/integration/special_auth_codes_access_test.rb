require 'test_helper'


class SpecialAuthCodesAccessTest < ActionController::IntegrationTest
  ASSETS_WITH_AUTH_CODES = %w[data_files events models sops samples specimens presentations]

  ASSETS_WITH_AUTH_CODES.each do |type_name|
    test "form allows creating temporary access links for #{type_name}" do
      User.current_user = Factory(:user, :login => 'test')
      post '/sessions/create', :login => 'test', :password => 'blah'

      get "/#{type_name}/new"
      assert_select "form div#temporary_links", :count => 0

      get "/#{type_name}/#{Factory(type_name.singularize.to_sym, :policy => Factory(:public_policy)).id}/edit"
      assert_select "form div#temporary_links"
    end
  end

  ASSETS_WITH_AUTH_CODES.each do |type_name|
    test "anonymous visitors can use access codes to show or download #{type_name}" do
      item = Factory(type_name.singularize.to_sym, :policy => Factory(:private_policy))
      item.special_auth_codes << Factory(:special_auth_code, :asset => item)

      code = CGI::escape(item.special_auth_codes.first.code)
      get "/#{type_name}/#{item.id}?code=#{code}"
      assert_response :success, "failed for asset #{type_name}"

      if item.is_downloadable?
        get "/#{type_name}/#{item.id}/download?code=#{code}"
        assert_response :success, "failed for asset #{type_name}"
      end
    end
  end

  ASSETS_WITH_AUTH_CODES.each do |type_name|
    test "anonymous visitors can not see or download #{type_name} without code" do
      item = Factory(type_name.singularize.to_sym, :policy => Factory(:private_policy))

      get "/#{type_name}/#{item.id}"
      assert_redirected_to eval "#{type_name}_path"
      assert_not_nil flash[:error]

      if item.is_downloadable?
        get "/#{type_name}/#{item.id}/download"
        assert_redirected_to item
        assert_not_nil flash[:error]
      end
    end
  end

  ASSETS_WITH_AUTH_CODES.each do |type_name|
    test "anonymous visitors can see or download #{type_name} with wrong code" do
      item = Factory(type_name.singularize.to_sym, :policy => Factory(:private_policy))
      item.special_auth_codes << Factory(:special_auth_code, :asset => item)

      random_code = CGI::escape(SecureRandom.base64(30))
      get "/#{type_name}/#{item.id}?code=#{random_code}"
      assert_redirected_to eval "#{type_name}_path"
      assert_not_nil flash[:error]

      if item.is_downloadable?
        get "/#{type_name}/#{item.id}/download?code=#{random_code}"
        assert_redirected_to item
        assert_not_nil flash[:error]
      end
    end
  end

  ASSETS_WITH_AUTH_CODES.each do |type_name|
    test "auth codes allow access to private #{type_name} until they expire" do
      auth_code = Factory :special_auth_code, :expiration_date => (Time.now + 1.days), :asset => Factory(type_name.singularize.to_sym, :policy => Factory(:private_policy))
      item = auth_code.asset

      #assert !item.can_view?
      #assert !item.can_download?

      #test without code instead of can_...? function
      get "/#{type_name}/#{item.id}"
      assert_redirected_to eval "#{type_name}_path"
      assert_not_nil flash[:error]

      if item.is_downloadable?
        get "/#{type_name}/#{item.id}/download"
        assert_redirected_to item
        assert_not_nil flash[:error]
      end


      code = CGI::escape(auth_code.code)
      get "/#{type_name}/#{item.id}?code=#{code}"
      assert_response :success, "failed for asset #{type_name}"

      if item.is_downloadable?
        get "/#{type_name}/#{item.id}/download?code=#{code}"
        assert_response :success, "failed for asset #{type_name}"
      end

      disable_authorization_checks {auth_code.expiration_date = Time.now - 1.days; auth_code.save! }
      item.reload
      get "/#{type_name}/#{item.id}?code=#{code}"
      assert_redirected_to eval "#{type_name}_path"
      assert_not_nil flash[:error]

      if item.is_downloadable?
        get "/#{type_name}/#{item.id}/download?code=#{code}"
        assert_redirected_to item
        assert_not_nil flash[:error]
      end
    end
  end

  test 'should be able to explore excel datafile with auth code' do
    auth_code = Factory :special_auth_code, :expiration_date => (Time.now + 1.days), :asset => Factory(:small_test_spreadsheet_datafile, :policy => Factory(:private_policy))
    item = auth_code.asset
    get "/data_files/#{item.id}/explore"
    assert_redirected_to item
    assert_not_nil flash[:error]

    code = CGI::escape(auth_code.code)
    get "/data_files/#{item.id}/explore?code=#{code}"
    assert_response :success
  end

  test "should be able to view content of sop with auth code" do
    auth_code = Factory :special_auth_code, :expiration_date => (Time.now + 1.days), :asset => Factory(:pdf_sop, :policy => Factory(:private_policy))
    item = auth_code.asset
    get "/sops/#{item.id}/content_blobs/#{item.content_blob.id}/view_pdf_content"
    assert_redirected_to item
    assert_not_nil flash[:error]

    code = CGI::escape(auth_code.code)
    get "/sops/#{item.id}/content_blobs/#{item.content_blob.id}/view_pdf_content?code=#{code}"
    assert_response :success
  end

end
