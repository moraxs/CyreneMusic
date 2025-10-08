import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/url_service.dart';
import '../services/playlist_service.dart';
import '../services/auth_service.dart';
import '../models/playlist.dart';
import '../models/track.dart';

/// 音乐平台枚举
enum MusicPlatform {
  netease('网易云音乐', '🎵'),
  qq('QQ音乐', '🎶');

  final String name;
  final String icon;
  const MusicPlatform(this.name, this.icon);
}

/// 从网易云/QQ音乐导入歌单对话框
class ImportPlaylistDialog {

  /// 解析网易云音乐歌单URL，提取歌单ID
  static String? _parseNeteasePlaylistId(String input) {
    final trimmedInput = input.trim();
    
    // 如果输入的是纯数字ID，直接返回
    if (RegExp(r'^\d+$').hasMatch(trimmedInput)) {
      return trimmedInput;
    }
    
    // 尝试从URL中解析ID
    try {
      // 支持的URL格式：
      // https://music.163.com/#/playlist?id=2154199263&creatorId=1408148628
      // https://music.163.com/playlist?id=2154199263&creatorId=1408148628
      // http://music.163.com/#/playlist?id=2154199263
      
      final uri = Uri.parse(trimmedInput);
      
      // 检查是否是网易云音乐域名
      if (!uri.host.contains('music.163.com')) {
        return null;
      }
      
      String? playlistId;
      
      // 首先检查主URL的查询参数
      playlistId = uri.queryParameters['id'];
      
      // 如果主URL没有，检查fragment中的查询参数
      if (playlistId == null && uri.fragment.isNotEmpty) {
        // fragment可能包含路径和查询参数，如：/playlist?id=2154199263&creatorId=1408148628
        final fragmentParts = uri.fragment.split('?');
        if (fragmentParts.length > 1) {
          // 解析fragment中的查询参数
          final fragmentQuery = fragmentParts[1];
          final fragmentParams = Uri.splitQueryString(fragmentQuery);
          playlistId = fragmentParams['id'];
        }
      }
      
      // 也尝试直接用正则表达式从整个URL中匹配ID
      if (playlistId == null) {
        final idMatch = RegExp(r'[?&]id=(\d+)').firstMatch(trimmedInput);
        if (idMatch != null) {
          playlistId = idMatch.group(1);
        }
      }
      
      // 验证ID是否为纯数字
      if (playlistId != null && RegExp(r'^\d+$').hasMatch(playlistId)) {
        return playlistId;
      }
      
      return null;
    } catch (e) {
      // URL解析失败，尝试正则表达式兜底
      try {
        final idMatch = RegExp(r'[?&]id=(\d+)').firstMatch(trimmedInput);
        if (idMatch != null) {
          return idMatch.group(1);
        }
      } catch (_) {
        // 忽略正则表达式错误
      }
      return null;
    }
  }

  /// 解析QQ音乐歌单URL，提取歌单ID (dissid)
  static String? _parseQQPlaylistId(String input) {
    final trimmedInput = input.trim();
    
    // 如果输入的是纯数字ID，直接返回
    if (RegExp(r'^\d+$').hasMatch(trimmedInput)) {
      return trimmedInput;
    }
    
    // 尝试从URL中解析ID
    try {
      // 支持的URL格式：
      // https://y.qq.com/n/ryqq/playlist/8522515502
      // https://y.qq.com/n/m/detail/taoge/index.html?id=8522515502
      // https://c.y.qq.com/base/fcgi-bin/u?__=8522515502
      
      final uri = Uri.parse(trimmedInput);
      
      // 检查是否是QQ音乐域名
      if (!uri.host.contains('qq.com')) {
        return null;
      }
      
      String? playlistId;
      
      // 从查询参数中提取
      playlistId = uri.queryParameters['id'];
      
      // 从路径中提取 (形如 /n/ryqq/playlist/8522515502)
      if (playlistId == null) {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final lastSegment = pathSegments.last;
          if (RegExp(r'^\d+$').hasMatch(lastSegment)) {
            playlistId = lastSegment;
          }
        }
      }
      
      // 正则表达式兜底
      if (playlistId == null) {
        final idMatch = RegExp(r'[\?&/](?:id=|playlist/)(\d+)').firstMatch(trimmedInput);
        if (idMatch != null) {
          playlistId = idMatch.group(1);
        }
      }
      
      // 验证ID是否为纯数字
      if (playlistId != null && RegExp(r'^\d+$').hasMatch(playlistId)) {
        return playlistId;
      }
      
      return null;
    } catch (e) {
      // URL解析失败，尝试正则表达式兜底
      try {
        final idMatch = RegExp(r'[\?&/](?:id=|playlist/)(\d+)').firstMatch(trimmedInput);
        if (idMatch != null) {
          return idMatch.group(1);
        }
      } catch (_) {
        // 忽略正则表达式错误
      }
      return null;
    }
  }

  /// 显示导入歌单对话框
  static Future<void> show(BuildContext context) async {
    final controller = TextEditingController();
    MusicPlatform selectedPlatform = MusicPlatform.netease;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_download, size: 24),
              SizedBox(width: 12),
              Text('导入歌单'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 平台选择
              const Text(
                '选择平台',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: MusicPlatform.values.map((platform) {
                  final isSelected = selectedPlatform == platform;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(platform.icon),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                platform.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              selectedPlatform = platform;
                            });
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              const Text(
                '输入歌单信息',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                selectedPlatform == MusicPlatform.netease
                    ? '支持以下两种输入方式：\n• 直接输入歌单ID，如：19723756\n• 粘贴完整URL，如：https://music.163.com/#/playlist?id=19723756'
                    : '支持以下两种输入方式：\n• 直接输入歌单ID，如：8522515502\n• 粘贴完整URL，如：https://y.qq.com/n/ryqq/playlist/8522515502',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '歌单ID或URL',
                  hintText: '例如: 19723756 或完整URL',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                maxLines: 2,
                minLines: 1,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final input = controller.text.trim();
                if (input.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入歌单ID或URL')),
                  );
                  return;
                }
                
                // 尝试解析歌单ID
                String? playlistId;
                if (selectedPlatform == MusicPlatform.netease) {
                  playlistId = _parseNeteasePlaylistId(input);
                } else {
                  playlistId = _parseQQPlaylistId(input);
                }
                
                if (playlistId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('无效的${selectedPlatform.name}歌单ID或URL格式\n请检查输入是否正确'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                
                Navigator.pop(context, {
                  'platform': selectedPlatform,
                  'playlistId': playlistId,
                });
              },
              child: const Text('下一步'),
            ),
          ],
        ),
      ),
    );

    if (result != null && context.mounted) {
      final platform = result['platform'] as MusicPlatform;
      final playlistId = result['playlistId'] as String;
      await _fetchAndImportPlaylist(context, platform, playlistId);
    }
  }

  /// 获取歌单并导入
  static Future<void> _fetchAndImportPlaylist(
      BuildContext context, MusicPlatform platform, String playlistId) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('正在获取${platform.name}歌单信息...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final baseUrl = UrlService().baseUrl;
      final url = platform == MusicPlatform.netease
          ? '$baseUrl/playlist?id=$playlistId&limit=1000'
          : '$baseUrl/qq/playlist?id=$playlistId&limit=1000';
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('请求超时'),
      );

      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['status'] == 200 && data['success'] == true) {
          final playlistData = data['data']['playlist'];
          final playlist = UniversalPlaylist.fromJson(playlistData, platform);

          // 显示选择目标歌单对话框
          await _showSelectTargetPlaylistDialog(context, playlist);
        } else {
          throw Exception(data['msg'] ?? '获取歌单失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入失败'),
          content: Text('获取歌单失败: $e'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  /// 显示选择目标歌单对话框
  static Future<void> _showSelectTargetPlaylistDialog(
      BuildContext context, UniversalPlaylist sourcePlaylist) async {
    final playlistService = PlaylistService();

    // 确保已加载歌单列表
    if (playlistService.playlists.isEmpty) {
      await playlistService.loadPlaylists();
    }

    if (!context.mounted) return;

    final targetPlaylist = await showDialog<Playlist>(
      context: context,
      builder: (context) => _SelectTargetPlaylistDialog(
        sourcePlaylist: sourcePlaylist,
      ),
    );

    if (targetPlaylist != null && context.mounted) {
      await _importTracks(context, sourcePlaylist, targetPlaylist);
    }
  }

  /// 导入歌曲到目标歌单
  static Future<void> _importTracks(
    BuildContext context,
    UniversalPlaylist sourcePlaylist,
    Playlist targetPlaylist,
  ) async {
    final playlistService = PlaylistService();

    // 显示导入进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: _ImportProgressDialog(
          sourcePlaylist: sourcePlaylist,
          targetPlaylist: targetPlaylist,
        ),
      ),
    );

    try {
      int successCount = 0;
      int failCount = 0;

      for (final track in sourcePlaylist.tracks) {
        try {
          await playlistService.addTrackToPlaylist(
            targetPlaylist.id,
            track,
          );
          successCount++;
        } catch (e) {
          // 如果是重复添加，也算成功
          if (e.toString().contains('已在歌单中')) {
            successCount++;
          } else {
            failCount++;
          }
        }

        // 更新进度
        if (context.mounted) {
          // 这里可以通过状态管理更新进度，简化起见直接继续
        }
      }

      if (!context.mounted) return;
      Navigator.pop(context); // 关闭进度对话框

      // 显示结果
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Text('导入完成'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(sourcePlaylist.platform.icon),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('来源: ${sourcePlaylist.platform.name}'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('歌单名称: ${sourcePlaylist.name}'),
              const SizedBox(height: 8),
              Text('目标歌单: ${targetPlaylist.name}'),
              const SizedBox(height: 8),
              Text('成功导入: $successCount 首'),
              if (failCount > 0) Text('导入失败: $failCount 首'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // 关闭进度对话框

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入失败'),
          content: Text('导入过程中发生错误: $e'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }
}

/// 通用歌单数据模型（支持网易云和QQ音乐）
class UniversalPlaylist {
  final dynamic id;  // 网易云用int，QQ用String
  final String name;
  final String coverImgUrl;
  final String creator;
  final int trackCount;
  final String? description;
  final List<Track> tracks;
  final MusicPlatform platform;

  UniversalPlaylist({
    required this.id,
    required this.name,
    required this.coverImgUrl,
    required this.creator,
    required this.trackCount,
    this.description,
    required this.tracks,
    required this.platform,
  });

  factory UniversalPlaylist.fromJson(
    Map<String, dynamic> json,
    MusicPlatform platform,
  ) {
    final List<dynamic> tracksJson = json['tracks'] ?? [];
    
    // 根据平台设置正确的MusicSource
    final MusicSource source = platform == MusicPlatform.netease
        ? MusicSource.netease
        : MusicSource.qq;
    
    final tracks = tracksJson.map((trackJson) {
      return Track(
        // QQ音乐使用songmid，网易云使用id
        id: platform == MusicPlatform.qq
            ? (trackJson['songmid'] ?? trackJson['id'] ?? '')
            : (trackJson['id'] ?? 0),
        name: (trackJson['name'] ?? '未知歌曲') as String,
        artists: (trackJson['artists'] ?? '未知艺术家') as String,
        album: (trackJson['album'] ?? '未知专辑') as String,
        picUrl: (trackJson['picUrl'] ?? '') as String,
        source: source,  // 🔥 关键：确保标记正确的来源
      );
    }).toList();

    return UniversalPlaylist(
      id: json['id'],
      name: (json['name'] ?? '未命名歌单') as String,
      coverImgUrl: (json['coverImgUrl'] ?? '') as String,
      creator: (json['creator'] ?? '未知') as String,
      trackCount: json['trackCount'] as int? ?? 0,
      description: json['description'] as String?,
      tracks: tracks,
      platform: platform,
    );
  }
}

/// 选择目标歌单对话框
class _SelectTargetPlaylistDialog extends StatefulWidget {
  final UniversalPlaylist sourcePlaylist;

  const _SelectTargetPlaylistDialog({
    required this.sourcePlaylist,
  });

  @override
  State<_SelectTargetPlaylistDialog> createState() =>
      _SelectTargetPlaylistDialogState();
}

class _SelectTargetPlaylistDialogState
    extends State<_SelectTargetPlaylistDialog> {
  final PlaylistService _playlistService = PlaylistService();

  @override
  void initState() {
    super.initState();
    _playlistService.addListener(_onPlaylistsChanged);
  }

  @override
  void dispose() {
    _playlistService.removeListener(_onPlaylistsChanged);
    super.dispose();
  }

  void _onPlaylistsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlists = _playlistService.playlists;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('选择目标歌单'),
          SizedBox(height: 4),
          Text(
            '将歌曲导入到以下歌单',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 源歌单信息
            Card(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        widget.sourcePlaylist.coverImgUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(widget.sourcePlaylist.platform.icon),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.sourcePlaylist.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '创建者: ${widget.sourcePlaylist.creator}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '歌曲数量: ${widget.sourcePlaylist.tracks.length} 首',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 新建歌单按钮
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.add,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              title: const Text('新建歌单'),
              subtitle: const Text('创建一个新歌单来导入'),
              onTap: () async {
                final newPlaylist = await _showCreatePlaylistDialog();
                if (newPlaylist != null && mounted) {
                  Navigator.pop(context, newPlaylist);
                }
              },
            ),

            const Divider(),

            // 歌单列表
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: playlist.isDefault
                          ? colorScheme.primaryContainer
                          : colorScheme.secondaryContainer,
                      child: Icon(
                        playlist.isDefault
                            ? Icons.favorite
                            : Icons.queue_music,
                        color: playlist.isDefault
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (playlist.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '默认',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text('${playlist.trackCount} 首歌曲'),
                    onTap: () => Navigator.pop(context, playlist),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  /// 显示创建歌单对话框
  Future<Playlist?> _showCreatePlaylistDialog() async {
    final controller = TextEditingController(
      text: widget.sourcePlaylist.name, // 默认使用源歌单名称
    );

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '歌单名称',
            hintText: '请输入歌单名称',
          ),
          autofocus: true,
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('歌单名称不能为空')),
                );
                return;
              }
              Navigator.pop(context, name);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name != null) {
      final success = await _playlistService.createPlaylist(name);
      if (success) {
        // 等待列表更新
        await Future.delayed(const Duration(milliseconds: 500));
        // 返回新创建的歌单
        final newPlaylist = _playlistService.playlists.firstWhere(
          (p) => p.name == name,
          orElse: () => _playlistService.playlists.last,
        );
        return newPlaylist;
      }
    }
    return null;
  }
}

/// 导入进度对话框
class _ImportProgressDialog extends StatelessWidget {
  final UniversalPlaylist sourcePlaylist;
  final Playlist targetPlaylist;

  const _ImportProgressDialog({
    required this.sourcePlaylist,
    required this.targetPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '正在导入歌曲...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sourcePlaylist.platform.icon),
                  const SizedBox(width: 4),
                  Text(
                    '从「${sourcePlaylist.name}」',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Text(
                '导入到「${targetPlaylist.name}」',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                '共 ${sourcePlaylist.tracks.length} 首歌曲',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
