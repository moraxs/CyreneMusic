import 'package:flutter/material.dart';
import '../services/netease_album_service.dart';
import '../models/track.dart';
import '../services/player_service.dart';

class AlbumDetailPage extends StatefulWidget {
  final int albumId;
  final bool embedded;
  const AlbumDetailPage({super.key, required this.albumId, this.embedded = false});

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _useGrid = false; // 歌曲视图模式

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await NeteaseAlbumService().fetchAlbumDetail(widget.albumId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      if (data == null) _error = '加载失败';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.embedded) {
      return _buildBody();
    }
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('专辑详情'),
        backgroundColor: cs.surface,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final album = _data!['album'] as Map<String, dynamic>? ?? {};
    final songs = (album['songs'] as List<dynamic>? ?? []) as List<dynamic>;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network((album['coverImgUrl'] ?? '') as String, width: 120, height: 120, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album['name']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(album['artist']?.toString() ?? '', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(album['description']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('歌曲', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Icon(Icons.view_list, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Switch(value: _useGrid, onChanged: (v) => setState(() => _useGrid = v)),
            const SizedBox(width: 8),
            Icon(Icons.grid_view, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
        const SizedBox(height: 8),
        if (!_useGrid) ...songs.map((s0) {
          final s = s0 as Map<String, dynamic>;
          final track = Track(
            id: s['id'],
            name: s['name']?.toString() ?? '',
            artists: s['artists']?.toString() ?? '',
            album: s['album']?.toString() ?? (album['name']?.toString() ?? ''),
            picUrl: s['picUrl']?.toString() ?? (album['coverImgUrl']?.toString() ?? ''),
            source: MusicSource.netease,
          );
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(track.picUrl, width: 50, height: 50, fit: BoxFit.cover),
              ),
              title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${track.artists} • ${track.album}', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => PlayerService().playTrack(track),
            ),
          );
        })
        else ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: songs.map((s0) {
              final s = s0 as Map<String, dynamic>;
              final track = Track(
                id: s['id'],
                name: s['name']?.toString() ?? '',
                artists: s['artists']?.toString() ?? '',
                album: s['album']?.toString() ?? (album['name']?.toString() ?? ''),
                picUrl: s['picUrl']?.toString() ?? (album['coverImgUrl']?.toString() ?? ''),
                source: MusicSource.netease,
              );
              return ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 260, maxWidth: 440),
                child: InkWell(
                  onTap: () => PlayerService().playTrack(track),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(track.picUrl, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(track.artists, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 6),
                              Text(track.album, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.play_arrow),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
