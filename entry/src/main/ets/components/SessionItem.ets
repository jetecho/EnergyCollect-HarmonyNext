import { Session } from '../model/Session';
import { SessionType } from '../model/SessionType';
import { iconToResource } from '../model/Device';
import { CalcUtil } from '../utils/CalcUtil';
import { DateTimeUtil } from '../utils/DateTimeUtil';
import { PAD_ROW, CORNER_MD } from '../utils/DesignTokens';

@Component
export struct SessionItem {
  @Prop session: Session;
  @Prop deviceName: string;
  @Prop deviceIcon: string;
  onEditNote: (session: Session) => void = () => {};

  private typeColor(): ResourceColor {
    if (this.session.type === SessionType.CHARGING) {
      return $r('app.color.charge_color');
    }
    return this.session.type === SessionType.USAGE ? $r('app.color.usage_color') : $r('app.color.idle_color');
  }

  private typeBg(): ResourceColor {
    if (this.session.type === SessionType.CHARGING) {
      return $r('app.color.charge_bg');
    }
    return this.session.type === SessionType.USAGE ? $r('app.color.usage_bg') : $r('app.color.idle_bg');
  }

  private typeLabel(): ResourceStr {
    if (this.session.type === SessionType.CHARGING) {
      return $r('app.string.session_type_charge');
    }
    return this.session.type === SessionType.USAGE ? $r('app.string.session_type_usage') : $r('app.string.session_type_idle');
  }

  build() {
    Row({ space: 12 }) {
      Stack() {
        Text('')
          .width(44)
          .height(44)
          .backgroundColor(this.typeBg())
          .borderRadius(22)
        Image(iconToResource(this.deviceIcon))
          .width(24)
          .height(24)
          .fillColor(this.typeColor())
      }
      .width(44)
      .height(44)

      Column({ space: 5 }) {
        Text(this.deviceName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row({ space: 6 }) {
          Text(this.typeLabel())
            .fontSize(11)
            .fontColor(this.typeColor())
            .backgroundColor(this.typeBg())
            .borderRadius(4)
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          Blank()
          if (this.session.isCompleted()) {
            Text(DateTimeUtil.formatDuration(this.session.endTime - this.session.startTime))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')

        Row({ space: 6 }) {
          Text(DateTimeUtil.formatDateTimeMs(this.session.startTime))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
          if (this.session.isCompleted()) {
            Text('→')
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
            Text(DateTimeUtil.formatDateTimeMs(this.session.endTime))
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .width('100%')

        this.BatteryRow()

        if (this.session.note.length > 0) {
          Text(this.session.note)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(PAD_ROW)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(CORNER_MD)
    .alignItems(VerticalAlign.Top)
    .onClick(() => {
      this.onEditNote(this.session);
    })
  }

  @Builder
  BatteryRow() {
    Row({ space: 6 }) {
      Text(`${this.session.startBattery}%`)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
      if (this.session.isCompleted()) {
        Text('→')
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
        Text(`${this.session.endBattery}%`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Text(this.consumptionText())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.consumptionColor())
      } else {
        Text($r('app.string.session_in_progress'))
          .fontSize(12)
          .fontColor(this.typeColor())
          .fontWeight(FontWeight.Medium)
      }
    }
    .width('100%')
  }

  private consumptionText(): string {
    const c: number = CalcUtil.consumption(this.session);
    if (c > 0) {
      return `(-${c}%)`;
    }
    if (c < 0) {
      return `(+${-c}%)`;
    }
    return '(0%)';
  }

  private consumptionColor(): ResourceColor {
    const c: number = CalcUtil.consumption(this.session);
    if (c > 0) {
      return $r('app.color.danger');
    }
    return $r('app.color.success');
  }
}
