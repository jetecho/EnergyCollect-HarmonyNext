import { a2dp, access, baseProfile, connection, hfp } from '@kit.ConnectivityKit';
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';
const PERMISSION_BLUETOOTH: Permissions = 'ohos.permission.ACCESS_BLUETOOTH';

/** 已连接的蓝牙音频设备（deviceId 为 MAC 形式） */
export interface BtDeviceInfo {
  deviceId: string;
  name: string;
}

/** 从系统读出的耳机电量摘要；各电量为 -1 表示无数据 */
export interface EarphoneBattery {
  /** 主电量：优先左右耳均值，其次设备总电量，最后充电盒电量（用于会话记录） */
  battery: number;
  /** 左耳电量，不支持时为 -1 */
  leftEar: number;
  /** 右耳电量，不支持时为 -1 */
  rightEar: number;
  /** 充电盒电量，无盒或不支持时为 -1 */
  boxBattery: number;
  /** 充电状态：0 未充电 / 1 充电中 */
  charging: number;
}

/**
 * 蓝牙电量 API 薄封装（@ohos.bluetooth.connection，API 12+）。
 * 系统会对蓝牙耳机上报左耳/右耳/充电盒三路电量与充电状态，
 * 未上报的字段值为 -1，调用方需按 -1 降级处理。
 */
export class BluetoothService {
  /** 是否已被授予蓝牙连接权限（不弹窗） */
  static async hasPermission(): Promise<boolean> {
    try {
      const info: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const state: abilityAccessCtrl.GrantStatus =
        await atManager.checkAccessToken(info.appInfo.accessTokenId, PERMISSION_BLUETOOTH);
      return state === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'hasPermission failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  /** 确保蓝牙权限，未授予时向用户发起请求 */
  static async ensurePermission(context: common.UIAbilityContext): Promise<boolean> {
    if (await BluetoothService.hasPermission()) {
      return true;
    }
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, [PERMISSION_BLUETOOTH]);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'requestPermissionsFromUser failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  static isBluetoothOn(): boolean {
    try {
      return access.getState() === access.BluetoothState.STATE_ON;
    } catch (e) {
      return false;
    }
  }

  /** 枚举当前已连接的蓝牙音频设备（A2DP + HFP 去重） */
  static listConnectedEarphoneDevices(): BtDeviceInfo[] {
    const ids: Set<string> = new Set<string>();
    try {
      const a2dpProfile: a2dp.A2dpSourceProfile = a2dp.createA2dpSrcProfile();
      for (const id of a2dpProfile.getConnectedDevices()) {
        ids.add(id);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'list a2dp connected failed: %{public}s', JSON.stringify(e));
    }
    try {
      const hfpProfile: hfp.HandsFreeAudioGatewayProfile = hfp.createHfpAgProfile();
      for (const id of hfpProfile.getConnectedDevices()) {
        ids.add(id);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'list hfp connected failed: %{public}s', JSON.stringify(e));
    }
    const result: BtDeviceInfo[] = [];
    for (const id of ids) {
      let name: string = id;
      try {
        const remote: string = connection.getRemoteDeviceName(id);
        if (remote.length > 0) {
          name = remote;
        }
      } catch (e) {
      }
      result.push({ deviceId: id, name: name });
    }
    return result;
  }

  /** 读取耳机三路电量与充电状态；蓝牙关闭、设备离线等以 BusinessError 抛出 */
  static async readEarphoneBattery(deviceId: string): Promise<EarphoneBattery> {
    const info: connection.BatteryInfo = await connection.getRemoteDeviceBatteryInfo(deviceId);
    const levels: number[] = [];
    if (info.leftEarBatteryLevel >= 0) {
      levels.push(info.leftEarBatteryLevel);
    }
    if (info.rightEarBatteryLevel >= 0) {
      levels.push(info.rightEarBatteryLevel);
    }
    let battery: number = -1;
    if (levels.length === 2) {
      battery = Math.round((levels[0] + levels[1]) / 2);
    } else if (levels.length === 1) {
      battery = levels[0];
    } else if (info.batteryLevel >= 0) {
      battery = info.batteryLevel;
    } else if (info.boxBatteryLevel >= 0) {
      battery = info.boxBatteryLevel;
    }
    const chargingIn: number = connection.DeviceChargeState.DEVICE_NORMAL_CHARGE_IN_CHARGING;
    const superChargingIn: number = connection.DeviceChargeState.DEVICE_SUPER_CHARGE_IN_CHARGING;
    const charging: boolean = info.boxChargeState === chargingIn || info.boxChargeState === superChargingIn ||
      info.leftEarChargeState === chargingIn || info.leftEarChargeState === superChargingIn ||
      info.rightEarChargeState === chargingIn || info.rightEarChargeState === superChargingIn;
    return {
      battery: battery,
      leftEar: info.leftEarBatteryLevel,
      rightEar: info.rightEarBatteryLevel,
      boxBattery: info.boxBatteryLevel,
      charging: charging ? 1 : 0
    };
  }

  /** 订阅系统蓝牙设备电量变化事件（全局事件，回调不带 deviceId，需自行刷新绑定设备） */
  static subscribeBatteryChange(cb: (info: connection.BatteryInfo) => void): boolean {
    try {
      connection.on('batteryChange', (info: connection.BatteryInfo): void => {
        cb(info);
      });
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribeBatteryChange failed: %{public}s', JSON.stringify(e as BusinessError));
      return false;
    }
  }

  static unsubscribeBatteryChange(): void {
    try {
      connection.off('batteryChange');
    } catch (e) {
    }
  }

  /** 订阅 A2DP+HFP 连接状态变化（事件只作触发器，连接真相以重查已连接列表为准） */
  static subscribeConnectionChange(trigger: (deviceId: string) => void): boolean {
    let ok: boolean = false;
    try {
      const a2dpProfile: a2dp.A2dpSourceProfile = BluetoothService.getA2dpProfile();
      a2dpProfile.on('connectionStateChange', (param: baseProfile.StateChangeParam): void => {
        trigger(param.deviceId);
      });
      ok = true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribe a2dp conn failed: %{public}s', JSON.stringify(e as BusinessError));
    }
    try {
      const hfpProfile: hfp.HandsFreeAudioGatewayProfile = BluetoothService.getHfpProfile();
      hfpProfile.on('connectionStateChange', (param: baseProfile.StateChangeParam): void => {
        trigger(param.deviceId);
      });
      ok = true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribe hfp conn failed: %{public}s', JSON.stringify(e as BusinessError));
    }
    return ok;
  }

  static unsubscribeConnectionChange(): void {
    try {
      BluetoothService.getA2dpProfile().off('connectionStateChange');
    } catch (e) {
    }
    try {
      BluetoothService.getHfpProfile().off('connectionStateChange');
    } catch (e) {
    }
  }

  /** 订阅蓝牙总开关变化（关蓝牙视同全部断开，开蓝牙触发重连对账） */
  static subscribeAdapterStateChange(trigger: () => void): boolean {
    try {
      access.on('stateChange', (_state: access.BluetoothState): void => {
        trigger();
      });
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribe adapter state failed: %{public}s', JSON.stringify(e as BusinessError));
      return false;
    }
  }

  static unsubscribeAdapterStateChange(): void {
    try {
      access.off('stateChange');
    } catch (e) {
    }
  }

  private static getA2dpProfile(): a2dp.A2dpSourceProfile {
    if (BluetoothService.a2dpProfile === null) {
      BluetoothService.a2dpProfile = a2dp.createA2dpSrcProfile();
    }
    return BluetoothService.a2dpProfile;
  }

  private static getHfpProfile(): hfp.HandsFreeAudioGatewayProfile {
    if (BluetoothService.hfpProfile === null) {
      BluetoothService.hfpProfile = hfp.createHfpAgProfile();
    }
    return BluetoothService.hfpProfile;
  }

  private static a2dpProfile: a2dp.A2dpSourceProfile | null = null;
  private static hfpProfile: hfp.HandsFreeAudioGatewayProfile | null = null;

  /** 设备是否处于已连接状态（A2DP ∪ HFP 任一连接即算连接；蓝牙关闭/查询异常视为未连接） */
  static isDeviceConnected(deviceId: string): boolean {
    if (!BluetoothService.isBluetoothOn()) {
      return false;
    }
    try {
      const a2dpIds: Array<string> = BluetoothService.getA2dpProfile().getConnectedDevices();
      if (a2dpIds.indexOf(deviceId) >= 0) {
        return true;
      }
    } catch (e) {
    }
    try {
      const hfpIds: Array<string> = BluetoothService.getHfpProfile().getConnectedDevices();
      if (hfpIds.indexOf(deviceId) >= 0) {
        return true;
      }
    } catch (e) {
    }
    return false;
  }
}
