import { HdsNavigation } from '@kit.UIDesignKit';
import { StatCard } from '../../components/StatCard';
import { EmptyState } from '../../components/EmptyState';
import { BatteryInputDialog } from '../../components/BatteryInputDialog';
import { DeviceSheet } from '../../components/DeviceSheet';
import { Device, iconToResource, isNev } from '../../model/Device';
import { Session } from '../../model/Session';
import { SessionType } from '../../model/SessionType';
import { DeviceRepository } from '../../data/repository/DeviceRepository';
import { PreferencesUtil } from '../../data/PreferencesUtil';
import { SessionRepository, TodayStats } from '../../data/repository/SessionRepository';
import { Database } from '../../data/Database';
import { DataNotifier } from '../../data/DataNotifier';
import { DateTimeUtil } from '../../utils/DateTimeUtil';
import { PromptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';

@Observed
export class DeviceCardData {
  device: Device = new Device();
  activeSession: Session | null = null;
  currentBattery: number = -1;
  currentRange: number = -1;
  todayCount: number = 0;
  todayDrain: number = 0;
  chargeGain: number = 0;
}

@Component
export struct DeviceCard {
  @ObjectLink card: DeviceCardData;
  onStart: (device: Device, type: SessionType, defaultBattery: number, defaultRange: number) => void = (): void => {};
  onEnd: (session: Session, device: Device) => void = (): void => {};
  @State elapsedText: string = '00:00:00';
  private timerId: number = -1;

  aboutToAppear(): void {
    if (this.card.activeSession !== null) {
      this.elapsedText = DateTimeUtil.formatClock(Date.now() - this.card.activeSession.startTime);
      this.ensureTimer();
    }
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private ensureTimer(): void {
    if (this.timerId !== -1) {
      return;
    }
    this.timerId = setInterval((): void => {
      if (this.card.activeSession !== null) {
        this.elapsedText = DateTimeUtil.formatClock(Date.now() - this.card.activeSession.startTime);
      }
    }, 1000);
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private activeLabel(s: Session): ResourceStr {
    if (s.type === SessionType.CHARGING) {
      return $r('app.string.home_active_charge');
    }
    if (s.type === SessionType.USAGE) {
      return $r('app.string.home_active_usage');
    }
    return $r('app.string.home_active_idle');
  }

  private activeColor(s: Session): ResourceColor {
    if (s.type === SessionType.CHARGING) {
      return $r('app.color.home_charge_color');
    }
    if (s.type === SessionType.USAGE) {
      return $r('app.color.usage_color');
    }
    return $r('app.color.home_idle_color');
  }

  private activeBg(s: Session): ResourceColor {
    if (s.type === SessionType.CHARGING) {
      return $r('app.color.home_charge_bg');
    }
    if (s.type === SessionType.USAGE) {
      return $r('app.color.usage_bg');
    }
    return $r('app.color.home_idle_bg');
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Image(iconToResource(this.card.device.icon))
          .width(22)
          .height(22)
          .fillColor($r('app.color.brand'))
        Text(this.card.device.name)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.card.currentBattery >= 0) {
          Row({ space: 4 }) {
            Image($r('app.media.ic_lightning'))
              .width(13)
              .height(13)
              .fillColor($r('app.color.home_charge_color'))
            Text(`${this.card.currentBattery}%`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
            if (isNev(this.card.device.icon) && this.card.currentRange >= 0) {
              Text($r('app.string.symbol_dot'))
                .fontSize(13)
                .fontColor($r('app.color.text_tertiary'))
              Text(`${this.card.currentRange}km`)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
          }
        } else {
          Text('--')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')

      if (this.card.activeSession !== null) {
        this.ActiveArea(this.card.activeSession)
      } else {
        this.CtaRow()
      }

      this.StatsRow()
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(18)
  }

  @Builder
  CtaRow() {
    Row({ space: 12 }) {
      Column({ space: 10 }) {
        Image(iconToResource(this.card.device.icon))
          .width(20)
          .height(20)
          .fillColor($r('app.color.brand'))
        Text($r('app.string.home_start_usage'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding({ top: 16, bottom: 16 })
      .borderRadius(14)
      .backgroundColor($r('app.color.usage_bg'))
      .onClick(() => {
        this.onStart(this.card.device, SessionType.USAGE, this.card.currentBattery, this.card.currentRange);
      })

      Column({ space: 10 }) {
        Image(iconToResource(this.card.device.icon))
          .width(20)
          .height(20)
          .fillColor($r('app.color.brand'))
        Text($r('app.string.home_start_charge'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .padding({ top: 16, bottom: 16 })
      .borderRadius(14)
      .backgroundColor($r('app.color.home_charge_bg'))
      .onClick(() => {
        this.onStart(this.card.device, SessionType.CHARGING, this.card.currentBattery, this.card.currentRange);
      })
    }
    .width('100%')
  }

  @Builder
  ActiveArea(s: Session) {
    Column({ space: 12 }) {
      Row() {
        Row({ space: 6 }) {
          Text(this.activeLabel(s))
            .fontSize(12)
            .fontColor(this.activeColor(s))
            .backgroundColor(this.activeBg(s))
            .borderRadius(6)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }
        Blank()
      }
      .width('100%')

      Row() {
        Column({ space: 4 }) {
          Text(this.elapsedText)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.home_elapsed'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column({ space: 4 }) {
          Row({ space: 3 }) {
            Text(`${s.startBattery}`)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('%')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(VerticalAlign.Bottom)
          Text($r('app.string.home_start_battery'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      Button($r('app.string.home_end_session'))
        .type(ButtonType.Normal)
        .borderRadius(12)
        .width('100%')
        .height(44)
        .backgroundColor($r('app.color.brand'))
        .fontColor($r('app.color.text_on_brand'))
        .onClick(() => {
          this.onEnd(s, this.card.device);
        })
    }
    .width('100%')
  }

  @Builder
  StatsRow() {
    Row({ space: 12 }) {
      Column() {
        StatCard({
          label: $r('app.string.stat_today_sessions'),
          value: `${this.card.todayCount}`
        })
      }
      .layoutWeight(1)
      Column() {
        StatCard({
          label: $r('app.string.stat_today_charge'),
          value: `${this.card.chargeGain}`,
          unit: '%'
        })
      }
      .layoutWeight(1)
      Column() {
        StatCard({
          label: $r('app.string.stat_today_drain'),
          value: `${this.card.todayDrain}`,
          unit: '%'
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
}

@Component
export struct HomeTab {
  private promptAction: PromptAction = this.getUIContext().getPromptAction();
  @StorageProp('homeDataVersion') @Watch('reload') homeDataVersion: number = 0;
  @StorageProp('dbInitFailed') dbInitFailed: boolean = false;
  // 孤儿会话恢复晚于页面创建时，通过 AppStorage 变化补发提示
  @StorageProp('recoveredSessions') @Watch('onRecoveredSessionsChange') recoveredSessions: number = 0;
  @State cards: DeviceCardData[] = [];
  @State showDeviceSheet: boolean = false;
  private loadSeq: number = 0;

  private deviceRepo: DeviceRepository = new DeviceRepository();
  private sessionRepo: SessionRepository = new SessionRepository();
  private startDialogController: CustomDialogController | null = null;
  private endDialogController: CustomDialogController | null = null;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.notifyRecoveredSessions();
    this.reload();
  }

  reload(): void {
    this.loadData();
  }

  private notifyRecoveredSessions(): void {
    const recovered: number = AppStorage.get<number>('recoveredSessions') ?? 0;
    if (recovered > 0) {
      AppStorage.setOrCreate('recoveredSessions', 0);
      this.showToastSafe($r('app.string.toast_recovered_sessions', recovered));
    }
  }

  onRecoveredSessionsChange(): void {
    this.notifyRecoveredSessions();
  }

  private async loadData(): Promise<void> {
    const seq: number = ++this.loadSeq;
    try {
      const devices: Device[] = await this.deviceRepo.listAll(false);
      if (seq !== this.loadSeq) {
        return;
      }
      const defaultId: number = AppStorage.get<number>('defaultDeviceId') ?? -1;
      const ordered: Device[] = devices.slice().sort((a: Device, b: Device): number => {
        if (a.id === defaultId) {
          return -1;
        }
        if (b.id === defaultId) {
          return 1;
        }
        return 0;
      });
      const startToday: number = DateTimeUtil.startOfToday();
      // 每设备 3 条轻量 SQL 并行查询（进行中/最近已完成/今日聚合），替代全量历史加载。
      // 复用已有卡片对象并原地赋值（@Observed + @ObjectLink）：ForEach 同键复用组件时
      // 也能刷到新数据，修复设备改名/导入后首页仍显示旧值的问题
      const oldById: Map<number, DeviceCardData> = new Map<number, DeviceCardData>();
      for (const c of this.cards) {
        oldById.set(c.device.id, c);
      }
      const cards: DeviceCardData[] =
        ordered.map((d: Device): DeviceCardData => oldById.get(d.id) ?? new DeviceCardData());
      const fills: Promise<void>[] = [];
      for (let i: number = 0; i < ordered.length; i++) {
        fills.push(this.fillDeviceCard(cards[i], ordered[i], startToday, seq));
      }
      await Promise.all(fills);
      if (seq !== this.loadSeq) {
        return;
      }
      this.cards = cards;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'HomeTab loadData failed: %{public}s', JSON.stringify(e));
    }
  }

  private async fillDeviceCard(card: DeviceCardData, device: Device, startToday: number, seq: number): Promise<void> {
    try {
      const results: Array<Session | TodayStats | null> = await Promise.all<Session | TodayStats | null>([
        this.sessionRepo.getActiveSession(device.id),
        this.sessionRepo.getLastCompleted(device.id),
        this.sessionRepo.getTodayStats(device.id, startToday)
      ]);
      if (seq !== this.loadSeq) {
        return;
      }
      const active: Session | null = results[0] as Session | null;
      const lastCompleted: Session | null = results[1] as Session | null;
      const stats: TodayStats = results[2] as TodayStats;
      card.device = device;
      card.activeSession = active;
      card.currentBattery = -1;
      card.currentRange = isNev(device.icon) && device.rangeRated > 0 ? device.rangeRated : -1;
      if (active !== null) {
        card.currentBattery = active.startBattery;
        if (active.startRange >= 0) {
          card.currentRange = active.startRange;
        }
      } else if (lastCompleted !== null) {
        card.currentBattery = lastCompleted.endBattery;
        if (lastCompleted.endRange >= 0) {
          card.currentRange = lastCompleted.endRange;
        }
      }
      card.todayCount = stats.count;
      card.todayDrain = stats.drain;
      card.chargeGain = stats.charge;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'fillDeviceCard failed for device %{public}d: %{public}s',
        device.id, JSON.stringify(e));
      if (seq === this.loadSeq) {
        card.device = device;
        card.activeSession = null;
        card.currentBattery = -1;
        card.currentRange = isNev(device.icon) && device.rangeRated > 0 ? device.rangeRated : -1;
      }
    }
  }

  private async retryDbInit(): Promise<void> {
    const ctx: Context | undefined = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      this.showToastSafe($r('app.string.toast_action_failed'));
      return;
    }
    try {
      await Database.getInstance().init(ctx);
      AppStorage.setOrCreate('dbInitFailed', false);
      DataNotifier.notifyAll();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'retryDbInit failed: %{public}s', JSON.stringify(e));
      this.showToastSafe($r('app.string.toast_action_failed'));
    }
  }

  private showToastSafe(message: ResourceStr): void {
    try {
      this.promptAction.showToast({ message: message });
    } catch (error) {
      const code: number = (error as BusinessError).code;
      const msg: string = (error as BusinessError).message;
      hilog.error(DOMAIN, TAG, 'showToast failed: code=%{public}d, message=%{public}s', code, msg);
    }
  }

  private openStartDialog(device: Device, type: SessionType, defaultBattery: number, defaultRange: number): void {
    const nev: boolean = isNev(device.icon);
    this.startDialogController = new CustomDialogController({
      builder: BatteryInputDialog({
        title: $r('app.string.battery_start_title'),
        maxValue: 100,
        defaultValue: defaultBattery,
        showRange: nev,
        rangeMax: device.rangeRated,
        rangeDefault: defaultRange,
        showNote: true,
        onConfirm: (battery: number, note: string, range: number): void => {
          this.confirmStart(device.id, type, battery, note, nev ? range : -1);
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: false
    });
    this.startDialogController.open();
  }

  private openEndDialog(session: Session, device: Device): void {
    const nev: boolean = isNev(device.icon);
    const isCharge: boolean = session.type === SessionType.CHARGING;
    this.endDialogController = new CustomDialogController({
      builder: BatteryInputDialog({
        title: $r('app.string.battery_end_title'),
        maxValue: isCharge ? 100 : session.startBattery,
        minValue: isCharge ? session.startBattery : 0,
        showRange: nev,
        rangeMax: device.rangeRated,
        rangeDefault: session.startRange >= 0 ? session.startRange : -1,
        showNote: false,
        onConfirm: (battery: number, note: string, range: number): void => {
          this.confirmEnd(session.id, battery, nev ? range : -1);
        },
        onInvalid: (): void => {
          this.showToastSafe($r('app.string.toast_end_too_high'));
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: false
    });
    this.endDialogController.open();
  }

  private async confirmStart(deviceId: number, type: SessionType, battery: number, note: string, range: number): Promise<void> {
    try {
      if (type === SessionType.USAGE) {
        await this.sessionRepo.startUsageSession(deviceId, battery, note, range);
      } else {
        await this.sessionRepo.startSession(deviceId, type, battery, note, range);
      }
      // 会话变更影响首页统计与历史页，定向通知；本 Tab 由 @Watch 触发 reload
      DataNotifier.notifyHome();
      DataNotifier.notifyHistory();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'confirmStart failed: %{public}s', JSON.stringify(e));
      this.showToastSafe($r('app.string.toast_action_failed'));
    }
  }

  private async confirmEnd(id: number, battery: number, range: number): Promise<void> {
    try {
      await this.sessionRepo.endSession(id, battery, range);
      DataNotifier.notifyHome();
      DataNotifier.notifyHistory();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'confirmEnd failed: %{public}s', JSON.stringify(e));
      this.showToastSafe($r('app.string.toast_action_failed'));
    }
  }

  private async saveDevice(name: string, icon: string, capacity: number, rangeRated: number, statMode: string): Promise<void> {
    try {
      const id: number = await this.deviceRepo.insert(name, icon, capacity, rangeRated, statMode);
      await this.ensureDefaultDevice(id);
      this.showDeviceSheet = false;
      DataNotifier.notifyAll();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'saveDevice failed: %{public}s', JSON.stringify(e));
      this.showToastSafe($r('app.string.toast_action_failed'));
    }
  }

  private async ensureDefaultDevice(newId: number): Promise<void> {
    const curDefault: number = AppStorage.get<number>('defaultDeviceId') ?? -1;
    if (curDefault > 0) {
      const exist: Device | null = await this.deviceRepo.getById(curDefault);
      if (exist !== null) {
        return;
      }
    }
    AppStorage.setOrCreate('defaultDeviceId', newId);
    PreferencesUtil.setDefaultDeviceId(newId);
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column({ space: 16 }) {
          if (this.cards.length === 0) {
            this.EmptyBody()
          } else {
            ForEach(this.cards, (card: DeviceCardData) => {
              DeviceCard({
                card: card,
                onStart: (device: Device, type: SessionType, defaultBattery: number, defaultRange: number): void => {
                  this.openStartDialog(device, type, defaultBattery, defaultRange);
                },
                onEnd: (session: Session, device: Device): void => {
                  this.openEndDialog(session, device);
                }
              })
            }, (card: DeviceCardData) => `${card.device.id}_${card.activeSession !== null ? card.activeSession.id : 'none'}`)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 96 + this.navBarHeight })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .hideTitleBar(true)
    .padding({ top: this.statusBarHeight })
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP])
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.bg_gradient_start'), 0.0], [$r('app.color.bg_gradient_end'), 1.0]]
    })
    .bindSheet($$this.showDeviceSheet, this.DeviceSheetBuilder(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false,
      backgroundColor: $r('app.color.bg_primary')
    })
  }

  @Builder
  EmptyBody() {
    if (this.dbInitFailed) {
      Column({ space: 4 }) {
        EmptyState({
          icon: $r('app.media.ic_device_other'),
          title: $r('app.string.db_error_title'),
          desc: $r('app.string.db_error_desc')
        })
        Button($r('app.string.db_error_retry'))
          .type(ButtonType.Normal)
          .borderRadius(14)
          .height(44)
          .padding({ left: 28, right: 28 })
          .backgroundColor($r('app.color.brand'))
          .fontColor($r('app.color.text_on_brand'))
          .margin({ top: 8 })
          .onClick(() => {
            this.retryDbInit();
          })
      }
      .width('100%')
      .padding({ top: 40 })
    } else {
      Column({ space: 4 }) {
        EmptyState({
          icon: $r('app.media.ic_device_other'),
          title: $r('app.string.home_no_device_title'),
          desc: $r('app.string.home_no_device_desc')
        })
        Button($r('app.string.home_no_device_btn'))
          .type(ButtonType.Normal)
          .borderRadius(14)
          .height(44)
          .padding({ left: 28, right: 28 })
          .backgroundColor($r('app.color.brand'))
          .fontColor($r('app.color.text_on_brand'))
          .margin({ top: 8 })
          .onClick(() => {
            this.showDeviceSheet = true;
          })
      }
      .width('100%')
      .padding({ top: 40 })
    }
  }

  @Builder
  DeviceSheetBuilder() {
    DeviceSheet({
      sheetTitle: $r('app.string.dialog_new_device_title'),
      initialName: '',
      initialIcon: 'other',
      canDelete: false,
      onSave: (name: string, icon: string, capacity: number, rangeRated: number, statMode: string): void => {
        this.saveDevice(name, icon, capacity, rangeRated, statMode);
      },
      onClose: (): void => {
        this.showDeviceSheet = false;
      },
      onInvalid: (): void => {
        this.showToastSafe($r('app.string.toast_name_empty'));
      }
    })
  }
}
