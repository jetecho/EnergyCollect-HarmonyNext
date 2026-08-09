import { LineChart as MpLineChart, LineChartModel, LineDataSet, LineData, EntryOhos, JArrayList, Mode, XAxisPosition, ILineDataSet } from '@ohos/mpchart';
import { ChartPoint } from '../model/ChartPoint';

@Component
export struct TrendChart {
  @Prop @Watch('refresh') points: ChartPoint[] = [];
  private model: LineChartModel = new LineChartModel();

  aboutToAppear(): void {
    this.setupModel();
    this.refresh();
  }

  private setupModel(): void {
    this.model.animateX(400);
    this.model.getDescription()?.setEnabled(false);
    this.model.getLegend()?.setEnabled(false);
    this.model.getXAxis()?.setPosition(XAxisPosition.BOTTOM);
    this.model.getAxisRight()?.setEnabled(false);
    this.model.getAxisLeft()?.setAxisMinimum(0);
    this.model.getAxisLeft()?.setAxisMaximum(100);
    this.model.setScaleEnabled(false);
    this.model.setDragXEnabled(true);
  }

  refresh(): void {
    const values: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
    for (let i = 0; i < this.points.length; i++) {
      values.add(new EntryOhos(i, this.points[i].value));
    }
    const set: LineDataSet = new LineDataSet(values, '');
    set.setColorByColor(0xFF0A59F7);
    set.setLineWidth(2);
    set.setMode(Mode.LINEAR);
    set.setCircleColor(0xFF0A59F7);
    set.setDrawValues(false);
    const list: JArrayList<ILineDataSet> = new JArrayList<ILineDataSet>();
    list.add(set);
    const data: LineData = new LineData(list);
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
