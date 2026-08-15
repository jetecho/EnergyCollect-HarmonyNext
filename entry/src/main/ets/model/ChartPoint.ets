export class ChartPoint {
  time: number = 0;
  value: number = 0;
  label: string = '';

  constructor(time: number, value: number, label: string) {
    this.time = time;
    this.value = value;
    this.label = label;
  }
}
