import { HdsNavigation } from '@kit.UIDesignKit';
import { StatCard } from '../../components/StatCard';
import { EmptyState } from '../../components/EmptyState';
import { SessionItem } from '../../components/SessionItem';
import { NoteEditDialog } from '../../components/NoteEditDialog';
import { TrendChart } from '../../components/LineChart';
import { SessionBarChart } from '../../components/SessionBarChart';
import { Device, isNev } from '../../model/Device';
import { Session } from '../../model/Session';
import { ChartPoint } from '../../model/ChartPoint';
import { DeviceRepository } from '../../data/repository/DeviceRepository';
import { SessionRepository } from '../../data/repository/SessionRepository';
import { CalcUtil } from '../../utils/CalcUtil';
import { DateTimeUtil } from '../../utils/DateTimeUtil';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';

@Component
export struct HistoryTab {
  @StorageProp('dataVersion') @Watch('reload') dataVersion: number = 0;
  @State devices: Device[] = [];
  @State sessions: Session[] = [];
  @State chartPoints: ChartPoint[] = [];
  @State filterDeviceId: number = 0;
  @State filterType: number = -1;
  @State filterPeriod: number = 0;
  @State totalSessions: number = 0;
  @State totalDrain: number = 0;
  @State totalCharge: number = 0;
  @State statUnit: string = '%';

  private deviceRepo: DeviceRepository = new DeviceRepository();
  private sessionRepo: SessionRepository = new SessionRepository();
  private noteDialogController: CustomDialogController | null = null;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.loadData();
  }

  private async loadData(): Promise<void> {
    try {
      const devices: Device[] = await this.deviceRepo.listAll(false);
      this.devices = devices;
      if (devices.length === 0) {
        this.sessions = [];
        this.chartPoints = [];
        this.totalSessions = 0;
        this.totalDrain = 0;
        this.totalCharge = 0;
        return;
      }
      const currentExists: boolean = this.filterDeviceId > 0 &&
        devices.some((d: Device): boolean => d.id === this.filterDeviceId);
      if (!currentExists) {
        const defaultId: number = AppStorage.get<number>('defaultDeviceId') ?? -1;
        const hasDefault: boolean = defaultId > 0 && devices.some((d: Device): boolean => d.id === defaultId);
        if (hasDefault) {
          this.filterDeviceId = defaultId;
        } else {
          this.filterDeviceId = devices[0].id;
        }
      }
      const sessionsAll: Session[] = await this.sessionRepo.listFiltered(this.filterDeviceId, this.filterType);
      let cutoff: number = 0;
      if (this.filterPeriod === 1) {
        cutoff = DateTimeUtil.startOfWeek();
      } else if (this.filterPeriod === 2) {
        cutoff = DateTimeUtil.startOfMonth();
      }
      const sessions: Session[] = cutoff > 0
        ? sessionsAll.filter((s: Session): boolean => s.startTime >= cutoff)
        : sessionsAll;
      this.sessions = sessions;
      this.chartPoints = CalcUtil.toChartPoints(sessions);
      this.totalSessions = sessions.length;
      const dev: Device | null = this.findDevice(this.filterDeviceId);
      const nev: boolean = dev !== null && isNev(dev.icon);
      const cap: number = dev !== null ? dev.batteryCapacity : 0;
      if (nev && cap > 0) {
        this.totalDrain = CalcUtil.totalDrain(sessions) * cap / 100;
        this.totalCharge = CalcUtil.totalCharge(sessions) * cap / 100;
        this.statUnit = 'kWh';
      } else {
        this.totalDrain = CalcUtil.totalDrain(sessions);
        this.totalCharge = CalcUtil.totalCharge(sessions);
        this.statUnit = '%';
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'HistoryTab loadData failed: %{public}s', JSON.stringify(e));
    }
  }

  private findDevice(id: number): Device | null {
    for (const d of this.devices) {
      if (d.id === id) {
        return d;
      }
    }
    return null;
  }

  private openNoteDialog(session: Session): void {
    this.noteDialogController = new CustomDialogController({
      builder: NoteEditDialog({
        initialNote: session.note,
        onConfirm: (note: string): void => {
          this.saveNote(session.id, note);
        }
      }),
      alignment: DialogAlignment.Center,
      customStyle: false
    });
    this.noteDialogController.open();
  }

  private async saveNote(id: number, note: string): Promise<void> {
    await this.sessionRepo.updateNote(id, note);
    this.bump();
  }

  private bump(): void {
    const v: number = AppStorage.get<number>('dataVersion') ?? 0;
    AppStorage.setOrCreate('dataVersion', v + 1);
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column({ space: 14 }) {
          if (this.devices.length === 0) {
            this.NoDeviceBody()
          } else {
            this.FilterRow()
            this.StatsRow()
            if (this.sessions.length === 0) {
              this.NoRecordBody()
            } else {
              this.ChartCard()
              this.BarChartCard()
              this.ListSection()
            }
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
  }

  @Builder
  FilterRow() {
    Column({ space: 10 }) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.devices, (d: Device) => {
            this.DeviceChip(d.id, d.name)
          }, (d: Device) => `d${d.id}`)
        }
        .padding({ left: 16, right: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      Row({ space: 8 }) {
        this.PeriodChip(0, $r('app.string.history_filter_all_types'))
        this.PeriodChip(1, $r('app.string.history_filter_week'))
        this.PeriodChip(2, $r('app.string.history_filter_month'))
      }
      .width('100%')

      Row({ space: 8 }) {
        this.TypeChip(-1, $r('app.string.history_filter_all_types'))
        this.TypeChip(0, $r('app.string.history_filter_usage'))
        this.TypeChip(1, $r('app.string.history_filter_idle'))
        this.TypeChip(2, $r('app.string.history_filter_charge'))
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  DeviceChip(id: number, label: ResourceStr) {
    Text(label)
      .fontSize(13)
      .fontColor(this.filterDeviceId === id ? $r('app.color.text_on_brand') : $r('app.color.text_secondary'))
      .backgroundColor(this.filterDeviceId === id ? $r('app.color.brand') : $r('app.color.bg_card'))
      .borderRadius(16)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .maxLines(1)
      .onClick(() => {
        this.filterDeviceId = id;
        this.reload();
      })
  }

  @Builder
  TypeChip(type: number, label: ResourceStr) {
    Text(label)
      .fontSize(13)
      .fontColor(this.filterType === type ? $r('app.color.text_on_brand') : $r('app.color.text_secondary'))
      .backgroundColor(this.filterType === type ? $r('app.color.brand') : $r('app.color.bg_card'))
      .borderRadius(16)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .onClick(() => {
        this.filterType = type;
        this.reload();
      })
  }

  @Builder
  PeriodChip(period: number, label: ResourceStr) {
    Text(label)
      .fontSize(13)
      .fontColor(this.filterPeriod === period ? $r('app.color.text_on_brand') : $r('app.color.text_secondary'))
      .backgroundColor(this.filterPeriod === period ? $r('app.color.brand') : $r('app.color.bg_card'))
      .borderRadius(16)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .onClick(() => {
        this.filterPeriod = period;
        this.reload();
      })
  }

  private periodSessionsLabel(): ResourceStr {
    if (this.filterPeriod === 1) {
      return $r('app.string.history_week_sessions');
    }
    if (this.filterPeriod === 2) {
      return $r('app.string.history_month_sessions');
    }
    return $r('app.string.history_total_sessions');
  }

  private periodDrainLabel(): ResourceStr {
    if (this.filterPeriod === 1) {
      return $r('app.string.history_week_drain');
    }
    if (this.filterPeriod === 2) {
      return $r('app.string.history_month_drain');
    }
    return $r('app.string.history_total_drain');
  }

  private periodChargeLabel(): ResourceStr {
    if (this.filterPeriod === 1) {
      return $r('app.string.history_week_charge');
    }
    if (this.filterPeriod === 2) {
      return $r('app.string.history_month_charge');
    }
    return $r('app.string.history_total_charge');
  }

  @Builder
  StatsRow() {
    Row({ space: 12 }) {
      Column() {
        StatCard({
          label: this.periodSessionsLabel(),
          value: `${this.totalSessions}`
        })
      }
      .layoutWeight(1)
      Column() {
        StatCard({
          label: this.periodChargeLabel(),
          value: this.statUnit === 'kWh' ? this.totalCharge.toFixed(1) : `${this.totalCharge}`,
          unit: this.statUnit,
          valueColor: $r('app.color.charge_color')
        })
      }
      .layoutWeight(1)
      Column() {
        StatCard({
          label: this.periodDrainLabel(),
          value: this.statUnit === 'kWh' ? this.totalDrain.toFixed(1) : `${this.totalDrain}`,
          unit: this.statUnit,
          valueColor: $r('app.color.danger')
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  ChartCard() {
    Column({ space: 8 }) {
      Text($r('app.string.history_chart_title'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      TrendChart({ points: this.chartPoints })
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(16)
  }

  @Builder
  BarChartCard() {
    Column({ space: 8 }) {
      Text($r('app.string.history_bar_title'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      SessionBarChart({ sessions: this.sessions })
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(16)
  }

  @Builder
  ListSection() {
    Column({ space: 10 }) {
      ForEach(this.sessions, (s: Session) => {
        SessionItem({
          session: s,
          deviceName: this.findDevice(s.deviceId)?.name ?? '',
          deviceIcon: this.findDevice(s.deviceId)?.icon ?? 'other',
          onEditNote: (session: Session): void => {
            this.openNoteDialog(session);
          }
        })
      }, (s: Session) => `${s.id}_${s.endTime}`)
    }
    .width('100%')
  }

  @Builder
  NoDeviceBody() {
    Column({ space: 4 }) {
      EmptyState({
        icon: $r('app.media.ic_device_other'),
        title: $r('app.string.history_no_device_title'),
        desc: $r('app.string.history_no_device_desc')
      })
    }
    .width('100%')
    .padding({ top: 40 })
  }

  @Builder
  NoRecordBody() {
    Column({ space: 4 }) {
      EmptyState({
        icon: $r('app.media.ic_history'),
        title: $r('app.string.history_empty_title'),
        desc: $r('app.string.history_empty_desc')
      })
    }
    .width('100%')
    .padding({ top: 20 })
  }
}
