import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const PREF_NAME: string = 'energy_collect_pref';
const KEY_COLOR_MODE: string = 'color_mode';
const KEY_DEFAULT_DEVICE_ID: string = 'default_device_id';
const DEFAULT_MODE: number = -1;
const DEFAULT_DEVICE: number = -1;
const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';

export class PreferencesUtil {
  private static store: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    if (PreferencesUtil.store === null) {
      try {
        PreferencesUtil.store = await preferences.getPreferences(context, PREF_NAME);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'preferences init failed: %{public}s', JSON.stringify(e));
      }
    }
  }

  static async getColorMode(): Promise<number> {
    if (PreferencesUtil.store === null) {
      return DEFAULT_MODE;
    }
    try {
      const v: preferences.ValueType = await PreferencesUtil.store.get(KEY_COLOR_MODE, DEFAULT_MODE);
      if (typeof v === 'number') {
        return v;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'preferences get colorMode failed: %{public}s', JSON.stringify(e));
    }
    return DEFAULT_MODE;
  }

  static async setColorMode(mode: number): Promise<void> {
    if (PreferencesUtil.store === null) {
      return;
    }
    try {
      await PreferencesUtil.store.put(KEY_COLOR_MODE, mode);
      await PreferencesUtil.store.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'preferences set colorMode failed: %{public}s', JSON.stringify(e));
    }
  }

  static async getDefaultDeviceId(): Promise<number> {
    if (PreferencesUtil.store === null) {
      return DEFAULT_DEVICE;
    }
    try {
      const v: preferences.ValueType = await PreferencesUtil.store.get(KEY_DEFAULT_DEVICE_ID, DEFAULT_DEVICE);
      if (typeof v === 'number') {
        return v;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'preferences get defaultDeviceId failed: %{public}s', JSON.stringify(e));
    }
    return DEFAULT_DEVICE;
  }

  static async setDefaultDeviceId(id: number): Promise<void> {
    if (PreferencesUtil.store === null) {
      return;
    }
    try {
      await PreferencesUtil.store.put(KEY_DEFAULT_DEVICE_ID, id);
      await PreferencesUtil.store.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'preferences set defaultDeviceId failed: %{public}s', JSON.stringify(e));
    }
  }
}
