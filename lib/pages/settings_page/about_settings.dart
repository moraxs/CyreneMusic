import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/version_info.dart';
import '../../services/auto_update_service.dart';
import '../../services/url_service.dart';
import '../../services/version_service.dart';

/// 关于设置组件
class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key});

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  final VersionService _versionService = VersionService();
  final AutoUpdateService _autoUpdateService = AutoUpdateService();

  @override
  void initState() {
    super.initState();
    _versionService.addListener(_onServiceChanged);
    _autoUpdateService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _versionService.removeListener(_onServiceChanged);
    _autoUpdateService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestVersion = _versionService.latestVersion;
    final hasUpdate = _versionService.hasUpdate;
    final autoSupported = _autoUpdateService.isPlatformSupported;
    final showStatus = _autoUpdateService.isUpdating ||
        _autoUpdateService.requiresRestart ||
        _autoUpdateService.lastError != null ||
        (_autoUpdateService.statusMessage.isNotEmpty &&
            _autoUpdateService.statusMessage != '未开始');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '关于'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('版本信息'),
                subtitle: Text('v${_versionService.currentVersion}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAboutDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.system_update),
                title: const Text('检查更新'),
                subtitle: const Text('查看是否有新版本'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _checkForUpdate(context),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.autorenew),
                value: autoSupported && _autoUpdateService.isEnabled,
                title: const Text('自动更新'),
                subtitle: Text(
                  autoSupported
                      ? '开启后检测到新版本将自动下载并安装'
                      : '当前平台暂不支持自动更新（仅 Windows 和 Android）',
                ),
                onChanged: autoSupported
                    ? (value) => _toggleAutoUpdate(context, value)
                    : null,
              ),
              if (autoSupported) const Divider(height: 1),
              if (autoSupported)
                ListTile(
                  leading: const Icon(Icons.flash_on_outlined),
                  title: const Text('一键更新'),
                  subtitle: Text(
                    hasUpdate && latestVersion != null
                        ? '发现新版本 ${latestVersion.version}，点击立即更新'
                        : '需先检查更新，若有新版本可快速安装',
                  ),
                  trailing: FilledButton.icon(
                    onPressed: () => _triggerQuickUpdate(context),
                    icon: const Icon(Icons.system_update_alt),
                    label: const Text('开始更新'),
                  ),
                  onTap: () => _triggerQuickUpdate(context),
                ),
              if (showStatus)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _autoUpdateService.lastError != null
                                ? Icons.error_outline
                                : _autoUpdateService.requiresRestart
                                    ? Icons.restart_alt
                                    : Icons.info_outline,
                            color: _autoUpdateService.lastError != null
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _autoUpdateService.statusMessage,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: _autoUpdateService.lastError != null
                                        ? Theme.of(context)
                                            .colorScheme
                                            .error
                                        : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (_autoUpdateService.isUpdating) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _autoUpdateService.progress > 0 &&
                                  _autoUpdateService.progress < 1
                              ? _autoUpdateService.progress
                              : null,
                        ),
                      ],
                      if (_autoUpdateService.requiresRestart) ...[
                        const SizedBox(height: 12),
                        Text(
                          '更新已完成，请退出并重新启动应用以应用最新版本。',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                      if (_autoUpdateService.lastSuccessAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '最后更新: ${_formatDateTime(_autoUpdateService.lastSuccessAt!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_autoUpdateService.lastError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '错误详情: ${_autoUpdateService.lastError}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
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

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Cyrene Music',
      applicationVersion: _versionService.currentVersion,
      applicationIcon: const Icon(Icons.music_note, size: 48),
      children: const [
        Text('一个跨平台的音乐与视频聚合播放器'),
        SizedBox(height: 16),
        Text('支持网易云音乐、QQ音乐、酷狗音乐、Bilibili等平台'),
      ],
    );
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final versionInfo = await _versionService.checkForUpdate(silent: false);

      if (!mounted) return;

      Navigator.of(context).pop();

      if (versionInfo != null && _versionService.hasUpdate) {
        _showUpdateDialog(context, versionInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('当前已是最新版本')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('检查更新失败: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _toggleAutoUpdate(BuildContext context, bool value) async {
    await _autoUpdateService.setEnabled(value);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? '已开启自动更新' : '已关闭自动更新'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _triggerQuickUpdate(BuildContext context) async {
    VersionInfo? versionInfo = _versionService.latestVersion;

    if (versionInfo == null || !_versionService.hasUpdate) {
      versionInfo = await _versionService.checkForUpdate(silent: false);
      if (!mounted) return;

      if (versionInfo == null || !_versionService.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('当前已是最新版本')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    if (!_autoUpdateService.isPlatformSupported) {
      await _openDownloadLink(context, versionInfo.downloadUrl);
      return;
    }

    await _autoUpdateService.startUpdate(
      versionInfo: versionInfo,
      autoTriggered: false,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.system_update_alt, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('已开始下载更新，请稍候查看状态')),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, VersionInfo versionInfo) {
    final isForceUpdate = versionInfo.forceUpdate;
    final platformSupported = _autoUpdateService.isPlatformSupported;

    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => PopScope(
        canPop: !isForceUpdate,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update, size: 28),
              SizedBox(width: 12),
              Text('发现新版本'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
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
                            '最新版本',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            versionInfo.version,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '当前版本',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _versionService.currentVersion,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '更新内容',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    versionInfo.changelog,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (isForceUpdate) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Theme.of(context).colorScheme.error,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '此版本为强制更新\n请尽快完成安装',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!isForceUpdate)
              TextButton(
                onPressed: () async {
                  await _versionService.ignoreCurrentVersion(versionInfo.version);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已忽略版本 ${versionInfo.version}，后续将不再提示'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('稍后提醒'),
              ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();

                if (platformSupported) {
                  await _autoUpdateService.startUpdate(
                    versionInfo: versionInfo,
                    autoTriggered: false,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Icon(Icons.system_update, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('正在下载并安装更新，请稍候')), 
                        ],
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } else {
                  await _openDownloadLink(context, versionInfo.downloadUrl);
                }
              },
              icon: const Icon(Icons.download),
              label: Text(platformSupported ? '一键更新' : '前往下载'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDownloadLink(BuildContext context, String url) async {
    final uri = _resolveDownloadUri(url);

    try {
      if (!await canLaunchUrl(uri)) {
        throw Exception('无法打开链接');
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('打开下载链接失败: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Uri _resolveDownloadUri(String rawUrl) {
    final uri = Uri.parse(rawUrl);
    if (uri.hasScheme) {
      return uri;
    }

    final base = UrlService().baseUrl;
    final cleanedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final formattedPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return Uri.parse('$cleanedBase$formattedPath');
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date = '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

