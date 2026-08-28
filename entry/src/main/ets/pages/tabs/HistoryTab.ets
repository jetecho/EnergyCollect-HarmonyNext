import { HdsNavigation } from '@kit.UIDesignKit';
import { StatCard } from '../../components/StatCard';
import { EmptyState } from '../../components/EmptyState';
import { SessionItem } from '../../components/SessionItem';
import { NoteEditDialog } from '../../components/NoteEditDialog';
import { TrendChart } from '../../components/LineChart';
import { SessionBarChart } from '../../components/SessionBarChart';
import { Device, isNev } from '../../model/Device';
import { Session } from '../../model/Session';
import { SessionType } from '../../model/SessionType';
import { ChartPoint } from '../../model/ChartPoint';
import { ChartTooltipData } from '../../model/ChartTooltip';
import { DeviceRepository } from '../../data/repository/DeviceRepository';
import { SessionRepository } from '../../data/repository/SessionRepository';
import { CalcUtil } from '../../utils/CalcUtil';
import { DateTimeUtil } from '../../utils/DateTimeUtil';
import { PAD_CARD, CORNER_MD, CORNER_SM } from '../../utils/DesignTokens';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'EnergyCollect';

/** 充电图默认展示的最近充电记录上限（充电未必每天都有，按记录数而非时间范围） */
const CHARGE_CHART_LIMIT: number = 20;

@Component
export struct HistoryTab {
  @StorageProp('historyDataVersion') @Watch('reload') historyDataVersion: number = 0;
  @State devices: Device[] = [];
  @State sessions: Session[] = [];
  // 图表专用：最近 7 个自然日内的会话（与列表/统计的周期筛选相互独立）
  @State chartSessions: Session[] = [];
  @State chartPoints: ChartPoint[] = [];
  // 充电图专用：最近最多 20 条充电记录（不限时间范围）
  @State chargeSessions: Session[] = [];
  @State filterDeviceId: number = 0;
  @State filterType: number = -1;
  @State filterPeriod: number = 0;
  @State totalSessions: number = 0;
  @State totalDrain: number = 0;
  @State totalCharge: number = 0;
  @State statUnit: string = '%';
  @State isRefreshing: boolean = false;
  @State chartTooltipData: ChartTooltipData | null = null;
  private loadSeq: number = 0;

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

  private periodCutoff(): number {
    if (this.filterPeriod === 1) {
      return DateTimeUtil.startOfWeek();
    }
    if (this.filterPeriod === 2) {
      return DateTimeUtil.startOfMonth();
    }
    return 0;
  }

  /** 图表数据起点：今天零点往前推 6 天，共覆盖最近 7 个自然日 */
  private chartCutoff(): number {
    return DateTimeUtil.startOfToday() - 6 * 24 * 60 * 60 * 1000;
  }

  private async loadData(): Promise<void> {
    const seq: number = ++this.loadSeq;
    try {
      const devices: Device[] = await this.deviceRepo.listAll(false);
      if (seq !== this.loadSeq) {
        return;
      }
      if (devices.length === 0) {
        if (seq === this.loadSeq) {
          this.devices = [];
          this.sessions = [];
          this.chartSessions = [];
          this.chartPoints = [];
          this.chargeSessions = [];
          this.totalSessions = 0;
          this.totalDrain = 0;
          this.totalCharge = 0;
        }
        return;
      }
      let nextFilter: number = this.filterDeviceId;
      const currentExists: boolean = nextFilter > 0 &&
        devices.some((d: Device): boolean => d.id === nextFilter);
      if (!currentExists) {
        const defaultId: number = AppStorage.get<number>('defaultDeviceId') ?? -1;
        const hasDefault: boolean = defaultId > 0 && devices.some((d: Device): boolean => d.id === defaultId);
        if (hasDefault) {
          nextFilter = defaultId;
        } else {
          nextFilter = devices[0].id;
        }
      }
      // 列表/统计按周期筛选；耗电图固定最近 7 个自然日；充电图取最近最多 20 条，三条查询并行
      const cutoff: number = this.periodCutoff();
      const chartStart: number = this.chartCutoff();
      const lists: Session[][] = await Promise.all<Session[]>([
        this.sessionRepo.listFiltered(nextFilter, this.filterType, cutoff),
        this.sessionRepo.listFiltered(nextFilter, this.filterType, chartStart),
        this.sessionRepo.listFiltered(nextFilter, SessionType.CHARGING, 0, CHARGE_CHART_LIMIT)
      ]);
      if (seq !== this.loadSeq) {
        return;
      }
      const sessions: Session[] = lists[0];
      const chartSessions: Session[] = lists[1];
      const chargeSessions: Session[] = lists[2];
      const chartPoints: ChartPoint[] = CalcUtil.toChartPoints(chartSessions);
      const totalSessions: number = sessions.length;
      const dev: Device | null = this.findInList(nextFilter, devices);
      const nev: boolean = dev !== null && isNev(dev.icon);
      const cap: number = dev !== null ? dev.batteryCapacity : 0;
      let totalDrain: number = 0;
      let totalCharge: number = 0;
      let statUnit: string = '%';
      if (nev && cap > 0) {
        totalDrain = CalcUtil.toKwh(CalcUtil.totalDrain(sessions), cap);
        totalCharge = CalcUtil.toKwh(CalcUtil.totalCharge(sessions), cap);
        statUnit = 'kWh';
      } else {
        totalDrain = CalcUtil.totalDrain(sessions);
        totalCharge = CalcUtil.totalCharge(sessions);
      }
      if (seq !== this.loadSeq) {
        return;
      }
      this.devices = devices;
      this.filterDeviceId = nextFilter;
      this.sessions = sessions;
      this.chartSessions = chartSessions;
      this.chartPoints = chartPoints;
      this.chargeSessions = chargeSessions;
      this.totalSessions = totalSessions;
      this.totalDrain = totalDrain;
      this.totalCharge = totalCharge;
      this.statUnit = statUnit;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'HistoryTab loadData failed: %{public}s', JSON.stringify(e));
    }
  }

  private findDevice(id: number): Device | null {
    return this.findInList(id, this.devices);
  }

  private findInList(id: number, list: Device[]): Device | null {
    for (const d of list) {
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
    try {
      await this.sessionRepo.updateNote(id, note);
      // 备注仅影响历史列表自身展示，本地更新（新对象触发 ForEach 重新 diff）即可，
      // 无需任何跨 Tab 通知
      const updated: Session[] = [];
      for (const s of this.sessions) {
        if (s.id === id) {
          const copy: Session = this.cloneSession(s);
          copy.note = note;
          updated.push(copy);
        } else {
          updated.push(s);
        }
      }
      this.sessions = updated;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'saveNote failed: %{public}s', JSON.stringify(e));
    }
  }

  private cloneSession(s: Session): Session {
    const copy: Session = new Session();
    copy.id = s.id;
    copy.deviceId = s.deviceId;
    copy.type = s.type;
    copy.startBattery = s.startBattery;
    copy.endBattery = s.endBattery;
    copy.startTime = s.startTime;
    copy.endTime = s.endTime;
    copy.note = s.note;
    copy.createdAt = s.createdAt;
    copy.startRange = s.startRange;
    copy.endRange = s.endRange;
    return copy;
  }

  /** 点击页面任意处或滚动历史页时，隐藏图表悬浮信息 */
  private dismissChartTooltips(): void {
    this.chartTooltipData = null;
  }

  /** 图表命中数据点后显示悬浮信息 */
  private onChartTap(data: ChartTooltipData): void {
    this.chartTooltipData = data;
  }

  build() {
    HdsNavigation() {
      Refresh({ refreshing: $$this.isRefreshing }) {
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
                this.ChargeChartCard()
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
        .onTouch((event: TouchEvent) => {
          // 触摸页面任意处（点击或滚动）即隐藏图表悬浮信息
          if (event.type === TouchType.Down || event.type === TouchType.Move) {
            this.dismissChartTooltips();
          }
        })
      }
      .width('100%')
      .height('100%')
      .onRefreshing(() => {
        this.loadData().then(() => {
          this.isRefreshing = false;
        });
      })
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
          }, (d: Device) => `d${d.id}_${d.name}`)
        }
        .padding({ left: 16, right: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      Row({ space: 8 }) {
        this.PeriodChip(0, $r('app.string.history_filter_all'))
        this.PeriodChip(1, $r('app.string.history_filter_week'))
        this.PeriodChip(2, $r('app.string.history_filter_month'))
      }
      .width('100%')

      Row({ space: 8 }) {
        this.TypeChip(-1, $r('app.string.history_filter_all'))
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
      if (this.chartSessions.length === 0) {
        this.ChartEmpty($r('app.string.history_chart_empty'))
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          TrendChart({
            points: this.chartPoints,
            tag: 'trend',
            onTap: (d: ChartTooltipData): void => {
              this.onChartTap(d);
            }
          })
            .width('100%')
          if (this.chartTooltipData !== null && this.chartTooltipData.tag === 'trend') {
            this.ChartTooltip(this.chartTooltipData)
          }
        }
        .width('100%')
        .height(180)
      }
    }
    .width('100%')
    .padding(PAD_CARD)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(CORNER_MD)
  }

  @Builder
  BarChartCard() {
    Column({ space: 8 }) {
      Text($r('app.string.history_drain_title'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      if (this.chartSessions.length === 0) {
        this.ChartEmpty($r('app.string.history_chart_empty'))
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          SessionBarChart({
            sessions: this.chartSessions,
            mode: 0,
            tag: 'drain',
            onTap: (d: ChartTooltipData): void => {
              this.onChartTap(d);
            }
          })
            .width('100%')
          if (this.chartTooltipData !== null && this.chartTooltipData.tag === 'drain') {
            this.ChartTooltip(this.chartTooltipData)
          }
        }
        .width('100%')
        .height(180)
      }
    }
    .width('100%')
    .padding(PAD_CARD)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(CORNER_MD)
  }

  @Builder
  ChargeChartCard() {
    Column({ space: 8 }) {
      Text($r('app.string.history_charge_title'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      if (this.chargeSessions.length === 0) {
        this.ChartEmpty($r('app.string.history_charge_empty'))
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          SessionBarChart({
            sessions: this.chargeSessions,
            mode: 1,
            tag: 'charge',
            onTap: (d: ChartTooltipData): void => {
              this.onChartTap(d);
            }
          })
            .width('100%')
          if (this.chartTooltipData !== null && this.chartTooltipData.tag === 'charge') {
            this.ChartTooltip(this.chartTooltipData)
          }
        }
        .width('100%')
        .height(180)
      }
    }
    .width('100%')
    .padding(PAD_CARD)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(CORNER_MD)
  }

  /** 图表悬浮信息卡片 */
  @Builder
  ChartTooltip(data: ChartTooltipData) {
    Column({ space: 4 }) {
      Text(data.valueText)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(data.valueColor)
      Text(data.timeText)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
      if (data.note.length > 0) {
        Text(data.note)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width(160)
    .padding(8)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(CORNER_SM)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.15)', offsetY: 4 })
    .position({ x: data.x, y: data.y })
    .translate({ x: -80, y: -90 })
  }

  /** 图表无数据时的占位（高度与图表一致，避免布局跳动） */
  @Builder
  ChartEmpty(message: ResourceStr) {
    Column({ space: 6 }) {
      Image($r('app.media.ic_history'))
        .width(36)
        .height(36)
        .fillColor($r('app.color.icon_outline'))
        .opacity(0.6)
      Text(message)
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .height(180)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ListSection() {
    Column({ space: 10 }) {
      // 键值需包含条目渲染的全部易变内容（备注、设备名/图标）：
      // ForEach 同键复用组件时不会重新执行 itemGenerator，漏掉的字段在数据更新后会显示旧值
      ForEach(this.sessions, (s: Session) => {
        SessionItem({
          session: s,
          deviceName: this.findDevice(s.deviceId)?.name ?? '',
          deviceIcon: this.findDevice(s.deviceId)?.icon ?? 'other',
          onEditNote: (session: Session): void => {
            this.openNoteDialog(session);
          }
        })
      }, (s: Session) => `${s.id}_${s.endTime}_${s.note}_${this.findDevice(s.deviceId)?.name ?? ''}_${this.findDevice(s.deviceId)?.icon ?? 'other'}`)
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
