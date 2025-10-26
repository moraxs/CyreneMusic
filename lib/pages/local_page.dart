import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/local_library_service.dart';
import '../services/player_service.dart';
import '../models/track.dart';

class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends State<LocalPage> {
  final LocalLibraryService _local = LocalLibraryService();

  @override
  void initState() {
    super.initState();
    _local.addListener(_onChanged);
  }

  @override
  void dispose() {
    _local.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: colorScheme.surface,
            title: Text(
              '本地',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.audio_file),
                tooltip: '选择单首歌曲',
                onPressed: () async {
                  await _local.pickSingleSong();
                },
              ),
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: '选择文件夹并扫描',
                onPressed: () async {
                  await _local.pickAndScanFolder();
                },
              ),
              if (_local.tracks.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: '清空列表',
                  onPressed: () {
                    _local.clear();
                  },
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: _local.tracks.isEmpty
                ? SliverToBoxAdapter(child: _buildEmpty())
                : SliverList.builder(
                    itemCount: _local.tracks.length,
                    itemBuilder: (context, index) {
                      final track = _local.tracks[index];
                      return _LocalTrackTile(track: track);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('未选择本地音乐', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '可选择单首歌曲或扫描整个文件夹（支持 mp3/wav/flac 等）',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LocalTrackTile extends StatelessWidget {
  final Track track;
  const _LocalTrackTile({required this.track});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _buildCover(cs),
        title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('本地 • ${_extOf(track.id)}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () async {
            await PlayerService().playTrack(track);
          },
          tooltip: '播放',
        ),
        onTap: () async {
          await PlayerService().playTrack(track);
        },
      ),
    );
  }

  Widget _buildCover(ColorScheme cs) {
    if (track.picUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: track.picUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
    );
  }

  String _extOf(dynamic id) {
    if (id is String) {
      final idx = id.lastIndexOf('.');
      if (idx > 0 && idx < id.length - 1) return id.substring(idx + 1).toUpperCase();
    }
    return '';
  }
}


