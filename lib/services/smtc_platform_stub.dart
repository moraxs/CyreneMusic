/// SMTC 桩实现（Web 平台）

// Web 平台的空实现
class SMTCWindows {
  SMTCWindows({
    dynamic metadata,
    dynamic timeline,
    dynamic config,
  });

  Stream<PressedButton> get buttonPressStream => const Stream.empty();
  
  void enableSmtc() {}
  void disableSmtc() {}
  void setPlaybackStatus(dynamic status) {}
  void updateMetadata(dynamic metadata) {}
  void updateTimeline(dynamic timeline) {}
  void dispose() {}
}

class MusicMetadata {
  const MusicMetadata({
    required this.title,
    required this.album,
    required this.albumArtist,
    required this.artist,
    required this.thumbnail,
  });

  final String title;
  final String album;
  final String albumArtist;
  final String artist;
  final String thumbnail;
}

class PlaybackTimeline {
  const PlaybackTimeline({
    required this.startTimeMs,
    required this.endTimeMs,
    required this.positionMs,
    required this.minSeekTimeMs,
    required this.maxSeekTimeMs,
  });

  final int startTimeMs;
  final int endTimeMs;
  final int positionMs;
  final int minSeekTimeMs;
  final int maxSeekTimeMs;
}

class SMTCConfig {
  const SMTCConfig({
    required this.fastForwardEnabled,
    required this.nextEnabled,
    required this.pauseEnabled,
    required this.playEnabled,
    required this.rewindEnabled,
    required this.prevEnabled,
    required this.stopEnabled,
  });

  final bool fastForwardEnabled;
  final bool nextEnabled;
  final bool pauseEnabled;
  final bool playEnabled;
  final bool rewindEnabled;
  final bool prevEnabled;
  final bool stopEnabled;
}

enum PlaybackStatus {
  closed,
  changing,
  stopped,
  playing,
  paused,
}

enum PressedButton {
  play,
  pause,
  stop,
  next,
  previous,
  fastForward,
  rewind,
  channelUp,
  channelDown,
}

