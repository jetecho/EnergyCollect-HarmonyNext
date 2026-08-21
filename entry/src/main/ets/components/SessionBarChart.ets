import { BarChart as MpBarChart, BarChartModel, BarDataSet, BarData, BarEntry, JArrayList, XAxisPosition, IBarDataSet, AxisBase, IAxisValueFormatter } from '@ohos/mpchart';
import { Session } from '../model/Session';
import { SessionType } from '../model/SessionType';
import { CalcUtil } from '../utils/CalcUtil';
import { DateTimeUtil } from '../utils/DateTimeUtil';

const COLOR_CHARGE: number = 0xFF1FA978;
const COLOR_USAGE: number = 0xFFE84026;
const COLOR_IDLE: number = 0xFFF08200;

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
  private model: BarChartModel = new BarChartModel();
  private timeFormatter: ChartTimeFormatter = new ChartTimeFormatter();

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
    // 均等 x 轴：柱子按序号等间距排列，时间仅用于底部标签
    const values: JArrayList<BarEntry> = new JArrayList<BarEntry>();
    const colors: number[] = [];
    const times: number[] = [];
    for (let i = 0; i < list.length; i++) {
      const s: Session = list[i];
      const y: number = this.mode === 1 ? s.endBattery - s.startBattery : CalcUtil.consumption(s);
      values.add(new BarEntry(i, y));
      times.push(s.startTime);
      if (this.mode === 1) {
        colors.push(COLOR_CHARGE);
      } else if (s.type === SessionType.IDLE) {
        colors.push(COLOR_IDLE);
      } else {
        colors.push(COLOR_USAGE);
      }
    }
    const set: BarDataSet = new BarDataSet(values, '');
    set.setColorsByArr(colors);
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

  build() {
    Column() {
      MpBarChart({ model: this.model })
        .width('100%')
        .height(180)
    }
    .width('100%')
  }
}
