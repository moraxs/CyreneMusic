import 'package:flutter/material.dart';
import '../services/netease_artist_service.dart';

class ArtistDetailPage extends StatefulWidget {
  final int artistId;
  const ArtistDetailPage({super.key, required this.artistId});

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
    final data = await NeteaseArtistDetailService().fetchArtistDetail(widget.artistId);
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
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('歌手详情'),
        backgroundColor: cs.surface,
      ),
      body: ArtistDetailContent(artistId: widget.artistId),
    );
  }
}

/// 无 AppBar 的内容组件，供悬浮窗使用
class ArtistDetailContent extends StatefulWidget {
  final int artistId;
  const ArtistDetailContent({super.key, required this.artistId});

  @override
  State<ArtistDetailContent> createState() => _ArtistDetailContentState();
}

class _ArtistDetailContentState extends State<ArtistDetailContent> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
    final data = await NeteaseArtistDetailService().fetchArtistDetail(widget.artistId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      if (data == null) _error = '加载失败';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final artist = _data!['artist'] as Map<String, dynamic>? ?? {};
    final albums = (_data!['albums'] as List<dynamic>? ?? []) as List<dynamic>;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: NetworkImage((artist['img1v1Url'] ?? artist['picUrl'] ?? '') as String),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(artist['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(artist['briefDesc']?.toString() ?? artist['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('专辑', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final a = albums[index] as Map<String, dynamic>;
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network((a['coverImgUrl'] ?? '') as String, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  title: Text(a['name']?.toString() ?? ''),
                  subtitle: Text((a['company']?.toString() ?? '').isEmpty ? '' : a['company'].toString()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


