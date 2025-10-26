import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/netease_discover_service.dart';
import '../models/netease_discover.dart';
import 'discover_playlist_detail_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  int? _selectedPlaylistId;
  String? _selectedPlaylistName;
  @override
  void initState() {
    super.initState();
    if (NeteaseDiscoverService().playlists.isEmpty && !NeteaseDiscoverService().isLoading) {
      NeteaseDiscoverService().fetchDiscoverPlaylists();
    }
    if (NeteaseDiscoverService().tags.isEmpty) {
      NeteaseDiscoverService().fetchTags();
    }
    NeteaseDiscoverService().addListener(_onChanged);
  }

  @override
  void dispose() {
    NeteaseDiscoverService().removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = NeteaseDiscoverService();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: colorScheme.surface,
            title: _buildTitle(colorScheme),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverToBoxAdapter(
              child: _buildContent(service),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTitle(ColorScheme colorScheme) {
    if (_selectedPlaylistId == null) {
      return Text(
        '发现',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // 面包屑样式：发现 > 歌单名
    return Row(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _selectedPlaylistId = null;
              _selectedPlaylistName = null;
            });
          },
          child: Row(
            children: [
              const Icon(Icons.explore, size: 20),
              const SizedBox(width: 6),
              const Text('发现', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _selectedPlaylistName ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(NeteaseDiscoverService service) {
    // 二级：歌单详情（内嵌在发现页，使用面包屑）
    if (_selectedPlaylistId != null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 160,
        child: DiscoverPlaylistDetailContent(playlistId: _selectedPlaylistId!),
      );
    }

    if (service.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (service.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(service.errorMessage!),
        ),
      );
    }

    final items = service.playlists;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // 顶部分类选择 + 自适应网格
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 2;
        if (width >= 1200) crossAxisCount = 6;
        else if (width >= 1000) crossAxisCount = 5;
        else if (width >= 800) crossAxisCount = 4;
        else if (width >= 600) crossAxisCount = 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTagSelector(service),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                // 调整纵横比，避免卡片内容溢出
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _PlaylistCard(
                summary: items[index],
                onOpen: (id, name) {
                  setState(() {
                    _selectedPlaylistId = id;
                    _selectedPlaylistName = name;
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTagSelector(NeteaseDiscoverService service) {
    final current = service.currentCat;
    return ChoiceChip(
      label: Text(current.isEmpty ? '全部歌单' : current),
      selected: true,
      onSelected: (_) => _showTagDialog(service),
    );
  }

  void _showTagDialog(NeteaseDiscoverService service) {
    final tags = service.tags;
    final allLabel = '全部歌单';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择歌单类型'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部歌单'),
                  selected: service.currentCat == allLabel,
                  onSelected: (_) {
                    Navigator.of(context).pop();
                    NeteaseDiscoverService().fetchDiscoverPlaylists(cat: allLabel);
                  },
                ),
                ...tags.map((t) => ChoiceChip(
                      label: Text(t.name),
                      selected: service.currentCat == t.name,
                      onSelected: (_) {
                        Navigator.of(context).pop();
                        NeteaseDiscoverService().fetchDiscoverPlaylists(cat: t.name);
                      },
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            )
          ],
        );
      },
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final NeteasePlaylistSummary summary;
  final void Function(int id, String name)? onOpen;
  const _PlaylistCard({required this.summary, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          if (onOpen != null) onOpen!(summary.id, summary.name);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: summary.coverImgUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (context, url, error) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.image_not_supported, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      summary.name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'by ${summary.creatorNickname}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.trackCount} 首 · 播放 ${summary.playCount}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


