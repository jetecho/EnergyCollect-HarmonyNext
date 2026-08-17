import { BarChart as MpBarChart, BarChartModel, BarDataSet, BarData, BarEntry, JArrayList, XAxisPosition, IBarDataSet, AxisBase, IAxisValueFormatter } from '@ohos/mpchart';
import { Session } from '../model/Session';
import { SessionType } from '../model/SessionType';
import { CalcUtil } from '../utils/CalcUtil';
import { DateTimeUtil } from '../utils/DateTimeUtil';

class ChartTimeFormatter implements IAxisValueFormatter {
  getFormattedValue(value: number, axis: AxisBase): string {
    return DateTimeUtil.formatAxisTime(value);
  }
}

@Component
export struct SessionBarChart {
  @Prop @Watch('refresh') sessions: Session[] = [];
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
    this.model.getXAxis()?.setLabelCount(4, true);
    this.model.getXAxis()?.setGranularity(1);
    this.model.getAxisRight()?.setEnabled(false);
    this.model.getAxisLeft()?.setDrawGridLines(true);
    this.model.setScaleEnabled(false);
    this.model.setDragXEnabled(true);
    this.model.setHighlightPerTapEnabled(false);
    this.model.setHighlightPerDragEnabled(false);
    this.model.setDrawValueAboveBar(true);
  }

  refresh(): void {
    const completed: Session[] = [];
    for (const s of this.sessions) {
      if (s.isCompleted()) {
        completed.push(s);
      }
    }
    completed.sort((a: Session, b: Session): number => a.startTime - b.startTime);
    const values: JArrayList<BarEntry> = new JArrayList<BarEntry>();
    const colors: number[] = [];
    let minTime: number = -1;
    let maxTime: number = -1;
    for (let i = 0; i < completed.length; i++) {
      const s: Session = completed[i];
      const x: number = s.startTime;
      if (minTime < 0 || x < minTime) {
        minTime = x;
      }
      if (maxTime < 0 || x > maxTime) {
        maxTime = x;
      }
      if (s.type === SessionType.CHARGING) {
        values.add(new BarEntry(x, s.endBattery - s.startBattery));
        colors.push(0xFF1FA978);
      } else if (s.type === SessionType.IDLE) {
        values.add(new BarEntry(x, CalcUtil.consumption(s)));
        colors.push(0xFFF08200);
      } else {
        values.add(new BarEntry(x, CalcUtil.consumption(s)));
        colors.push(0xFFE84026);
      }
    }
    const set: BarDataSet = new BarDataSet(values, '');
    set.setColorsByArr(colors);
    set.setDrawValues(true);
    const list: JArrayList<IBarDataSet> = new JArrayList<IBarDataSet>();
    list.add(set);
    const data: BarData = new BarData(list);
    // x 轴为时间戳，柱宽按数据时间跨度折算，避免柱子过细或过宽
    let barWidth: number = 6 * 60 * 60 * 1000;
    if (completed.length > 1 && maxTime > minTime) {
      barWidth = (maxTime - minTime) / completed.length * 0.6;
      const minWidth: number = 60 * 60 * 1000;
      const maxWidth: number = 7 * 24 * 60 * 60 * 1000;
      if (barWidth < minWidth) {
        barWidth = minWidth;
      }
      if (barWidth > maxWidth) {
        barWidth = maxWidth;
      }
    }
    data.setBarWidth(barWidth);
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
