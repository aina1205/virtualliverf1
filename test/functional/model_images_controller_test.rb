require 'test_helper'

class ModelImagesControllerTest < ActionController::TestCase
  fixtures :models, :users

  include AuthenticatedTestHelper

  test "get model image" do
    model = Factory(:model_with_image,:policy=>Factory(:public_policy))
    get :show,:model_id=>model.id,:id=>model.model_image.id
    assert_response :success
    assert_equal "image/jpeg",@response.header["Content-Type"]
    assert_equal "inline; filename=\"#{model.model_image.id}.jpg\"",@response.header["Content-Disposition"]
    assert_equal "5821",@response.header["Content-Length"]
  end

  test "get model image with size" do
    model = Factory(:model_with_image,:policy=>Factory(:public_policy))
    get :show,:model_id=>model.id,:id=>model.model_image.id, :size=>"10x10"
    assert_response :success
    assert_equal "image/jpeg",@response.header["Content-Type"]
    assert_equal "inline; filename=\"#{model.model_image.id}.jpg\"",@response.header["Content-Disposition"]
    assert_equal "393",@response.header["Content-Length"]
  end

  test "model_image is authorised by model" do
    model = Factory(:model_with_image,:policy=>Factory(:private_policy))
    get :show,:model_id=>model.id,:id=>model.model_image.id
    assert_redirected_to root_path
    assert_not_nil flash[:error]
    assert_equal "You can only view images for models you can access",flash[:error]
  end

end
