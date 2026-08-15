@CustomDialog
export struct BatteryInputDialog {
  controller: CustomDialogController;
  title: ResourceStr = $r('app.string.battery_start_title');
  maxValue: number = 100;
  minValue: number = 0;
  defaultValue: number = -1;
  showNote: boolean = true;
  onConfirm: (battery: number, note: string) => void = () => {};
  onInvalid: () => void = () => {};
  @State battery: number = 100;
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
  }

  build() {
    Column({ space: 16 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Row() {
        Text($r('app.string.battery_label'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        Blank()
        Text(`${this.battery}%`)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand'))
      }
      .width('100%')

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
        })

      if (this.showNote) {
        Column({ space: 6 }) {
          Text($r('app.string.battery_note_label'))
            .fontSize(14)
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
          .backgroundColor($r('app.color.bg_primary'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.controller.close();
          })
        Button($r('app.string.action_confirm'))
          .type(ButtonType.Normal)
          .borderRadius(12)
          .layoutWeight(1)
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
            this.onConfirm(this.battery, this.note);
            this.controller.close();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(8)
  }
}
