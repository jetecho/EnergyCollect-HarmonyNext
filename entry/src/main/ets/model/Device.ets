export class Device {
  id: number = 0;
  name: string = '';
  icon: string = 'other';
  sortOrder: number = 0;
  archived: boolean = false;
  createdAt: number = 0;
  batteryCapacity: number = 0;
  rangeRated: number = 0;
  statMode: string = '';
  /** 绑定的蓝牙设备 ID（MAC 形式），空串表示未绑定 */
  btDeviceId: string = '';
  /** 绑定蓝牙设备的名称（仅展示用） */
  btName: string = '';
  /** 最近同步的耳机电量（左右耳均值口径），-1 表示无数据 */
  btBattery: number = -1;
  /** 最近同步的左耳电量，-1 表示不支持或无数据 */
  btLeftBattery: number = -1;
  /** 最近同步的右耳电量，-1 表示不支持或无数据 */
  btRightBattery: number = -1;
  /** 最近同步的充电盒电量，-1 表示无盒或不支持 */
  btBoxBattery: number = -1;
  /** 最近同步的充电状态：0 未充电 / 1 充电中 / -1 未知 */
  btCharging: number = -1;
  /** 最近同步时间戳，0 表示从未同步 */
  btSyncAt: number = 0;
  /** 最近一次已知的连接状态：1 已连接 / 0 断开（跨进程持久化，用于边沿判定与启动对账） */
  btConnState: number = 0;
}

export const DEVICE_ICON_KEYS: string[] = ['ev', 'nev', 'powerbank', 'phone', 'laptop', 'other'];

export function isNev(icon: string): boolean {
  return icon === 'nev';
}

export function iconToResource(icon: string): Resource {
  switch (icon) {
    case 'ev':
      return $r('app.media.ic_device_ev');
    case 'nev':
      return $r('app.media.ic_device_nev');
    case 'powerbank':
      return $r('app.media.ic_device_powerbank');
    case 'phone':
      return $r('app.media.ic_device_phone');
    case 'earphone':
      return $r('app.media.ic_device_earphone');
    case 'laptop':
      return $r('app.media.ic_device_laptop');
    case 'other':
      return $r('app.media.ic_device_other');
    default:
      return $r('app.media.ic_device_other');
  }
}

export function iconToNameRes(icon: string): Resource {
  switch (icon) {
    case 'ev':
      return $r('app.string.device_type_ev');
    case 'nev':
      return $r('app.string.device_type_nev');
    case 'powerbank':
      return $r('app.string.device_type_powerbank');
    case 'phone':
      return $r('app.string.device_type_phone');
    case 'earphone':
      return $r('app.string.device_type_earphone');
    case 'laptop':
      return $r('app.string.device_type_laptop');
    case 'other':
      return $r('app.string.device_type_other');
    default:
      return $r('app.string.device_type_other');
  }
}

/** 续航标准统计方式 -> 资源名（CLTC/WLTC），未知回退 CLTC。 */
export function statModeLabelRes(mode: string): Resource {
  if (mode === 'WLTC') {
    return $r('app.string.stat_mode_wltc');
  }
  return $r('app.string.stat_mode_cltc');
}
