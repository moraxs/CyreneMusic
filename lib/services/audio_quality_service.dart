import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_detail.dart';

/// 音质服务 - 管理用户选择的音质
class AudioQualityService extends ChangeNotifier {
  static final AudioQualityService _instance = AudioQualityService._internal();
  factory AudioQualityService() => _instance;
  AudioQualityService._internal() {
    _loadQuality();
  }

  AudioQuality _currentQuality = AudioQuality.exhigh; // 默认极高音质
  AudioQuality get currentQuality => _currentQuality;

  static const String _qualityKey = 'audio_quality';

  /// 加载音质设置
  Future<void> _loadQuality() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final qualityString = prefs.getString(_qualityKey);
      
      if (qualityString != null) {
        _currentQuality = AudioQuality.values.firstWhere(
          (e) => e.toString() == qualityString,
          orElse: () => AudioQuality.exhigh,
        );
      }
      
      print('🎵 [AudioQualityService] 加载音质设置: ${getQualityName()}');
    } catch (e) {
      print('❌ [AudioQualityService] 加载音质设置失败: $e');
      _currentQuality = AudioQuality.exhigh;
    }
    notifyListeners();
  }

  /// 设置音质
  Future<void> setQuality(AudioQuality quality) async {
    if (_currentQuality == quality) return;

    _currentQuality = quality;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_qualityKey, quality.toString());
      print('🎵 [AudioQualityService] 音质已设置: ${getQualityName()}');
    } catch (e) {
      print('❌ [AudioQualityService] 保存音质设置失败: $e');
    }
    
    notifyListeners();
  }

  /// 获取音质名称
  String getQualityName() {
    switch (_currentQuality) {
      case AudioQuality.standard:
        return '标准音质';
      case AudioQuality.exhigh:
        return '极高音质';
      case AudioQuality.lossless:
        return '无损音质';
      default:
        return '极高音质';
    }
  }

  /// 获取音质描述
  String getQualityDescription() {
    switch (_currentQuality) {
      case AudioQuality.standard:
        return '128kbps，节省流量';
      case AudioQuality.exhigh:
        return '320kbps，推荐';
      case AudioQuality.lossless:
        return 'FLAC，音质最佳';
      default:
        return '320kbps，推荐';
    }
  }

  /// 获取QQ音乐的音质键名
  String getQQMusicQualityKey() {
    switch (_currentQuality) {
      case AudioQuality.standard:
        return '128';
      case AudioQuality.exhigh:
        return '320';
      case AudioQuality.lossless:
        return 'flac';
      default:
        return '320';
    }
  }

  /// 从QQ音乐的music_urls中选择最佳可用音质
  /// 优先选择用户设定的音质，如果不存在则降级选择
  String? selectBestQQMusicUrl(Map<String, dynamic> musicUrls) {
    final preferredKey = getQQMusicQualityKey();
    
    // 音质优先级（从高到低）
    final qualityPriority = ['flac', '320', '128'];
    
    // 首先尝试用户选择的音质
    if (musicUrls.containsKey(preferredKey)) {
      final urlData = musicUrls[preferredKey];
      if (urlData is Map && urlData['url'] != null && urlData['url'].isNotEmpty) {
        print('🎵 [AudioQualityService] QQ音乐使用音质: $preferredKey');
        return urlData['url'];
      }
    }
    
    // 如果用户选择的音质不可用，按优先级降级
    for (final key in qualityPriority) {
      if (musicUrls.containsKey(key)) {
        final urlData = musicUrls[key];
        if (urlData is Map && urlData['url'] != null && urlData['url'].isNotEmpty) {
          print('⚠️ [AudioQualityService] QQ音乐音质降级到: $key');
          return urlData['url'];
        }
      }
    }
    
    print('❌ [AudioQualityService] QQ音乐无可用音质');
    return null;
  }
}

