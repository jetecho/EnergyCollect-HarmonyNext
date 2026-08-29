import { connection } from '@kit.ConnectivityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Device } from '../model/Device';
import { Session } from '../model/Session';
import { SessionType } from '../model/SessionType';
import { DeviceRepository } from '../data/repository/DeviceRepository';
import { SessionRepository } from '../data/repository/SessionRepository';
import { DataNotifier } from '../data/DataNotifier';
import { BluetoothService, EarphoneBattery } from './BluetoothService';

const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';

/** 断开宽限期：瞬态断连（电梯/超距/开关蓝牙）不立即结束使用会话 */
const DISCONNECT_GRACE_MS: number = 2 * 60 * 1000;

export const SOURCE_MANUAL: string = 'manual';
export const SOURCE_AUTO_BT: string = 'auto_bt';
export const SOURCE_AUTO_CHARGE: string = 'auto_charge';

interface PendingEnd {
  timerId: number;
}

/**
 * 蓝牙耳机自动会话引擎（对账式设计）：
 *
 * - 事件只是触发器（连接变化/电量变化/蓝牙开关），真相以重查 A2DP∪HFP 已连接列表为准；
 * - 会话由"断开→连接"的边沿驱动，启动基线对账不产生边沿（重启不误开）；
 * - 断开走 2 分钟宽限期，宽限期内重连则同一会话延续；
 * - 充电与使用互斥：充电开始即结束使用会话（D3），充电结束时若耳机仍连接
 *   且无会话则自动开使用会话（D4）；
 * - 所有开始/结束动作前先查活跃会话，幂等闸门防"二次开始/二次结束"。
 */
export class EarphoneSyncManager {
  private static instance: EarphoneSyncManager | null = null;

  static getInstance(): EarphoneSyncManager {
    if (EarphoneSyncManager.instance === null) {
      EarphoneSyncManager.instance = new EarphoneSyncManager();
    }
    return EarphoneSyncManager.instance;
  }

  private listening: boolean = false;
  private reconciling: boolean = false;
  private pendingReconcile: boolean = false;
  /** 断开宽限期定时器：deviceId -> timerId。进程死亡即失效，重启对账兜底 */
  private pendingEnds: Map<string, PendingEnd> = new Map<string, PendingEnd>();
  private deviceRepo: DeviceRepository = new DeviceRepository();
  private sessionRepo: SessionRepository = new SessionRepository();

  private constructor() {
  }

  /**
   * 幂等启动：订阅三类蓝牙事件并做启动基线对账。
   * 基线对账只落连接状态、只收尾孤儿会话，不因"启动时已连接"开新会话。
   */
  async start(): Promise<void> {
    if (this.listening) {
      return;
    }
    if (!await BluetoothService.hasPermission()) {
      return;
    }
    const trigger = (): void => {
      this.reconcile(true, false);
    };
    const btOk: boolean = BluetoothService.subscribeBatteryChange((_info: connection.BatteryInfo): void => {
      trigger();
    });
    const connOk: boolean = BluetoothService.subscribeConnectionChange((_deviceId: string): void => {
      trigger();
    });
    const adpOk: boolean = BluetoothService.subscribeAdapterStateChange((): void => {
      trigger();
    });
    this.listening = true;
    hilog.info(DOMAIN, TAG, 'EarphoneSyncManager started: bat=%{public}s conn=%{public}s adapter=%{public}s',
      btOk ? 'Y' : 'N', connOk ? 'Y' : 'N', adpOk ? 'Y' : 'N');
    await this.reconcile(false, true);
  }

  stop(): void {
    if (!this.listening) {
      return;
    }
    BluetoothService.unsubscribeBatteryChange();
    BluetoothService.unsubscribeConnectionChange();
    BluetoothService.unsubscribeAdapterStateChange();
    this.listening = false;
  }

  /** 回前台入口：未启动则基线启动；已启动则补一次允许边沿的立即结算对账 */
  async reconcileOnForeground(): Promise<void> {
    if (!this.listening) {
      await this.start();
      return;
    }
    await this.reconcile(true, true);
  }

  /**
   * 对账：对每个绑定设备，用真实连接集合与持久化状态求差异并应用最小转换。
   * allowConnectEdges=false 仅用于启动基线（启动时已连接 ≠ 刚刚连接）。
   * immediateDisconnect=true 用于回前台/冷启动对账：发现断开时立即结算
   * （断开发生在后台冻结期间，时刻不可考，不再补 2 分钟宽限）。
   * 实时事件触发的对账走宽限期，防瞬态断连切碎会话。
   */
  private async reconcile(allowConnectEdges: boolean, immediateDisconnect: boolean): Promise<void> {
    if (this.reconciling) {
      this.pendingReconcile = true;
      return;
    }
    this.reconciling = true;
    try {
      const all: Device[] = await this.deviceRepo.listAll(true);
      const bound: Device[] = all.filter((d: Device): boolean => d.btDeviceId.length > 0);
      let changed: boolean = false;
      for (const d of bound) {
        if (await this.reconcileDevice(d, allowConnectEdges, immediateDisconnect)) {
          changed = true;
        }
      }
      if (changed) {
        DataNotifier.notifyHome();
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'reconcile failed: %{public}s', JSON.stringify(e));
    } finally {
      this.reconciling = false;
      if (this.pendingReconcile) {
        this.pendingReconcile = false;
        this.reconcile(true, false);
      }
    }
  }

  /** 返回该设备状态是否发生变化 */
  private async reconcileDevice(d: Device, allowConnectEdges: boolean, immediateDisconnect: boolean): Promise<boolean> {
    let changed: boolean = false;
    const actual: boolean = BluetoothService.isDeviceConnected(d.btDeviceId);

    // ---- 电量刷新 + 充电状态转换 ----
    let info: EarphoneBattery | null = null;
    try {
      info = await BluetoothService.readEarphoneBattery(d.btDeviceId);
    } catch (e) {
      // 断开/蓝牙关闭时读不到电量，保持旧值，连接边照常处理
    }
    if (info !== null && info.battery >= 0) {
      hilog.info(DOMAIN, TAG, 'bt read %{public}s: L=%{public}d R=%{public}d box=%{public}d chg=%{public}d conn=%{public}s(persist %{public}d)',
        d.name, info.leftEar, info.rightEar, info.boxBattery, info.charging,
        actual ? 'Y' : 'N', d.btConnState);
      if (d.btBattery !== info.battery || d.btLeftBattery !== info.leftEar || d.btRightBattery !== info.rightEar ||
        d.btBoxBattery !== info.boxBattery || d.btCharging !== info.charging) {
        await this.deviceRepo.updateBtState(d.id, info.battery, info.leftEar, info.rightEar, info.boxBattery, info.charging);
        changed = true;
        await this.applyChargeTransition(d, info, actual);
      }
    }

    // ---- 连接边沿（边沿触发，非电平触发） ----
    if (actual && d.btConnState === 0) {
      // 连接边沿
      await this.deviceRepo.updateBtConnState(d.id, true);
      d.btConnState = 1;
      this.cancelPendingEnd(d.btDeviceId);
      changed = true;
      if (allowConnectEdges) {
        await this.autoStartUsage(d);
      } else {
        hilog.info(DOMAIN, TAG, 'baseline: %{public}s already connected at launch, no session', d.name);
      }
    } else if (actual && d.btConnState === 1) {
      // 连接保持：若宽限期挂起（如开关蓝牙瞬断）则撤销
      this.cancelPendingEnd(d.btDeviceId);
    } else if (!actual && d.btConnState === 1) {
      // 断开边沿
      const active: Session | null = await this.sessionRepo.getActiveSession(d.id);
      if (active !== null && active.type === SessionType.USAGE) {
        if (immediateDisconnect) {
          // 后台冻结期间发生的断开，时刻不可考：立即结算，结束时间=发现时刻
          await this.finishUsageNow(d);
          changed = true;
        } else if (!this.pendingEnds.has(d.btDeviceId)) {
          // 实时断开：进入宽限期。已有挂起定时器时不重置（否则任何蓝牙事件都会无限顺延结算）
          this.scheduleGraceEnd(d);
          hilog.info(DOMAIN, TAG, 'disconnect: grace period started for %{public}s', d.name);
        }
      } else {
        // 无使用会话（无会话/充电中）：直接落"已断开"
        await this.deviceRepo.updateBtConnState(d.id, false);
        d.btConnState = 0;
        changed = true;
      }
    } else {
      // 实际断开且持久化为断开：无动作
    }
    return changed;
  }

  /** 立即结束使用会话并落断开状态（回前台/冷启动对账用） */
  private async finishUsageNow(d: Device): Promise<void> {
    const active: Session | null = await this.sessionRepo.getActiveSession(d.id);
    if (active !== null && active.type === SessionType.USAGE) {
      let end: number = active.startBattery;
      if (d.btBattery >= 0) {
        end = Math.min(d.btBattery, active.startBattery);
      }
      await this.sessionRepo.endSession(active.id, end);
      hilog.info(DOMAIN, TAG, 'disconnect discovered: usage %{public}d closed at %{public}d%%', active.id, end);
    }
    await this.deviceRepo.updateBtConnState(d.id, false);
    d.btConnState = 0;
  }

  /** 充电状态转换：充/用互斥（D3）+ 充电结束自动续用（D4） */
  private async applyChargeTransition(d: Device, info: EarphoneBattery, connectedNow: boolean): Promise<void> {
    const prev: number = d.btCharging;
    if (prev >= 0 && prev === info.charging) {
      return;
    }
    if (prev === 0 && info.charging === 1) {
      // 充电开始：结束任何使用会话（无宽限），再开充电会话
      this.cancelPendingEnd(d.btDeviceId);
      const active: Session | null = await this.sessionRepo.getActiveSession(d.id);
      if (active !== null && active.type === SessionType.USAGE) {
        const end: number = info.battery >= 0 ? Math.min(info.battery, active.startBattery) : active.startBattery;
        await this.sessionRepo.endSession(active.id, end);
        hilog.info(DOMAIN, TAG, 'charge start: auto end usage %{public}d (source=%{public}s)', active.id, active.source);
      }
      if (info.battery >= 0 && await this.sessionRepo.getActiveSession(d.id) === null) {
        await this.sessionRepo.startSession(d.id, SessionType.CHARGING, info.battery, '', undefined, SOURCE_AUTO_CHARGE);
        hilog.info(DOMAIN, TAG, 'charge start: auto charging for device %{public}d', d.id);
      }
    } else if (prev === 1 && info.charging === 0) {
      // 充电结束：关闭充电会话；若耳机仍连接且无会话则自动续用（D4）
      const active: Session | null = await this.sessionRepo.getActiveSession(d.id);
      if (active !== null && active.type === SessionType.CHARGING) {
        const end: number = info.battery >= active.startBattery ? info.battery : active.startBattery;
        await this.sessionRepo.endSession(active.id, end);
        hilog.info(DOMAIN, TAG, 'charge end: auto closed charging %{public}d', active.id);
      }
      if (connectedNow && info.battery >= 0 && await this.sessionRepo.getActiveSession(d.id) === null) {
        await this.sessionRepo.startUsageSession(d.id, info.battery, '', -1, SOURCE_AUTO_BT);
        hilog.info(DOMAIN, TAG, 'charge end: auto resume usage for device %{public}d', d.id);
      }
    }
  }

  /** 连接边沿开使用会话；幂等闸门：已有任何活跃会话则忽略（手动开始保护） */
  private async autoStartUsage(d: Device): Promise<void> {
    try {
      const active: Session | null = await this.sessionRepo.getActiveSession(d.id);
      if (active !== null) {
        hilog.info(DOMAIN, TAG, 'connect: session %{public}d already active, skip auto start', active.id);
        return;
      }
      let battery: number = d.btBattery;
      if (battery < 0) {
        const last: Session | null = await this.sessionRepo.getLastCompleted(d.id);
        battery = last !== null ? last.endBattery : 100;
      }
      await this.sessionRepo.startUsageSession(d.id, battery, '', -1, SOURCE_AUTO_BT);
      hilog.info(DOMAIN, TAG, 'connect: auto usage started for device %{public}d at %{public}d%%', d.id, battery);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'autoStartUsage failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 宽限期到点结算：仅当使用会话仍开着才结束（幂等闸门防二次结束） */
  private scheduleGraceEnd(d: Device): void {
    if (this.pendingEnds.has(d.btDeviceId)) {
      return;
    }
    const timerId: number = setTimeout((): void => {
      this.pendingEnds.delete(d.btDeviceId);
      this.finishGraceEnd(d.id, d.btDeviceId);
    }, DISCONNECT_GRACE_MS);
    this.pendingEnds.set(d.btDeviceId, { timerId: timerId });
  }

  private cancelPendingEnd(btDeviceId: string): void {
    const pending: PendingEnd | undefined = this.pendingEnds.get(btDeviceId);
    if (pending !== undefined) {
      clearTimeout(pending.timerId);
      this.pendingEnds.delete(btDeviceId);
    }
  }

  private async finishGraceEnd(deviceId: number, btDeviceId: string): Promise<void> {
    try {
      const active: Session | null = await this.sessionRepo.getActiveSession(deviceId);
      if (active === null || active.type !== SessionType.USAGE) {
        return;
      }
      const d: Device | null = await this.deviceRepo.getById(deviceId);
      let end: number = active.startBattery;
      if (d !== null && d.btBattery >= 0) {
        end = Math.min(d.btBattery, active.startBattery);
      }
      await this.sessionRepo.endSession(active.id, end);
      const still: boolean = BluetoothService.isDeviceConnected(btDeviceId);
      if (!still) {
        await this.deviceRepo.updateBtConnState(deviceId, false);
      }
      DataNotifier.notifyHome();
      hilog.info(DOMAIN, TAG, 'grace end: usage %{public}d closed at %{public}d%%', active.id, end);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'finishGraceEnd failed: %{public}s', JSON.stringify(e));
    }
  }
}
