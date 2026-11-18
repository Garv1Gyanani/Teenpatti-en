/// Named sound effect cues bundled under `assets/audio/`.
enum AppAudioCue {
  uiTap('assets/audio/ui_tap.wav', defaultVolume: 0.35),
  cardDeal('assets/audio/card_deal.wav', defaultVolume: 0.55),
  cardFlip('assets/audio/card_flip.wav', defaultVolume: 0.65),
  chipToss('assets/audio/chip_toss.wav', defaultVolume: 0.65),
  turnChime('assets/audio/turn_chime.wav', defaultVolume: 0.55),
  timerWarn('assets/audio/timer_warn.wav', defaultVolume: 0.45),
  packFold('assets/audio/pack_fold.wav', defaultVolume: 0.55),
  winFlourish('assets/audio/win_flourish.wav', defaultVolume: 0.72),
  loseSoft('assets/audio/lose_soft.wav', defaultVolume: 0.55);

  const AppAudioCue(this.assetPath, {required this.defaultVolume});

  final String assetPath;
  final double defaultVolume;

  static const String ambientLoopAsset = 'assets/audio/jazz_lounge_loop.mp3';
}
