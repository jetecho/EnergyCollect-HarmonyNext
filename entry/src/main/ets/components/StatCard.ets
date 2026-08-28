import { PAD_CARD, CORNER_MD } from '../utils/DesignTokens';

@Component
export struct StatCard {
  @Prop label: ResourceStr;
  @Prop value: string;
  @Prop unit: ResourceStr = '';
  @Prop valueColor: ResourceColor = $r('app.color.text_primary');

  build() {
    Column() {
      Text(this.label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row() {
        Text(this.value)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.valueColor)
          .maxLines(1)
        if (this.unit !== '') {
          Text(this.unit)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 3, bottom: 3 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(PAD_CARD)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(CORNER_MD)
  }
}
