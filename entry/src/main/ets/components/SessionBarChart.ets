import { BarChart as MpBarChart, BarChartModel, BarDataSet, BarData, BarEntry, JArrayList, XAxisPosition, IBarDataSet, AxisBase, IAxisValueFormatter, Highlight } from '@ohos/mpchart';
import { Session } from '../model/Session';
import { SessionType } from '../model/SessionType';
import { CalcUtil } from '../utils/CalcUtil';
import { DateTimeUtil } from '../utils/DateTimeUtil';
import { ChartTooltipData } from '../model/ChartTooltip';
import { Immersive } from '../utils/Immersive';

/**
 * 均等 x 轴下的时间标签：x 值为柱子序号（0,1,2...），映射回真实时间展示
 */
class ChartTimeFormatter implements IAxisValueFormatter {
  times: number[] = [];

  getFormattedValue(value: number, axis: AxisBase): string {
    const idx: number = Math.round(value);
    if (idx < 0 || idx >= this.times.length) {
      return '';
    }
    return DateTimeUtil.formatAxisTime(this.times[idx]);
  }
}

@Component
export struct SessionBarChart {
  @Prop @Watch('refresh') sessions: Session[] = [];
  /** 0=耗电图（使用红/闲置黄），1=充电图（绿色） */
  @Prop mode: number = 0;
  /** 来源标识，用于 HistoryTab 区分 tooltip 归属 */
  @Prop tag: string = '';
  /** 深浅色跟随应用设置/系统配置，变化时重绘配色 */
  @StorageProp('colorMode') @Watch('refresh') colorMode: number = -1;
  @StorageProp('systemColorMode') @Watch('refresh') systemColorMode: number = -1;
  /** 命中柱子时上抛悬浮信息 */
  onTap: (data: ChartTooltipData) => void = (): void => {};
  private model: BarChartModel = new BarChartModel();
  private timeFormatter: ChartTimeFormatter = new ChartTimeFormatter();
  /** 当前绘制的会话（过滤+排序后，与柱子索引一一对应） */
  private displaySessions: Session[] = [];
  private downX: number = -1;
  private downY: number = -1;

  aboutToAppear(): void {
    this.setupModel();
    this.refresh();
  }

  private setupModel(): void {
    this.model.animateY(400);
    this.model.getDescription()?.setEnabled(false);
    this.model.getLegend()?.setEnabled(false);
    this.model.getXAxis()?.setPosition(XAxisPosition.BOTTOM);
    this.model.getXAxis()?.setDrawGridLines(false);
    this.model.getXAxis()?.setValueFormatter(this.timeFormatter);
    this.model.getXAxis()?.setLabelCount(6, true);
    this.model.getXAxis()?.setGranularity(1);
    this.model.getAxisRight()?.setEnabled(false);
    this.model.getAxisLeft()?.setAxisMinimum(0);
    this.model.getAxisLeft()?.setDrawGridLines(true);
    this.model.setScaleEnabled(false);
    this.model.setDragXEnabled(true);
    this.model.setHighlightPerTapEnabled(false);
    this.model.setHighlightPerDragEnabled(false);
    this.model.setDrawValueAboveBar(true);
  }

  refresh(): void {
    const isDark: boolean = Immersive.isDarkMode(this.colorMode, this.systemColorMode);
    this.applyPalette(isDark);
    const list: Session[] = [];
    for (const s of this.sessions) {
      if (!s.isCompleted()) {
        continue;
      }
      if (this.mode === 1) {
        if (s.type !== SessionType.CHARGING) {
          continue;
        }
      } else if (s.type === SessionType.CHARGING) {
        continue;
      }
      list.push(s);
    }
    list.sort((a: Session, b: Session): number => a.startTime - b.startTime);
    // 记录当前绘制的会话，供点击选中时回查
    this.displaySessions = list;
    // 柱色与 color.json 保持同步：充电 charge_color、闲置 idle_color、使用 danger
    const chargeColor: number = isDark ? 0xFF3DCE9E : 0xFF1FA978;
    const usageColor: number = isDark ? 0xFFFF6A4D : 0xFFE84026;
    const idleColor: number = isDark ? 0xFFFFB020 : 0xFFF08200;
    // 均等 x 轴：柱子按序号等间距排列，时间仅用于底部标签
    const values: JArrayList<BarEntry> = new JArrayList<BarEntry>();
    const colors: number[] = [];
    const times: number[] = [];
    for (let i: number = 0; i < list.length; i++) {
      const s: Session = list[i];
      const y: number = this.mode === 1 ? s.endBattery - s.startBattery : CalcUtil.consumption(s);
      values.add(new BarEntry(i, y));
      times.push(s.startTime);
      if (this.mode === 1) {
        colors.push(chargeColor);
      } else if (s.type === SessionType.IDLE) {
        colors.push(idleColor);
      } else {
        colors.push(usageColor);
      }
    }
    const set: BarDataSet = new BarDataSet(values, '');
    set.setColorsByArr(colors);
    set.setValueTextColor(isDark ? 0xFFA8A8A8 : 0xFF555770);
    // 柱顶数值仅在柱子较少时显示，避免重叠
    set.setDrawValues(list.length <= 10);
    const sets: JArrayList<IBarDataSet> = new JArrayList<IBarDataSet>();
    sets.add(set);
    const data: BarData = new BarData(sets);
    // 均等轴下柱宽按槽位比例固定
    data.setBarWidth(0.6);
    this.timeFormatter.times = times;
    this.model.setData(data);
  }

  /** 轴标签与网格线配色随深浅色切换（色值与 color.json 的 text_tertiary/divider 保持同步） */
  private applyPalette(isDark: boolean): void {
    const labelColor: number = isDark ? 0xFF6E6E6E : 0xFF99A0B3;
    const gridColor: number = isDark ? 0xFF2A2A2A : 0xFFE5E8EE;
    this.model.getXAxis()?.setTextColor(labelColor);
    this.model.getXAxis()?.setGridColor(gridColor);
    this.model.getAxisLeft()?.setTextColor(labelColor);
    this.model.getAxisLeft()?.setGridColor(gridColor);
  }

  /** 按坐标判断是否命中柱子，命中则上抛悬浮信息 */
  private handleChartTapAt(x: number, y: number): void {
    const h: Highlight | null = this.model.getHighlightByTouchPoint(x, y);
    if (h === null) {
      return;
    }
    const idx: number = Math.round(h.getX());
    if (idx < 0 || idx >= this.displaySessions.length) {
      return;
    }
    const vph = this.model.getViewPortHandler();
    const n: number = this.displaySessions.length;
    const slotWidth: number = (vph.contentRight() - vph.contentLeft()) / n;
    const halfBar: number = 0.3 * slotWidth;
    // x 不在柱子宽度内（柱间空隙）或 y 在柱顶上方/底部下方 → 空白，不处理
    if (Math.abs(x - h.getXPx()) > halfBar) {
      return;
    }
    if (y < h.getYPx() || y > vph.contentBottom()) {
      return;
    }
    const s: Session = this.displaySessions[idx];
    let valueText: string;
    let valueColor: ResourceColor;
    if (this.mode === 1) {
      valueText = `+${s.endBattery - s.startBattery}%`;
      valueColor = $r('app.color.charge_color');
    } else {
      valueText = `-${CalcUtil.consumption(s)}%`;
      valueColor = s.type === SessionType.IDLE ? $r('app.color.idle_color') : $r('app.color.usage_color');
    }
    const timeText: string = s.isCompleted()
      ? `${DateTimeUtil.formatDateTime(s.startTime)} ~ ${DateTimeUtil.formatDateTime(s.endTime)}`
      : `${DateTimeUtil.formatDateTime(s.startTime)} ~ 进行中`;
    this.onTap({
      tag: this.tag,
      valueText: valueText,
      valueColor: valueColor,
      timeText: timeText,
      note: s.note,
      x: h.getXPx(),
      y: h.getYPx()
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      MpBarChart({ model: this.model })
        .width('100%')
        .height(180)
    }
    .width('100%')
    .height(180)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down && event.touches && event.touches.length > 0) {
        this.downX = event.touches[0].x;
        this.downY = event.touches[0].y;
      } else if (event.type === TouchType.Up) {
        if (this.downX >= 0) {
          this.handleChartTapAt(this.downX, this.downY);
          this.downX = -1;
          this.downY = -1;
        }
      }
    })
  }
}
