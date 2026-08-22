import { LineChart as MpLineChart, LineChartModel, LineDataSet, LineData, EntryOhos, JArrayList, Mode, XAxisPosition, ILineDataSet, AxisBase, IAxisValueFormatter, Highlight } from '@ohos/mpchart';
import { ChartPoint } from '../model/ChartPoint';
import { DateTimeUtil } from '../utils/DateTimeUtil';
import { ChartTooltipData } from '../model/ChartTooltip';
import { Immersive } from '../utils/Immersive';

/**
 * 均等 x 轴下的时间标签：x 值为点序号（0,1,2...），映射回真实时间展示
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
export struct TrendChart {
  @Prop @Watch('refresh') points: ChartPoint[] = [];
  /** 来源标识 */
  @Prop tag: string = '';
  /** 深浅色跟随应用设置/系统配置，变化时重绘配色 */
  @StorageProp('colorMode') @Watch('refresh') colorMode: number = -1;
  @StorageProp('systemColorMode') @Watch('refresh') systemColorMode: number = -1;
  /** 命中数据点时上抛悬浮信息 */
  onTap: (data: ChartTooltipData) => void = (): void => {};
  private model: LineChartModel = new LineChartModel();
  private timeFormatter: ChartTimeFormatter = new ChartTimeFormatter();
  private downX: number = -1;
  private downY: number = -1;

  aboutToAppear(): void {
    this.setupModel();
    this.refresh();
  }

  private setupModel(): void {
    this.model.animateX(400);
    this.model.getDescription()?.setEnabled(false);
    this.model.getLegend()?.setEnabled(false);
    this.model.getXAxis()?.setPosition(XAxisPosition.BOTTOM);
    this.model.getXAxis()?.setDrawGridLines(false);
    this.model.getXAxis()?.setValueFormatter(this.timeFormatter);
    this.model.getXAxis()?.setLabelCount(4, true);
    this.model.getXAxis()?.setGranularity(1);
    this.model.getAxisRight()?.setEnabled(false);
    this.model.getAxisLeft()?.setAxisMinimum(0);
    this.model.getAxisLeft()?.setAxisMaximum(100);
    this.model.getAxisLeft()?.setDrawGridLines(true);
    this.model.setScaleEnabled(false);
    this.model.setDragXEnabled(true);
    this.model.setHighlightPerTapEnabled(false);
    this.model.setHighlightPerDragEnabled(false);
  }

  refresh(): void {
    const isDark: boolean = Immersive.isDarkMode(this.colorMode, this.systemColorMode);
    this.applyPalette(isDark);
    // 均等 x 轴：x 取点序号，时间仅用于底部标签
    const values: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
    const times: number[] = [];
    for (let i: number = 0; i < this.points.length; i++) {
      values.add(new EntryOhos(i, this.points[i].value));
      times.push(this.points[i].time);
    }
    const set: LineDataSet = new LineDataSet(values, '');
    // 线色与 color.json 的 brand 保持同步（浅 #0A59F7 / 深 #3D6CFF）
    set.setColorByColor(isDark ? 0xFF3D6CFF : 0xFF0A59F7);
    set.setLineWidth(2);
    // 直线折线（不去平滑），转折点清晰
    set.setMode(Mode.LINEAR);
    set.setDrawCircles(false);
    set.setDrawValues(false);
    const list: JArrayList<ILineDataSet> = new JArrayList<ILineDataSet>();
    list.add(set);
    const data: LineData = new LineData(list);
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

  /** 按坐标判断是否命中数据点（距离阈值），命中则上抛悬浮信息 */
  private handleChartTapAt(x: number, y: number): void {
    const h: Highlight | null = this.model.getHighlightByTouchPoint(x, y);
    if (h === null) {
      return;
    }
    // 点击位置与数据点像素位置的距离，超过阈值视为空白，不处理
    const dx: number = x - h.getXPx();
    const dy: number = y - h.getYPx();
    if (dx * dx + dy * dy > 30 * 30) {
      return;
    }
    const idx: number = Math.round(h.getX());
    if (idx < 0 || idx >= this.points.length) {
      return;
    }
    const pt: ChartPoint = this.points[idx];
    this.onTap({
      tag: this.tag,
      valueText: `${pt.value}%`,
      valueColor: $r('app.color.brand'),
      timeText: DateTimeUtil.formatDateTime(pt.time),
      note: pt.session !== null ? pt.session.note : '',
      x: h.getXPx(),
      y: h.getYPx()
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      MpLineChart({ model: this.model })
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
