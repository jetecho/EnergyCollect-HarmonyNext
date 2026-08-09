import { HdsNavigation } from '@kit.UIDesignKit';
import { StatCard } from '../../components/StatCard';
import { EmptyState } from '../../components/EmptyState';
import { SessionItem } from '../../components/SessionItem';
import { TrendChart } from '../../components/LineChart';
import { SessionBarChart } from '../../components/SessionBarChart';
import { Device, isNev } from '../../model/Device';
import { Session } from '../../model/Session';
import { ChartPoint } from '../../model/ChartPoint';
import { DeviceRepository } from '../../data/repository/DeviceRepository';
import { SessionRepository } from '../../data/repository/SessionRepository';
import { CalcUtil } from '../../utils/CalcUtil';

@Component
export struct HistoryTab {
  @StorageProp('dataVersion') @Watch('reload') dataVersion: number = 0;
  @State devices: Device[] = [];
  @State sessions: Session[] = [];
  @State chartPoints: ChartPoint[] = [];
  @State filterDeviceId: number = 0;
  @State filterType: number = -1;
  @State totalSessions: number = 0;
  @State totalDrain: number = 0;
  @State totalCharge: number = 0;
  @State statUnit: string = '%';

  private deviceRepo: DeviceRepository = new DeviceRepository();
  private sessionRepo: SessionRepository = new SessionRepository();
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
    this.devices = devices;
    if (this.filterDeviceId <= 0) {
      if (devices.length > 0) {
        this.filterDeviceId = devices[0].id;
      } else {
        this.sessions = [];
        this.chartPoints = [];
        this.totalSessions = 0;
        this.totalDrain = 0;
        this.totalCharge = 0;
        return;
      }
    }
    const sessions: Session[] = await this.sessionRepo.listFiltered(this.filterDeviceId, this.filterType);
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
  }

  private findDevice(id: number): Device | null {
    for (const d of this.devices) {
      if (d.id === id) {
        return d;
      }
    }
    return null;
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column({ space: 14 }) {
          this.FilterRow()
          this.StatsRow()
          this.ChartCard()
          this.BarChartCard()
          this.ListSection()
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
  StatsRow() {
    Row({ space: 12 }) {
      Column() {
        StatCard({
          label: $r('app.string.history_total_sessions'),
          value: `${this.totalSessions}`
        })
      }
      .layoutWeight(1)
      Column() {
        StatCard({
          label: $r('app.string.history_total_charge'),
          value: this.statUnit === 'kWh' ? this.totalCharge.toFixed(1) : `${this.totalCharge}`,
          unit: this.statUnit,
          valueColor: $r('app.color.charge_color')
        })
      }
      .layoutWeight(1)
      Column() {
        StatCard({
          label: $r('app.string.history_total_drain'),
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
    if (this.sessions.length === 0) {
      Column() {
        EmptyState({
          icon: $r('app.media.ic_history'),
          title: $r('app.string.history_empty_title'),
          desc: $r('app.string.history_empty_desc')
        })
      }
      .width('100%')
    } else {
      Column({ space: 10 }) {
        ForEach(this.sessions, (s: Session) => {
          SessionItem({
            session: s,
            deviceName: this.findDevice(s.deviceId)?.name ?? '',
            deviceIcon: this.findDevice(s.deviceId)?.icon ?? 'other'
          })
        }, (s: Session) => `${s.id}_${s.endTime}`)
      }
      .width('100%')
    }
  }
}
