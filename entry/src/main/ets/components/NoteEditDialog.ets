@CustomDialog
export struct NoteEditDialog {
  controller: CustomDialogController;
  initialNote: string = '';
  onConfirm: (note: string) => void = () => {};
  @State note: string = '';

  aboutToAppear(): void {
    this.note = this.initialNote;
  }

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.dialog_note_edit_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

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
        Button($r('app.string.action_save'))
          .type(ButtonType.Normal)
          .borderRadius(12)
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.brand'))
          .fontColor($r('app.color.text_on_brand'))
          .onClick(() => {
            this.onConfirm(this.note);
            this.controller.close();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
  }
}
