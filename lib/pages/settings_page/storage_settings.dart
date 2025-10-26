import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/cache_service.dart';
import '../../services/download_service.dart';

/// 存储设置组件
class StorageSettings extends StatefulWidget {
  const StorageSettings({super.key});

  @override
  State<StorageSettings> createState() => _StorageSettingsState();
}

class _StorageSettingsState extends State<StorageSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('存储'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.cloud_download),
                title: const Text('启用缓存'),
                subtitle: Text(
                  CacheService().cacheEnabled
                      ? '自动缓存播放过的歌曲'
                      : '缓存已禁用'
                ),
                value: CacheService().cacheEnabled,
                onChanged: (value) async {
                  await CacheService().setCacheEnabled(value);
                  setState(() {});
                },
              ),
              if (Platform.isWindows) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('缓存目录'),
                  subtitle: Text(_getCacheDirSubtitle()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCacheDirSettings(),
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('缓存管理'),
                subtitle: Text(_getCacheSubtitle()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCacheManagement(),
              ),
              if (Platform.isWindows) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('下载目录'),
                  subtitle: Text(_getDownloadDirSubtitle()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDownloadDirSettings(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _getCacheSubtitle() {
    if (!CacheService().isInitialized) {
      return '初始化中...';
    }

    if (!CacheService().cacheEnabled) {
      return '缓存功能已禁用';
    }

    final count = CacheService().cachedCount;
    if (count == 0) {
      return '暂无缓存';
    }

    return '已缓存 $count 首歌曲';
  }

  String _getCacheDirSubtitle() {
    final customDir = CacheService().customCacheDir;
    if (customDir != null && customDir.isNotEmpty) {
      return '自定义：$customDir';
    }
    return '默认位置';
  }

  String _getDownloadDirSubtitle() {
    final downloadPath = DownloadService().downloadPath;
    if (downloadPath != null && downloadPath.isNotEmpty) {
      return downloadPath;
    }
    return '未设置';
  }

  Future<void> _showCacheManagement() async {
    final stats = await CacheService().getCacheStats();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storage),
            SizedBox(width: 8),
            Text('缓存管理'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '占用空间',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stats.formattedSize,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.folder_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '已缓存 ${stats.totalFiles} 首歌曲',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          if (stats.totalFiles > 0)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _confirmClearCache();
              },
              icon: const Icon(Icons.delete_sweep),
              label: const Text('清除缓存'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClearCache() async {
    final stats = await CacheService().getCacheStats();

    if (stats.totalFiles == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无缓存可清除')),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: Text(
          '确定要清除所有缓存吗？\n\n'
          '将删除 ${stats.totalFiles} 首歌曲的缓存\n'
          '释放 ${stats.formattedSize} 空间',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 16),
                        Text('正在清除缓存...'),
                      ],
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }

              await CacheService().clearAllCache();

              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已清除 ${stats.totalFiles} 首歌曲的缓存'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCacheDirSettings() async {
    final currentCustomDir = CacheService().customCacheDir;
    final currentDir = CacheService().currentCacheDir;
    final defaultDir = await CacheService().getDefaultCacheDir();
    
    final dirController = TextEditingController(text: currentCustomDir ?? '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder),
              SizedBox(width: 8),
              Text('缓存目录设置'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前目录：',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  currentDir ?? '未知',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  '默认目录：',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  defaultDir,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dirController,
                        decoration: const InputDecoration(
                          labelText: '自定义目录（留空使用默认）',
                          hintText: '例：D:\\Music\\Cache',
                          prefixIcon: Icon(Icons.edit_location),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () async {
                        String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: '选择缓存目录',
                          lockParentWindow: true,
                        );

                        if (selectedDirectory != null) {
                          setState(() {
                            dirController.text = selectedDirectory;
                          });
                        }
                      },
                      icon: const Icon(Icons.folder_open),
                      tooltip: '浏览选择目录',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '提示',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• 点击文件夹图标选择目录\n'
                        '• 更改目录需要重启应用生效\n'
                        '• 确保目录有读写权限\n'
                        '• 旧缓存不会自动迁移',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (currentCustomDir != null && currentCustomDir.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final success = await CacheService().setCustomCacheDir(null);
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已恢复默认目录，请重启应用生效'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.restore),
                label: const Text('恢复默认'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final newDir = dirController.text.trim();
                
                if (newDir.isEmpty || newDir == currentCustomDir) {
                  Navigator.pop(context);
                  return;
                }

                final success = await CacheService().setCustomCacheDir(newDir);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    _showRestartDialog(newDir);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('目录设置失败，请检查路径是否正确'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestartDialog(String newDir) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.restart_alt, size: 48),
        title: const Text('需要重启应用'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '缓存目录已设置为：',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SelectableText(
              newDir,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '必须重启应用才能使用新目录！\n当前播放的歌曲仍会缓存到旧目录。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDownloadDirSettings() async {
    final currentDownloadPath = DownloadService().downloadPath;
    final dirController = TextEditingController(text: currentDownloadPath ?? '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下载目录设置'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前下载目录：',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                currentDownloadPath ?? '未设置',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: dirController,
                decoration: const InputDecoration(
                  labelText: '新下载目录',
                  border: OutlineInputBorder(),
                  hintText: '例如: D:\\Music\\Cyrene',
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: '选择下载目录',
                        );

                        if (result != null) {
                          dirController.text = result;
                        }
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text('浏览'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '下载的音乐文件将保存到指定目录',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                      ),
                    ),
                  ],
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
          FilledButton(
            onPressed: () async {
              final newDir = dirController.text.trim();

              if (newDir.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请选择下载目录')),
                );
                return;
              }

              final success = await DownloadService().setDownloadPath(newDir);

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('下载目录已更新')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('设置下载目录失败')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

