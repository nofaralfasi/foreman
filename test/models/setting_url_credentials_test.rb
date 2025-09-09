require 'test_helper'

class SettingUrlCredentialsTest < ActiveSupport::TestCase
  setup do
    Setting.any_instance.stubs(:encryption_key).returns('25d224dd383e92a7e0c82b8bf7c985e815f34cf5')
  end

  describe 'URL credential handling scenarios' do
    test "valid URL with credentials on port 3129 is applied and masked" do
      url = 'https://USER:SECRETPASSWORD@squid-server:3129'
      setting = Setting.new(name: 'test_proxy_3129', value: url)
      setting.stubs(:settings_type).returns('url')
      setting.stubs(:setting_definition).returns(nil)
      setting.stubs(:default).returns(nil)
      
      # Value should be applied successfully
      assert setting.save!, "Expected URL with credentials to save successfully"
      
      # Should be detected as encrypted
      assert setting.encrypted?, "Expected URL with credentials to be considered encrypted"
      
      # Should be encrypted in database
      assert setting.is_decryptable?(setting.read_attribute(:value)), "Expected URL to be encrypted in database"
      
      # Should return original value when accessed
      assert_equal url, setting.value, "Expected decrypted value to match original"
      
      # Presenter should show masked value
      presenter = SettingPresenter.new(setting.attributes.merge(encrypted: setting.encrypted?))
      assert_equal '*****', presenter.safe_value, "Expected presenter to show masked value"
      
      # Audit should be redacted
      audit = setting.audits.last
      if audit&.audited_changes&.dig('value')
        refute_includes audit.audited_changes['value'].to_s, 'SECRETPASSWORD', 
                       'Expected password to be redacted from audit'
        assert_includes audit.audited_changes['value'].to_s, '[redacted]', 
                       'Expected audit to contain redaction marker'
      end
    end

    test "valid URL with credentials on port 3128 is applied and masked" do
      url = 'https://USER:SECRETPASSWORD@squid-server:3128'
      setting = Setting.new(name: 'test_proxy_3128', value: url)
      setting.stubs(:settings_type).returns('url')
      setting.stubs(:setting_definition).returns(nil)
      setting.stubs(:default).returns(nil)
      
      # Value should be applied successfully
      assert setting.save!, "Expected URL with credentials to save successfully"
      
      # Should be detected as encrypted
      assert setting.encrypted?, "Expected URL with credentials to be considered encrypted"
      
      # Should be encrypted in database
      assert setting.is_decryptable?(setting.read_attribute(:value)), "Expected URL to be encrypted in database"
      
      # Should return original value when accessed
      assert_equal url, setting.value, "Expected decrypted value to match original"
      
      # Presenter should show masked value
      presenter = SettingPresenter.new(setting.attributes.merge(encrypted: setting.encrypted?))
      assert_equal '*****', presenter.safe_value, "Expected presenter to show masked value"
      
      # Audit should be redacted
      audit = setting.audits.last
      if audit&.audited_changes&.dig('value')
        refute_includes audit.audited_changes['value'].to_s, 'SECRETPASSWORD', 
                       'Expected password to be redacted from audit'
        assert_includes audit.audited_changes['value'].to_s, '[redacted]', 
                       'Expected audit to contain redaction marker'
      end
    end

    test "invalid URL format is rejected" do
      malformed_url = 'https:/USER:SECRETPASSWORD@squid-server:3129'
      setting = Setting.new(name: 'test_malformed_proxy', value: malformed_url)
      setting.stubs(:settings_type).returns('url')
      setting.stubs(:setting_definition).returns(nil)
      setting.stubs(:default).returns(nil)
      
      # Value should be rejected
      refute setting.valid?, "Expected malformed URL to be rejected"
      assert setting.errors[:value].any?, "Expected validation errors for malformed URL"
      assert setting.errors.full_messages.any? { |msg| msg.include?('valid') },
             "Expected validation error message about valid URL"
    end

    test "malformed URLs with credentials are masked in audit logs" do
      # This test specifically focuses on audit log masking behavior
      malformed_url = 'https:/USER:SECRETPASSWORD@squid-server:3129'
      
      # Create an audit entry that simulates a malformed URL with credentials
      audit = Audit.new(
        auditable_type: 'Setting',
        auditable_id: 1,
        action: 'update',
        audited_changes: { 'value' => ['old_value', malformed_url] }
      )
      
      # The filter_encrypted callback should redact even malformed URLs with credentials
      audit.send(:filter_encrypted)
      
      assert_equal "[redacted]", audit.audited_changes['value'][1],
                   "Expected malformed URL with credentials to be redacted in audit"
      refute_includes audit.audited_changes['value'].to_s, 'SECRETPASSWORD',
                     'Expected password to be redacted from audit even in malformed URL'
    end

    test "valid URL without credentials is applied and shown in logs and templates" do
      url = 'https://USERSECRETPASSWORD@squid-server:3129'  # No colon, so no password
      setting = Setting.new(name: 'test_proxy_no_creds', value: url)
      setting.stubs(:settings_type).returns('url')
      setting.stubs(:setting_definition).returns(nil)
      setting.stubs(:default).returns(nil)
      
      # Value should be applied successfully
      assert setting.save!, "Expected URL without credentials to save successfully"
      
      # Should NOT be detected as encrypted
      refute setting.encrypted?, "Expected URL without credentials not to be considered encrypted"
      
      # Should NOT be encrypted in database
      refute setting.is_decryptable?(setting.read_attribute(:value)), 
             "Expected URL without credentials not to be encrypted in database"
      
      # Should return original value when accessed
      assert_equal url, setting.value, "Expected value to match original"
      
      # Presenter should show actual value
      presenter = SettingPresenter.new(setting.attributes.merge(encrypted: setting.encrypted?))
      assert_equal url, presenter.safe_value, "Expected presenter to show actual value"
      
      # Audit should NOT be redacted
      audit = setting.audits.last
      if audit&.audited_changes&.dig('value')
        assert_includes audit.audited_changes['value'].to_s, url,
                       'Expected URL without credentials to appear in audit'
        refute_includes audit.audited_changes['value'].to_s, '[redacted]',
                       'Expected audit not to contain redaction marker'
      end
    end

    test "regression check: other URL settings remain unaffected" do
      # Test various URL formats that should work normally
      test_urls = [
        'https://example.com',
        'http://proxy.example.com:8080',
        'https://cdn.example.com/path/to/resource',
        'http://localhost:3000',
        'https://api.example.com/v1/endpoint?param=value'
      ]
      
      test_urls.each_with_index do |url, index|
        setting = Setting.new(name: "test_regression_#{index}", value: url)
        setting.stubs(:settings_type).returns('url')
        setting.stubs(:setting_definition).returns(nil)
        setting.stubs(:default).returns(nil)
        
        # Should save successfully
        assert setting.save!, "Expected normal URL #{url} to save successfully"
        
        # Should NOT be encrypted
        refute setting.encrypted?, "Expected normal URL #{url} not to be considered encrypted"
        
        # Should return original value
        assert_equal url, setting.value, "Expected normal URL #{url} to remain unchanged"
        
        # Presenter should show actual value
        presenter = SettingPresenter.new(setting.attributes.merge(encrypted: setting.encrypted?))
        assert_equal url, presenter.safe_value, "Expected normal URL #{url} to be shown in presenter"
      end
    end

    test "template rendering masks credentials but shows normal URLs" do
      # Set up allowed settings for template rendering
      original_allowed = Foreman::Renderer.config.allowed_global_settings.dup
      Foreman::Renderer.config.allowed_global_settings += [:test_url_with_creds, :test_url_no_creds]
      
      begin
        # URL with credentials - should be masked
        setting_with_creds = mock('setting_with_creds')
        setting_with_creds.stubs(:encrypted?).returns(true)
        setting_with_creds.stubs(:hidden_value).returns('*****')
        setting_with_creds.stubs(:settings_type).returns('url')
        setting_with_creds.stubs(:value).returns('https://USER:SECRETPASSWORD@squid-server:3129')
        
        # URL without credentials - should show actual value
        setting_no_creds = mock('setting_no_creds')
        setting_no_creds.stubs(:encrypted?).returns(false)
        setting_no_creds.stubs(:settings_type).returns('url')
        setting_no_creds.stubs(:value).returns('https://squid-server:3129')
        
        # Mock the scope for template rendering
        host = FactoryBot.build_stubbed(:host)
        template = OpenStruct.new(name: 'Test', template: 'Test')
        source = Foreman::Renderer::Source::Database.new(template)
        scope = Class.new(Foreman::Renderer::Scope::Base) do
          include Foreman::Renderer::Scope::Macros::Base
        end.send(:new, host: host, source: source)
        
        # Test masked setting
        Foreman.settings.expects(:find).with('test_url_with_creds').returns(setting_with_creds)
        result = scope.global_setting('test_url_with_creds')
        assert_equal '*****', result, "Expected template to show masked value for URL with credentials"
        
        # Test non-masked setting
        Foreman.settings.expects(:find).with('test_url_no_creds').returns(setting_no_creds)
        result = scope.global_setting('test_url_no_creds')
        assert_equal 'https://squid-server:3129', result, "Expected template to show actual value for URL without credentials"
        
      ensure
        Foreman::Renderer.config.allowed_global_settings = original_allowed
      end
    end

    test "Setting.url_has_credentials? correctly identifies test scenarios" do
      # Test case 1: Valid URL with credentials (port 3129)
      assert Setting.url_has_credentials?('https://USER:SECRETPASSWORD@squid-server:3129'),
             "Expected URL with credentials on port 3129 to be detected"
      
      # Test case 2: Valid URL with credentials (port 3128) 
      assert Setting.url_has_credentials?('https://USER:SECRETPASSWORD@squid-server:3128'),
             "Expected URL with credentials on port 3128 to be detected"
      
      # Test case 3: Invalid URL format (should still detect credentials pattern)
      assert Setting.url_has_credentials?('https:/USER:SECRETPASSWORD@squid-server:3129'),
             "Expected malformed URL with credentials pattern to be detected"
      
      # Test case 4: Valid URL without credentials (user only, no password)
      refute Setting.url_has_credentials?('https://USERSECRETPASSWORD@squid-server:3129'),
             "Expected URL without credentials (no colon) not to be detected"
      
      # Additional regression cases
      refute Setting.url_has_credentials?('https://squid-server:3129'),
             "Expected URL without userinfo not to be detected"
      refute Setting.url_has_credentials?('https://example.com'),
             "Expected simple URL not to be detected"
    end
  end
end
