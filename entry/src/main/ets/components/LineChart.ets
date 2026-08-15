import { ChartPoint } from '../model/ChartPoint';

@Component
export struct LineChart {
  @Prop @Watch('scheduleRedraw') points: ChartPoint[];
  @StorageProp('systemColorMode') @Watch('scheduleRedraw') sysMode: number = 0;
  @State canvasWidth: number = 300;
  private canvasHeight: number = 180;
  private isReady: boolean = false;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private readonly padL: number = 6;
  private readonly padR: number = 6;
  private readonly padT: number = 14;
  private readonly padB: number = 22;

  private strokeColorStr(): string {
    return this.sysMode === 1 ? '#5C86FF' : '#0A59F7';
  }

  private gridColorStr(): string {
    return this.sysMode === 1 ? '#2A2A2A' : '#E5E8EE';
  }

  private textColorStr(): string {
    return this.sysMode === 1 ? '#6E6E6E' : '#99A0B3';
  }

  scheduleRedraw(): void {
    if (this.isReady) {
      this.draw();
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height(this.canvasHeight)
      .onAreaChange((oldValue: Area, newValue: Area) => {
        const w: Length = newValue.width;
        let widthNum: number = 0;
        if (typeof w === 'number') {
          widthNum = w;
        } else if (typeof w === 'string') {
          widthNum = parseFloat(w);
        }
        if (widthNum > 0) {
          this.canvasWidth = widthNum;
        }
        if (this.isReady) {
          this.draw();
        }
      })
      .onReady(() => {
        this.isReady = true;
        this.draw();
      })
  }

  private draw(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const w: number = this.canvasWidth;
    const h: number = this.canvasHeight;
    ctx.clearRect(0, 0, w, h);

    const plotL: number = this.padL;
    const plotR: number = w - this.padR;
    const plotT: number = this.padT;
    const plotB: number = h - this.padB;
    const plotW: number = plotR - plotL;
    const plotH: number = plotB - plotT;

    ctx.lineWidth = 1;
    ctx.strokeStyle = this.gridColorStr();
    ctx.font = '10px sans-serif';
    ctx.fillStyle = this.textColorStr();
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';

    const gridValues: number[] = [0, 25, 50, 75, 100];
    for (let i: number = 0; i < gridValues.length; i++) {
      const v: number = gridValues[i];
      const y: number = plotT + (1 - v / 100) * plotH;
      ctx.beginPath();
      ctx.moveTo(plotL, y);
      ctx.lineTo(plotR, y);
      ctx.stroke();
      ctx.fillText(`${v}`, plotL + 2, y - 7);
    }

    const n: number = this.points.length;
    if (n === 0) {
      ctx.fillStyle = this.textColorStr();
      ctx.textAlign = 'center';
      ctx.fillText('--', plotL + plotW / 2, plotT + plotH / 2);
      return;
    }

    const xAt = (i: number): number => {
      if (n <= 1) {
        return plotL + plotW / 2;
      }
      return plotL + (i / (n - 1)) * plotW;
    };
    const yAt = (val: number): number => plotT + (1 - val / 100) * plotH;

    if (n >= 2) {
      ctx.beginPath();
      ctx.moveTo(xAt(0), plotB);
      for (let i: number = 0; i < n; i++) {
        ctx.lineTo(xAt(i), yAt(this.points[i].value));
      }
      ctx.lineTo(xAt(n - 1), plotB);
      ctx.closePath();
      ctx.fillStyle = this.toRgba(this.strokeColorStr(), 0.15);
      ctx.fill();

      ctx.beginPath();
      ctx.lineWidth = 2.2;
      ctx.strokeStyle = this.strokeColorStr();
      ctx.lineJoin = 'round';
      ctx.lineCap = 'round';
      ctx.moveTo(xAt(0), yAt(this.points[0].value));
      for (let i: number = 1; i < n; i++) {
        ctx.lineTo(xAt(i), yAt(this.points[i].value));
      }
      ctx.stroke();
    }

    ctx.fillStyle = this.strokeColorStr();
    for (let i: number = 0; i < n; i++) {
      ctx.beginPath();
      ctx.arc(xAt(i), yAt(this.points[i].value), 2.4, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.fillStyle = this.textColorStr();
    ctx.font = '10px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    const labelIdxs: number[] = n <= 1 ? [0] : [0, Math.floor((n - 1) / 2), n - 1];
    for (let k: number = 0; k < labelIdxs.length; k++) {
      const idx: number = labelIdxs[k];
      ctx.fillText(this.points[idx].label, xAt(idx), plotB + 6);
    }
  }

  private toRgba(hex: string, alpha: number): string {
    if (hex === undefined || hex === null || hex.length < 7) {
      return `rgba(10,89,247,${alpha})`;
    }
    const h: string = hex.replace('#', '');
    const r: number = parseInt(h.substring(0, 2), 16);
    const g: number = parseInt(h.substring(2, 4), 16);
    const b: number = parseInt(h.substring(4, 6), 16);
    return `rgba(${r},${g},${b},${alpha})`;
  }
}
