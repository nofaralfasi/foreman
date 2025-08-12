require 'test_helper'

class Api::V2::SettingsControllerTest < ActionController::TestCase
  describe '#index' do
    def setup
      @org = FactoryBot.create(:organization)
      @loc = FactoryBot.create(:location)
    end

    test "should get all settings through index" do
      Setting['display_fqdn_for_hosts'] = false
      get :index, params: { per_page: 'all' }
      assert_response :success
      settings = ActiveSupport::JSON.decode(@response.body)['results']
      assert_equal Foreman.settings.count, settings.count
      foreman_url = settings.detect { |s| s['name'] == 'foreman_url' }
      assert_equal Setting['foreman_url'], foreman_url['value']
      assert_equal Foreman.settings.find('foreman_url').default, foreman_url['default']
      display_fqdn_for_hosts = settings.detect { |s| s['name'] == 'display_fqdn_for_hosts' }
      assert_equal false, display_fqdn_for_hosts['value']
    end

    test "should get index with organization and location params" do
      get :index, params: { location_id: @loc.id, organization_id: @org.id}
      assert_response :success
      settings = ActiveSupport::JSON.decode(@response.body)['results']
      assert !settings.empty?
    end

    test "should get index with pagination string params" do
      get :index, params: { page: "1", per_page: "5"}
      assert_response :success
      settings = ActiveSupport::JSON.decode(@response.body)['results']
      assert_equal 5, settings.count
    end

    context 'with globals set' do
      setup { SETTINGS.merge!(oauth_active: true) }
      teardown { SETTINGS.delete(:oauth_active) }

      it 'retrieves the global value' do
        get :index, params: { per_page: 'all' }
        assert_response :success
        settings = ActiveSupport::JSON.decode(@response.body)['results']
        oauth_active = settings.detect { |set| set['name'] == 'oauth_active' }
        assert_not_nil oauth_active
        assert true, oauth_active['value']
      end
    end
  end

  describe '#show' do
    test "should show default value" do
      get :show, params: { :id => 'foreman_url' }
      assert_response :success
      show_response = ActiveSupport::JSON.decode(@response.body)
      assert !show_response.empty?
      assert_equal Setting['foreman_url'], show_response['value']
    end

    test "should show set value" do
      Setting['foreman_url'] = value = 'http://cool-foreman.example.net'
      get :show, params: { :id => 'foreman_url' }
      assert_response :success
      show_response = ActiveSupport::JSON.decode(@response.body)
      assert !show_response.empty?
      assert_equal value, show_response['value']
    end

    test "properly show overriden false value" do
      Setting['display_fqdn_for_hosts'] = value = false
      get :show, params: { :id => 'display_fqdn_for_hosts' }
      assert_response :success
      show_response = ActiveSupport::JSON.decode(@response.body)
      assert_equal value, show_response['value']
    end

    test "validate show attributes" do
      get :show, params: { :id => 'foreman_url' }
      assert_response :success
      show_response = ActiveSupport::JSON.decode(@response.body)
      assert_include show_response.keys, 'updated_at'
    end
  end

  test "should not update setting" do
    Setting['foreman_url'] = 'http://cool-foreman.example.net'
    put :update, params: { :id => 'foreman_url', :setting => { } }
    assert_response 422
  end

  test "should parse string values to integers" do
    put :update, params: { :id => 'entries_per_page', :setting => { :value => "100" } }
    assert_response :success
    assert_equal 100, Setting['entries_per_page']
  end

  test "should accept integer values" do
    Setting['entries_per_page'] = 30
    put :update, params: { :id => 'entries_per_page', :setting => { :value => 120 } }
    assert_response :success
    assert_equal 120, Setting['entries_per_page']
  end

  test "should parse string values to ararys" do
    put :update, params: { :id => 'excluded_facts', :setting => { :value => "['baz','foo']" } }
    assert_response :success
    assert_equal ['baz', 'foo'], Setting['excluded_facts']
  end

  test "should accept array values" do
    put :update, params: { :id => 'excluded_facts', :setting => { :value => ['foo', 'bar'] } }
    assert_response :success
    assert_equal ['foo', 'bar'], Setting['excluded_facts']
  end

  test_attributes :pid => 'fb8b0bf1-b475-435a-926b-861aa18d31f1'
  test "should update login page footer text with long value" do
    value = RFauxFactory.gen_alpha 1000
    put :update, params: { :id => 'login_text', :setting => { :value => value } }
    assert_equal JSON.parse(@response.body)['value'], value, "Can't update login_text setting with valid value #{value}"
  end

  test_attributes :pid => '7a56f194-8bde-4dbf-9993-62eb6ab10733'
  test "should update login page footer text with empty value" do
    put :update, params: { :id => 'login_text', :setting => { :value => "" } }
    assert_equal JSON.parse(@response.body)['value'], "", "Can't update login_text setting with empty value"
  end

  test "settings list should show full name column" do
    get :index
    assert_response :success
    response = ActiveSupport::JSON.decode(@response.body)
    assert response["results"][0].key?("full_name")
  end

  test "should update setting as system admin" do
    user = user_one_as_system_admin
    as_user user do
      put :update, params: { :id => 'entries_per_page', :setting => { :value => "100" } }
    end
    assert_response :success
  end

  test "should return validation error for malformed URL in URL type settings" do
    # Test that malformed URLs are properly rejected with error response for any URL type setting
    malformed_url = 'https:/USER:PASS@proxy.example.com'  # Missing slash after https:/
    
    # Test with the known URL type setting
    put :update, params: { :id => 'http_proxy', :setting => { :value => malformed_url } }
    
    assert_response :unprocessable_entity, "URL type setting should reject malformed URL"
    
    response_body = JSON.parse(@response.body)
    
    # Verify the API returns proper validation error for malformed URLs
    assert_includes response_body['error']['message'], 'must be a valid HTTP(S) URL', 
                   "API should return validation error for malformed URL in URL type setting"
  end

  test "should accept valid URL in URL type settings" do
    # Test that valid URLs are accepted for URL type settings
    valid_urls = [
      'https://proxy.example.com:3128',
      'http://proxy.example.com:8080',
      'https://user:pass@proxy.example.com',
      'https://proxy.example.com/path'
    ]
    
    valid_urls.each do |valid_url|
      put :update, params: { :id => 'http_proxy', :setting => { :value => valid_url } }
      
      assert_response :success, "URL type setting should accept valid URL: #{valid_url}"
      
      # Verify the value was set (should be encrypted if it has credentials)
      setting = Setting.find_by_name('http_proxy')
      assert_equal valid_url, setting.value, "URL should be properly stored and retrievable"
    end
  end

  test "validates URL format for all URL type settings dynamically" do
    # This test is designed to work with any settings that have type 'url'
    # It finds URL type settings from the actual setting definitions
    
    malformed_url = 'https:/USER:SECRETPASSWORD@squid-server:3129'  # Missing slash after https:/
    valid_url = 'https://proxy.example.com:8080'
    
    # Get URL type settings from the setting registry
    url_type_settings = []
    Foreman::SettingManager.settings.each do |name, definition|
      if definition[:type] == :url
        url_type_settings << name.to_s
      end
    end
    
    # Fallback to known URL setting if none found in registry
    url_type_settings = ['http_proxy'] if url_type_settings.empty?
    
    url_type_settings.each do |setting_name|
      # Test malformed URL rejection
      put :update, params: { :id => setting_name, :setting => { :value => malformed_url } }
      
      assert_response :unprocessable_entity, "Setting #{setting_name} should reject malformed URL"
      
      response_body = JSON.parse(@response.body)
      assert_includes response_body['error']['message'], 'must be a valid HTTP(S) URL', 
                     "Setting #{setting_name} should return URL validation error"
      
      # Test valid URL acceptance
      put :update, params: { :id => setting_name, :setting => { :value => valid_url } }
      
      assert_response :success, "Setting #{setting_name} should accept valid URL"
      
      # Verify the value was stored correctly
      setting = Setting.find_by_name(setting_name)
      assert_equal valid_url, setting.value, "Setting #{setting_name} should store valid URL correctly"
    end
  end

  test "should view setting as system admin" do
    user = user_one_as_system_admin
    setting = Setting.first
    as_user user do
      get :show, params: { :id => setting.to_param }
    end
    assert_response :success
  end

  private

  def user_one_as_system_admin
    user = users(:one)
    user.roles = [Role.default, Role.find_by_name('System admin')]
    user
  end
end
