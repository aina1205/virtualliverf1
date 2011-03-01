require 'test_helper'

class ApplicationConfigurationTest < ActiveSupport::TestCase

  test "default page" do
    assert_equal "latest",Seek::ApplicationConfiguration.get_default_page("sops")
    assert_equal "latest",Seek::ApplicationConfiguration.get_default_page(:sops)
  end

end