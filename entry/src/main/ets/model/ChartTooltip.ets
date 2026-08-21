/** 图表悬浮信息数据：由图表组件命中数据点后上抛，HistoryTab 负责渲染与隐藏 */
export interface ChartTooltipData {
  /** 标识来源图表：'trend' | 'drain' | 'charge' */
  tag: string;
  valueText: string;
  valueColor: ResourceColor;
  timeText: string;
  note: string;
  /** 数据点在图表内的坐标（vp，用于悬浮定位） */
  x: number;
  y: number;
}
