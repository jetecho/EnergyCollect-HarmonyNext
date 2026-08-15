import { BarChart as MpBarChart, BarChartModel, BarDataSet, BarData, BarEntry, JArrayList, XAxisPosition, IBarDataSet } from '@ohos/mpchart';
import { Session } from '../model/Session';
import { SessionType } from '../model/SessionType';
import { CalcUtil } from '../utils/CalcUtil';

@Component
export struct SessionBarChart {
  @Prop @Watch('refresh') sessions: Session[] = [];
  private model: BarChartModel = new BarChartModel();

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
    for (let i = 0; i < completed.length; i++) {
      const s: Session = completed[i];
      if (s.type === SessionType.CHARGING) {
        values.add(new BarEntry(i, s.endBattery - s.startBattery));
        colors.push(0xFF1FA978);
      } else if (s.type === SessionType.IDLE) {
        values.add(new BarEntry(i, CalcUtil.consumption(s)));
        colors.push(0xFFF08200);
      } else {
        values.add(new BarEntry(i, CalcUtil.consumption(s)));
        colors.push(0xFFE84026);
      }
    }
    const set: BarDataSet = new BarDataSet(values, '');
    set.setColorsByArr(colors);
    set.setDrawValues(true);
    const list: JArrayList<IBarDataSet> = new JArrayList<IBarDataSet>();
    list.add(set);
    const data: BarData = new BarData(list);
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
