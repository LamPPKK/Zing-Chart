@Entry
@Component
struct PlayerCard {
  @LocalStorageProp('title') title: string = '#zingChart';
  @LocalStorageProp('artist') artist: string = '';
  @LocalStorageProp('isPlaying') isPlaying: boolean = false;
  @LocalStorageProp('positionMs') positionMs: number = 0;
  @LocalStorageProp('durationMs') durationMs: number = 0;

  private send(action: string): void {
    postCardAction(this, {
      action: 'message',
      params: { action: action }
    });
  }

  build() {
    Row({ space: 18 }) {
      Column() {
        SymbolGlyph($r('sys.symbol.waveform'))
          .fontSize(30)
          .fontColor(['#121212'])
      }
      .width(72)
      .height(72)
      .justifyContent(FlexAlign.Center)
      .linearGradient({
        angle: 45,
        colors: [['#FF6B5E', 0.0], ['#DAFF48', 1.0]]
      })
      .borderRadius(22)

      Column({ space: 7 }) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF7F0')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.artist.length > 0 ? this.artist : $r('app.string.form_no_song'))
          .fontSize(14)
          .fontColor('#B7B3AC')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Progress({ value: this.durationMs > 0 ? this.positionMs : 0,
          total: this.durationMs > 0 ? this.durationMs : 1, type: ProgressType.Linear })
          .color('#FF6B5E')
          .backgroundColor('#3B3A38')
          .height(4)
        Row({ space: 16 }) {
          SymbolButton({ symbol: $r('sys.symbol.backward_end_fill') })
            .accessibilityText($r('app.string.form_previous'))
            .onClick(() => this.send('previous'))
          SymbolButton({
            symbol: this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill')
          })
            .accessibilityText(this.isPlaying ? $r('app.string.form_pause') : $r('app.string.form_play'))
            .onClick(() => this.send('togglePlayPause'))
          SymbolButton({ symbol: $r('sys.symbol.forward_end_fill') })
            .accessibilityText($r('app.string.form_next'))
            .onClick(() => this.send('next'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(22)
    .backgroundColor('#121212')
  }
}

@Component
struct SymbolButton {
  @Prop symbol: Resource;

  build() {
    Button() {
      SymbolGlyph(this.symbol).fontSize(24).fontColor(['#FFF7F0'])
    }
    .width(44)
    .height(44)
    .borderRadius(22)
    .backgroundColor('#252422')
  }
}
