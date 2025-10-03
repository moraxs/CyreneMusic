import 'package:flutter/foundation.dart';
import '../models/track.dart';

/// 播放队列来源
enum QueueSource {
  none,        // 无队列
  favorites,   // 收藏列表
  history,     // 播放历史
  search,      // 搜索结果
  toplist,     // 排行榜
}

/// 播放队列服务 - 管理当前播放列表
class PlaylistQueueService extends ChangeNotifier {
  static final PlaylistQueueService _instance = PlaylistQueueService._internal();
  factory PlaylistQueueService() => _instance;
  PlaylistQueueService._internal();

  List<Track> _queue = [];
  int _currentIndex = -1;
  QueueSource _source = QueueSource.none;

  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  QueueSource get source => _source;
  bool get hasQueue => _queue.isNotEmpty;

  /// 设置播放队列
  void setQueue(List<Track> tracks, int startIndex, QueueSource source) {
    _queue = List.from(tracks);
    _currentIndex = startIndex;
    _source = source;
    
    print('🎵 [PlaylistQueueService] 设置播放队列: ${_queue.length} 首歌曲, 来源: ${source.name}, 当前索引: $startIndex');
    notifyListeners();
  }

  /// 播放指定曲目（更新当前索引）
  void playTrack(Track track) {
    final index = _queue.indexWhere(
      (t) => t.id.toString() == track.id.toString() && t.source == track.source
    );
    
    if (index != -1) {
      _currentIndex = index;
      print('🎵 [PlaylistQueueService] 切换到队列中的歌曲: ${track.name}, 索引: $index');
      notifyListeners();
    } else {
      print('⚠️ [PlaylistQueueService] 歌曲不在当前队列中: ${track.name}');
    }
  }

  /// 获取下一首歌曲
  Track? getNext() {
    if (_queue.isEmpty) {
      return null;
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex < _queue.length) {
      _currentIndex = nextIndex;
      print('⏭️ [PlaylistQueueService] 下一首: ${_queue[_currentIndex].name}');
      notifyListeners();
      return _queue[_currentIndex];
    }

    print('⚠️ [PlaylistQueueService] 已经是队列最后一首');
    return null;
  }

  /// 获取上一首歌曲
  Track? getPrevious() {
    if (_queue.isEmpty) {
      return null;
    }

    final prevIndex = _currentIndex - 1;
    if (prevIndex >= 0) {
      _currentIndex = prevIndex;
      print('⏮️ [PlaylistQueueService] 上一首: ${_queue[_currentIndex].name}');
      notifyListeners();
      return _queue[_currentIndex];
    }

    print('⚠️ [PlaylistQueueService] 已经是队列第一首');
    return null;
  }

  /// 检查是否有下一首
  bool get hasNext => _queue.isNotEmpty && _currentIndex < _queue.length - 1;

  /// 检查是否有上一首
  bool get hasPrevious => _queue.isNotEmpty && _currentIndex > 0;

  /// 获取随机歌曲（用于随机播放）
  Track? getRandomTrack() {
    if (_queue.isEmpty) {
      return null;
    }

    final random = DateTime.now().microsecondsSinceEpoch % _queue.length;
    _currentIndex = random;
    print('🔀 [PlaylistQueueService] 随机播放: ${_queue[_currentIndex].name}');
    notifyListeners();
    return _queue[_currentIndex];
  }

  /// 清空播放队列
  void clear() {
    _queue.clear();
    _currentIndex = -1;
    _source = QueueSource.none;
    print('🗑️ [PlaylistQueueService] 清空播放队列');
    notifyListeners();
  }

  /// 获取队列信息（用于显示）
  String getQueueInfo() {
    if (_queue.isEmpty) {
      return '无播放队列';
    }
    return '${_source.name} (${_currentIndex + 1}/${_queue.length})';
  }
}

