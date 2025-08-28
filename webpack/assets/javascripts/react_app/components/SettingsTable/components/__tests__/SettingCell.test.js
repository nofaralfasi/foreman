import { testComponentSnapshotsWithFixtures } from 'foremanReact/common/testHelpers';

import {
  rootPass,
  stringSetting,
  withoutFullName,
} from '../../../SettingRecords/__tests__/SettingRecords.fixtures';

import React from 'react';
import { mount } from 'enzyme';
import { Provider } from 'react-redux';
import configureMockStore from 'redux-mock-store';
import { act } from 'react-dom/test-utils';
import SettingValue from '../SettingValue';
import SettingValueCell from '../SettingValueCell';

const fixtures = {
  'render ordinary': { setting: stringSetting },
  'render encrypted with fullName': { setting: rootPass },
  'render without fullName': { setting: withoutFullName },
};

describe('SettingCell', () =>
  testComponentSnapshotsWithFixtures(SettingValue, fixtures));

describe('SettingValueCell encrypted flag updates after save', () => {
  const mockStore = configureMockStore();
  const store = mockStore({});

  it('updates displayed value and encrypted flag from server response', () => {
    const setting = { id: 'http_proxy', name: 'http_proxy', value: '', encrypted: false };
    const wrapper = mount(
      <Provider store={store}>
        <SettingValueCell setting={setting} index={0} />
      </Provider>
    );

    // open edit
    act(() => {
      wrapper.find(`button#${setting.name}`).simulate('click');
    });
    wrapper.update();

    // simulate updateSetting called by SettingValueEdit success
    const updated = { id: 'http_proxy', name: 'http_proxy', value: 'http://user:pass@h:1', encrypted: true };
    act(() => {
      wrapper.find('SettingValueEdit').props().updateSetting(updated);
    });
    wrapper.update();

    // rendered value should be masked
    expect(wrapper.find('.setting-value').first().text()).toBe('*****');
  });

  it('updates displayed value when encryption flag is removed', () => {
    const setting = { id: 'http_proxy', name: 'http_proxy', value: '*****', encrypted: true };
    const wrapper = mount(
      <Provider store={store}>
        <SettingValueCell setting={setting} index={0} />
      </Provider>
    );

    act(() => {
      wrapper.find(`button#${setting.name}`).simulate('click');
    });
    wrapper.update();

    const updated = { id: 'http_proxy', name: 'http_proxy', value: 'http://user@host:8080', encrypted: false };
    act(() => {
      wrapper.find('SettingValueEdit').props().updateSetting(updated);
    });
    wrapper.update();

    expect(wrapper.find('.setting-value').first().text()).toBe('http://user@host:8080');
  });
});
