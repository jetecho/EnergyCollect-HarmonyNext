import { LineChart as MpLineChart, LineChartModel, LineDataSet, LineData, EntryOhos, JArrayList, Mode, XAxisPosition, ILineDataSet, AxisBase, IAxisValueFormatter } from '@ohos/mpchart';
import { ChartPoint } from '../model/ChartPoint';
import { DateTimeUtil } from '../utils/DateTimeUtil';

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
  private model: LineChartModel = new LineChartModel();
  private timeFormatter: ChartTimeFormatter = new ChartTimeFormatter();

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
    // 均等 x 轴：x 取点序号，时间仅用于底部标签
    const values: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
    const times: number[] = [];
    for (let i = 0; i < this.points.length; i++) {
      values.add(new EntryOhos(i, this.points[i].value));
      times.push(this.points[i].time);
    }
    const set: LineDataSet = new LineDataSet(values, '');
    set.setColorByColor(0xFF0A59F7);
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

  build() {
    Column() {
      MpLineChart({ model: this.model })
        .width('100%')
        .height(180)
    }
    .width('100%')
  }
}
