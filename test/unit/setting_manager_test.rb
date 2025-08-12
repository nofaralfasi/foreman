require 'test_helper'

class SettingManagerTest < ActiveSupport::TestCase
  let(:setting_memo) { {} }
  let(:category_memo) { { 'general' => N_('General') } }

  setup do
    Foreman::SettingManager.stubs(settings: setting_memo, categories: category_memo)
  end

  it 'adds setting to category general by default' do
    Foreman::SettingManager.define(:test_context) do
      category(:general) do
        setting(:foo,
          type: :string,
          default: 'bar',
          description: 'This is nicely described foo setting',
          full_name: 'Foo setting')
      end
    end
    assert_not_nil setting_memo['foo']
    assert_equal setting_memo['foo'][:category], 'general'
  end

  it 'adds setting to defined category within block and sets it\'s label' do
    Foreman::SettingManager.define(:test_context) do
      category(:my_category, 'Awesome Category') do
        setting(:foo,
          type: :string,
          default: 'bar',
          description: 'This is nicely described foo setting',
          full_name: 'Foo setting')
      end
    end
    assert_not_nil setting_memo['foo']
    assert_equal setting_memo['foo'][:category], 'my_category'
    assert_equal category_memo['my_category'], 'Awesome Category'
  end

  it 'doesnt allow setting redefinition' do
    assert_raise ::Foreman::Exception, "Setting 'foo' is already defined, please avoid collisions" do
      Foreman::SettingManager.define(:test_context) do
        category(:my_category, 'Awesome Category') do
          setting(:foo,
            type: :string,
            default: 'bar',
            description: 'This is nicely described foo setting',
            full_name: 'Foo setting')
        end
        category(:general) do
          setting(:foo,
            type: :string,
            default: 'bar',
            description: 'This is nicely described foo setting',
            full_name: 'Foo setting')
        end
      end
    end
  end

  it 'doesnt allow setting with invalid type' do
    # no type not allowed
    assert_raise ArgumentError, "missing keyword: :type" do
      Foreman::SettingManager.define(:test_context) do
        category(:my_category, 'Awesome Category') do
          setting(:foo,
            default: 'bar',
            description: 'This is nicely described foo setting',
            full_name: 'Foo setting')
        end
      end
    end
    # invalid type not allowed
    assert_raise ::Foreman::Exception, "Setting 'foo' has invalid type definition. Please use valid type." do
      Foreman::SettingManager.define(:test_context) do
        category(:general) do
          setting(:foo,
            type: :custom_type,
            default: 'bar',
            description: 'This is nicely described foo setting',
            full_name: 'Foo setting')
        end
      end
    end
  end

  it 'allows URL type settings' do
    Foreman::SettingManager.define(:test_context) do
      category(:general) do
        setting(:test_url_setting,
          type: :url,
          default: 'https://example.com',
          description: 'This is a URL setting',
          full_name: 'Test URL Setting')
      end
    end
    assert_not_nil setting_memo['test_url_setting']
    assert_equal :url, setting_memo['test_url_setting'][:type]
  end

  it 'includes URL in available types' do
    available_types = Foreman::SettingManager.available_types
    assert_includes available_types, :url
  end

  describe 'Validations' do
    setup do
      @validation_backup = Setting._validators[:value].dup
    end

    teardown do
      Setting._validators[:value] = @validation_backup
    end

    it 'defines validation on Setting model for given setting name' do
      Foreman::SettingManager.define(:test_context) do
        category(:general) do
          setting(:validfoo,
            type: :string,
            default: 'bar@example.com',
            description: 'This is nicely described foo setting',
            full_name: 'Foo setting',
            validate: :email)
        end
      end
      Foreman::SettingManager.validations.setup!
      Foreman.settings.load_definitions
      setting = Setting.new(name: 'validfoo', value: 'notanemail')
      assert_not setting.valid?
    end

    it 'defines validation through validates' do
      Foreman::SettingManager.define(:test_context) do
        category(:general) do
          setting(:validfoo,
            type: :string,
            default: 'bar@example.com',
            description: 'This is nicely described foo setting',
            full_name: 'Foo setting')
          validates(:validfoo, { email: true })
        end
      end
      Foreman::SettingManager.validations.setup!
      Foreman.settings.load_definitions
      setting = Setting.new(name: 'validfoo', value: 'notanemail')
      assert_not setting.valid?
    end

    it 'defines validation through RegExp' do
      Foreman::SettingManager.define(:test_context) do
        category(:general) do
          setting(:validfoo2,
            type: :string,
            default: 'bar@include.com',
            description: 'This is nicely described foo setting',
            full_name: 'Foo setting',
            validate: /.*@include.com/)
        end
      end
      Foreman::SettingManager.validations.setup!
      Foreman.settings.load_definitions
      setting = Setting.new(name: 'validfoo2', value: 'bar@notvalid.com')
      assert_not setting.valid?
    end

    it 'defines validation through Proc' do
      Foreman::SettingManager.define(:test_context) do
        category(:general) do
          setting(:validfoo3,
            type: :string,
            default: 'bar@example.com',
            description: 'This is nicely described foo setting',
            full_name: 'Foo setting',
            validate: ->(value) { !value.nil? && value.starts_with?('bar') })
        end
      end
      Foreman::SettingManager.validations.setup!
      Foreman.settings.load_definitions
      setting = Setting.new(name: 'validfoo3', value: 'notvalid@example.com')
      assert_not setting.valid?
    end
  end
end
