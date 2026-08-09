@CustomDialog
export struct BatteryInputDialog {
  controller: CustomDialogController;
  title: ResourceStr = $r('app.string.battery_start_title');
  maxValue: number = 100;
  minValue: number = 0;
  defaultValue: number = -1;
  showRange: boolean = false;
  rangeMax: number = 0;
  rangeDefault: number = -1;
  showNote: boolean = true;
  onConfirm: (battery: number, note: string, range: number) => void = () => {};
  onInvalid: () => void = () => {};
  @State battery: number = 100;
  @State range: number = 0;
  @State note: string = '';

  aboutToAppear(): void {
    if (this.defaultValue >= 0) {
      this.battery = this.defaultValue;
    } else if (this.minValue > 0) {
      this.battery = this.maxValue < 100 ? this.maxValue : 100;
    } else if (this.maxValue > 0 && this.maxValue < 100) {
      this.battery = this.maxValue;
    } else {
      this.battery = 100;
    }
    if (this.showRange) {
      this.range = this.rangeDefault >= 0 ? this.rangeDefault : Math.round((this.rangeMax > 0 ? this.rangeMax : 1000) / 2);
    }
  }

  build() {
    Column({ space: 16 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Column({ space: 4 }) {
        Row() {
          Text(`${this.battery}`)
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand'))
          Text('%')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand'))
            .margin({ bottom: 6 })
        }
        .alignItems(VerticalAlign.Bottom)

        Text($r('app.string.battery_label'))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Slider({
        value: this.battery,
        min: this.minValue,
        max: this.maxValue > 0 && this.maxValue < 100 ? this.maxValue : 100,
        step: 1,
        style: SliderStyle.OutSet
      })
        .blockColor($r('app.color.brand'))
        .selectedColor($r('app.color.brand'))
        .trackColor($r('app.color.divider'))
        .width('100%')
        .onChange((value: number, mode: SliderChangeMode) => {
          this.battery = Math.round(value);
          if (this.showRange && this.rangeMax > 0) {
            this.range = Math.round(this.battery * this.rangeMax / 100);
          }
        })

      if (this.showRange) {
        Column({ space: 4 }) {
          Row() {
            Text(`${this.range}`)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.charge_color'))
            Text('km')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.charge_color'))
              .margin({ bottom: 4 })
          }
          .alignItems(VerticalAlign.Bottom)

          Text($r('app.string.session_range_label'))
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Slider({
          value: this.range,
          min: 0,
          max: this.rangeMax > 0 ? this.rangeMax : 1000,
          step: 1,
          style: SliderStyle.OutSet
        })
          .blockColor($r('app.color.charge_color'))
          .selectedColor($r('app.color.charge_color'))
          .trackColor($r('app.color.divider'))
          .width('100%')
          .onChange((value: number, mode: SliderChangeMode) => {
            this.range = Math.round(value);
          })
      }

      if (this.showNote) {
        Column({ space: 6 }) {
          Text($r('app.string.battery_note_label'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          TextInput({
            text: this.note,
            placeholder: $r('app.string.battery_note_placeholder')
          })
            .fontSize(14)
            .backgroundColor($r('app.color.bg_primary'))
            .borderRadius(10)
            .height(44)
            .onChange((v: string) => {
              this.note = v;
            })
        }
        .width('100%')
      }

      Row({ space: 12 }) {
        Button($r('app.string.action_cancel'))
          .type(ButtonType.Normal)
          .borderRadius(12)
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.bg_primary'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.controller.close();
          })
        Button($r('app.string.action_confirm'))
          .type(ButtonType.Normal)
          .borderRadius(12)
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.brand'))
          .fontColor($r('app.color.text_on_brand'))
          .onClick(() => {
            if (this.minValue > 0 && this.battery < this.minValue) {
              this.onInvalid();
              return;
            }
            if (this.maxValue > 0 && this.maxValue < 100 && this.battery > this.maxValue) {
              this.onInvalid();
              return;
            }
            this.onConfirm(this.battery, this.note, this.range);
            this.controller.close();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
  }
}
