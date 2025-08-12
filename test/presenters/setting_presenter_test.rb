require 'test_helper'

class SettingPresenterTest < ActiveSupport::TestCase
  let(:encrypted) { false }
  let(:extra_attrs) { {} }
  let(:base_attributes) do
    {
      name: 'test_setting',
      context: :test,
      category: 'Test',
      default: nil,
      full_name: 'Test Setting',
      description: 'Test setting',
      value: nil,
      encrypted: encrypted
    }
  end
  let(:presenter) { SettingPresenter.new(base_attributes.merge(extra_attrs)) }

  describe '#safe_value' do
    context 'when explicitly encrypted' do
      let(:encrypted) { true }
      
      it 'should hide value if encrypted' do
        assert_equal '*****', presenter.safe_value
      end
    end

    context 'when URL with credentials (auto-detected as encrypted)' do
      let(:encrypted) { false }
      let(:extra_attrs) do
        {
          settings_type: 'url',
          value: 'https://user:password@proxy.example.com:8080'
        }
      end

      it 'should hide value for URLs with credentials' do
        Setting.expects(:url_has_credentials?).with('https://user:password@proxy.example.com:8080').returns(true)
        assert_equal '*****', presenter.safe_value
      end
    end

    context 'when URL without credentials' do
      let(:encrypted) { false }
      let(:extra_attrs) do
        {
          settings_type: 'url',
          value: 'https://proxy.example.com:8080'
        }
      end

      it 'should show actual value for URLs without credentials' do
        Setting.expects(:url_has_credentials?).with('https://proxy.example.com:8080').returns(false)
        assert_equal 'https://proxy.example.com:8080', presenter.safe_value
      end
    end
  end

  describe '#encrypted?' do
    context 'when explicitly marked as encrypted' do
      let(:encrypted) { true }
      let(:extra_attrs) { {} }
      
      it 'returns true' do
        assert presenter.encrypted?
      end
    end

    context 'when URL type with credentials' do
      let(:encrypted) { false }
      let(:extra_attrs) do
        {
          settings_type: 'url',
          value: 'https://user:password@proxy.example.com:8080'
        }
      end

      it 'auto-detects encryption for URLs with credentials' do
        Setting.expects(:url_has_credentials?).with('https://user:password@proxy.example.com:8080').returns(true)
        assert presenter.encrypted?
      end
    end

    context 'when URL type but no credentials' do
      let(:encrypted) { false }
      let(:extra_attrs) do
        {
          settings_type: 'url',
          value: 'https://proxy.example.com:8080'
        }
      end

      it 'does not consider it encrypted when no credentials' do
        Setting.expects(:url_has_credentials?).with('https://proxy.example.com:8080').returns(false)
        refute presenter.encrypted?
      end
    end

    context 'when non-URL type' do
      let(:encrypted) { false }
      let(:extra_attrs) { { settings_type: 'string', value: 'abc' } }
      
      it 'returns false for non-URL types' do
        refute presenter.encrypted?
      end
    end

    context 'when value is nil' do
      let(:encrypted) { false }
      let(:extra_attrs) { { settings_type: 'url', value: nil } }
      
      it 'returns false without error' do
        refute presenter.encrypted?
      end
    end
  end

  describe '#settings_type' do
    context 'when settings_type is explicitly set' do
      let(:encrypted) { false }
      let(:extra_attrs) { { settings_type: 'url' } }

      it 'returns the settings_type attribute value' do
        assert_equal 'url', presenter.settings_type
      end
    end

    context 'when settings_type is not set' do
      let(:encrypted) { false }
      let(:extra_attrs) { { default: 2 } }

      it 'falls back to Setting.setting_type_from_value' do
        Setting.expects(:setting_type_from_value).with(2).returns('integer')
        assert_equal 'integer', presenter.settings_type
      end
    end
  end

  describe '#value' do
    context 'mass assigned nil value' do
      let(:encrypted) { false }
      let(:extra_attrs) { { default: 2 } }

      it 'returns default' do
        assert_equal 2, presenter.value
      end
    end

    context 'mass assigned non-nil value' do
      let(:encrypted) { false }
      let(:extra_attrs) { { value: 30 } }

      it 'returns value' do
        assert_equal 30, presenter.value
      end
    end

    context 'set explicit nil value' do
      let(:encrypted) { false }
      let(:extra_attrs) { {} }

      it 'returns explicitly set nil value' do
        presenter.value = nil
        assert_equal nil, presenter.value
      end
    end

    context 'with global truth defined in SETTINGS' do
      let(:encrypted) { false }
      let(:extra_attrs) { { name: 'test_global_setting' } }

      setup { SETTINGS.merge!(test_global_setting: 42) }
      teardown { SETTINGS.delete(:test_global_setting) }

      it 'returns the global' do
        assert_equal 42, presenter.value
      end
    end
  end
end
