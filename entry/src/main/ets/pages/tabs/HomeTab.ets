import { HdsNavigation } from '@kit.UIDesignKit';
import { StatCard } from '../../components/StatCard';
import { EmptyState } from '../../components/EmptyState';
import { BatteryInputDialog } from '../../components/BatteryInputDialog';
import { DeviceSheet } from '../../components/DeviceSheet';
import { Device, iconToResource, isNev } from '../../model/Device';
import { Session } from '../../model/Session';
import { SessionType } from '../../model/SessionType';
import { DeviceRepository } from '../../data/repository/DeviceRepository';
import { SessionRepository } from '../../data/repository/SessionRepository';
import { CalcUtil } from '../../utils/CalcUtil';
import { DateTimeUtil } from '../../utils/DateTimeUtil';
import { promptAction } from '@kit.ArkUI';

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
      return $r('app.color.charge_color');
    }
    if (s.type === SessionType.USAGE) {
      return $r('app.color.usage_color');
    }
    return $r('app.color.idle_color');
  }

  private activeBg(s: Session): ResourceColor {
    if (s.type === SessionType.CHARGING) {
      return $r('app.color.charge_bg');
    }
    if (s.type === SessionType.USAGE) {
      return $r('app.color.usage_bg');
    }
    return $r('app.color.idle_bg');
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
              .fillColor($r('app.color.charge_color'))
            Text(`${this.card.currentBattery}%`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
            if (isNev(this.card.device.icon) && this.card.currentRange >= 0) {
              Text('·')
                .fontSize(13)
                .fontColor($r('app.color.text_tertiary'))
              Text(`${this.card.currentRange}km`)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
          }
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
      Column({ space: 8 }) {
        Stack() {
          Text('')
            .width(40)
            .height(40)
            .backgroundColor($r('app.color.usage_color'))
            .borderRadius(20)
            .opacity(0.12)
          Image(iconToResource(this.card.device.icon))
            .width(20)
            .height(20)
            .fillColor($r('app.color.usage_color'))
        }
        .width(40)
        .height(40)
        Text($r('app.string.home_start_usage'))
          .fontSize(12)
          .fontColor($r('app.color.text_primary'))
      }
      .layoutWeight(1)
      .padding({ top: 12, bottom: 12 })
      .borderRadius(14)
      .backgroundColor($r('app.color.usage_bg'))
      .onClick(() => {
        this.onStart(this.card.device, SessionType.USAGE, this.card.currentBattery, this.card.currentRange);
      })

      Column({ space: 8 }) {
        Stack() {
          Text('')
            .width(40)
            .height(40)
            .backgroundColor($r('app.color.charge_color'))
            .borderRadius(20)
            .opacity(0.12)
          Image(iconToResource(this.card.device.icon))
            .width(20)
            .height(20)
            .fillColor($r('app.color.charge_color'))
        }
        .width(40)
        .height(40)
        Text($r('app.string.home_start_charge'))
          .fontSize(12)
          .fontColor($r('app.color.text_primary'))
      }
      .layoutWeight(1)
      .padding({ top: 12, bottom: 12 })
      .borderRadius(14)
      .backgroundColor($r('app.color.charge_bg'))
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
          unit: '%',
          valueColor: $r('app.color.charge_color')
        })
      }
      .layoutWeight(1)
      Column() {
        StatCard({
          label: $r('app.string.stat_today_drain'),
          value: `${this.card.todayDrain}`,
          unit: '%',
          valueColor: $r('app.color.danger')
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
}

@Component
export struct HomeTab {
  @StorageProp('dataVersion') @Watch('reload') dataVersion: number = 0;
  @State cards: DeviceCardData[] = [];
  @State showDeviceSheet: boolean = false;

  private deviceRepo: DeviceRepository = new DeviceRepository();
  private sessionRepo: SessionRepository = new SessionRepository();
  private startDialogController: CustomDialogController | null = null;
  private endDialogController: CustomDialogController | null = null;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.loadData();
  }

  private async loadData(): Promise<void> {
    const devices: Device[] = await this.deviceRepo.listAll(false);
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
    const cards: DeviceCardData[] = [];
    for (const d of ordered) {
      const active: Session | null = await this.sessionRepo.getActive(d.id);
      const sessions: Session[] = await this.sessionRepo.listFiltered(d.id, -1);
      let currentBattery: number = 100;
      let currentRange: number = -1;
      if (isNev(d.icon) && d.rangeRated > 0) {
        currentRange = d.rangeRated;
      }
      if (active !== null) {
        currentBattery = active.startBattery;
        if (active.startRange >= 0) {
          currentRange = active.startRange;
        }
      } else {
        for (const s of sessions) {
          if (s.isCompleted()) {
            currentBattery = s.endBattery;
            if (s.endRange >= 0) {
              currentRange = s.endRange;
            }
            break;
          }
        }
      }
      const card: DeviceCardData = new DeviceCardData();
      card.device = d;
      card.activeSession = active;
      card.currentBattery = currentBattery;
      card.currentRange = currentRange;
      card.todayCount = CalcUtil.countToday(sessions, startToday);
      card.todayDrain = CalcUtil.drainToday(sessions, startToday);
      card.chargeGain = CalcUtil.chargeToday(sessions, startToday);
      cards.push(card);
    }
    this.cards = cards;
  }

  private bump(): void {
    const v: number = AppStorage.get<number>('dataVersion') ?? 0;
    AppStorage.setOrCreate('dataVersion', v + 1);
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
          promptAction.showToast({ message: $r('app.string.toast_end_too_high') });
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: false
    });
    this.endDialogController.open();
  }

  private async confirmStart(deviceId: number, type: SessionType, battery: number, note: string, range: number): Promise<void> {
    if (type === SessionType.USAGE) {
      await this.maybeInsertIdleDrain(deviceId, battery);
    }
    await this.sessionRepo.startSession(deviceId, type, battery, note, range);
    this.bump();
    this.loadData();
  }

  private async maybeInsertIdleDrain(deviceId: number, startBattery: number): Promise<void> {
    const sessions: Session[] = await this.sessionRepo.listFiltered(deviceId, -1);
    let lastCompleted: Session | null = null;
    for (const s of sessions) {
      if (s.isCompleted()) {
        lastCompleted = s;
        break;
      }
    }
    if (lastCompleted !== null && startBattery < lastCompleted.endBattery) {
      await this.sessionRepo.insertCompleted(
        deviceId, SessionType.IDLE,
        lastCompleted.endBattery, startBattery,
        lastCompleted.endTime, Date.now()
      );
    }
  }

  private async confirmEnd(id: number, battery: number, range: number): Promise<void> {
    await this.sessionRepo.endSession(id, battery, range);
    this.bump();
    this.loadData();
  }

  private async saveDevice(name: string, icon: string, capacity: number, rangeRated: number, statMode: string): Promise<void> {
    await this.deviceRepo.insert(name, icon, capacity, rangeRated, statMode);
    this.showDeviceSheet = false;
    this.bump();
    this.loadData();
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
        promptAction.showToast({ message: $r('app.string.toast_name_empty') });
      }
    })
  }
}
