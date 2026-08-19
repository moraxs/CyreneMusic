import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;
import '../../widgets/cupertino/cupertino_settings_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/version_info.dart';
import '../../services/auto_update_service.dart';
import '../../services/url_service.dart';
import '../../services/version_service.dart';
import '../../services/developer_mode_service.dart';
import '../../utils/theme_manager.dart';
import '../../widgets/material/material_settings_widgets.dart';
import '../../utils/toast_utils.dart';
import 'user_agreement_page.dart';

/// 关于设置详情内容（二级页面内容，嵌入在设置页面中）
class AboutSettingsContent extends StatefulWidget {
  final VoidCallback onBack;
  final bool embed;

  const AboutSettingsContent({
    super.key,
    required this.onBack,
    this.embed = false,
  });

  /// 构建 Fluent UI 面包屑导航（Windows 11 24H2 风格）
  Widget buildFluentBreadcrumb(BuildContext context) {
    final theme = fluent_ui.FluentTheme.of(context);
    final typography = theme.typography;

    return Row(
      children: [
        // 父级：设置（颜色较浅，可点击）
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onBack,
            child: Text(
              '设置',
              style: typography.title?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            fluent_ui.FluentIcons.chevron_right,
            size: 14,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        // 当前页面：关于（正常颜色）
        Text('关于', style: typography.title),
      ],
    );
  }

  @override
  State<AboutSettingsContent> createState() => _AboutSettingsContentState();
}

class _AboutSettingsContentState extends State<AboutSettingsContent> {
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
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ThemeManager().isCupertinoFramework) {
      return _buildCupertinoUI(context);
    }

    return _buildMaterialUI(context);
  }

  /// 构建 Material UI 版本
  Widget _buildMaterialUI(BuildContext context) {
    final latestVersion = _versionService.latestVersion;
    final hasUpdate = _versionService.hasUpdate;
    final autoSupported = _autoUpdateService.isPlatformSupported;
    final showStatus =
        _autoUpdateService.isUpdating ||
        _autoUpdateService.requiresRestart ||
        _autoUpdateService.lastError != null ||
        (_autoUpdateService.statusMessage.isNotEmpty &&
            _autoUpdateService.statusMessage != '未开始');

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // 应用图标和名称头部
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              // 应用图标
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icons/new_ico_white.png',
                  width: 96,
                  height: 96,
                ),
              ),
              const SizedBox(height: 16),
              // 应用名称
              Text(
                'Cyrene Music',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => DeveloperModeService().onVersionClicked(),
                child: Text(
                  'v${_versionService.currentVersion}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        MD3SettingsSection(
          children: [
            MD3SettingsTile(
              leading: const Icon(Icons.info_outline),
              title: '版本信息',
              subtitle: 'v${_versionService.currentVersion}',
              onTap: () => DeveloperModeService().onVersionClicked(),
            ),
            MD3SettingsTile(
              leading: const Icon(Icons.system_update_outlined),
              title: '检查更新',
              subtitle: '查看是否有新版本',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _checkForUpdate(context),
            ),
            MD3SwitchTile(
              leading: const Icon(Icons.autorenew_outlined),
              title: '自动更新',
              subtitle: autoSupported
                  ? '开启后检测到新版本将自动下载并安装'
                  : '当前平台暂不支持自动更新（仅 Windows 和 Android）',
              value: autoSupported && _autoUpdateService.isEnabled,
              enabled: autoSupported,
              onChanged: (value) => _toggleAutoUpdate(context, value),
            ),
            MD3SettingsTile(
              leading: const Icon(Icons.description_outlined),
              title: '用户协议',
              subtitle: '查看用户协议与隐私政策',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserAgreementPage(),
                ),
              ),
            ),
            MD3SettingsTile(
              leading: const Icon(Icons.article_outlined),
              title: '开放源代码许可',
              subtitle: '查看第三方库许可信息',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLicensePage(context),
            ),
            if (showStatus)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _autoUpdateService.lastError != null
                        ? Theme.of(
                            context,
                          ).colorScheme.errorContainer.withOpacity(0.5)
                        : Theme.of(context).colorScheme.surfaceContainerHighest
                              .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                                : Icons.info_outlined,
                            size: 20,
                            color: _autoUpdateService.lastError != null
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _autoUpdateService.statusMessage,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: _autoUpdateService.lastError != null
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (_autoUpdateService.isUpdating) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value:
                                _autoUpdateService.progress > 0 &&
                                    _autoUpdateService.progress < 1
                                ? _autoUpdateService.progress
                                : null,
                            minHeight: 6,
                          ),
                        ),
                      ],
                      if (_autoUpdateService.requiresRestart) ...[
                        const SizedBox(height: 12),
                        Text(
                          '更新已完成，请退出并重新启动应用以应用最新版本。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                      if (_autoUpdateService.lastSuccessAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '最后更新: ${_formatDateTime(_autoUpdateService.lastSuccessAt!)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      if (_autoUpdateService.lastError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '错误详情: ${_autoUpdateService.lastError}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 构建 Cupertino UI 版本
  Widget _buildCupertinoUI(BuildContext context) {
    final latestVersion = _versionService.latestVersion;
    final hasUpdate = _versionService.hasUpdate;
    final autoSupported = _autoUpdateService.isPlatformSupported;
    final showStatus =
        _autoUpdateService.isUpdating ||
        _autoUpdateService.requiresRestart ||
        _autoUpdateService.lastError != null ||
        (_autoUpdateService.statusMessage.isNotEmpty &&
            _autoUpdateService.statusMessage != '未开始');

    return ListView(
      padding: const EdgeInsets.only(top: 20),
      children: [
        // 应用图标和名称头部
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              // 应用图标
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icons/new_ico_white.png',
                  width: 96,
                  height: 96,
                ),
              ),
              const SizedBox(height: 16),
              // 应用名称
              Text(
                'Cyrene Music',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => DeveloperModeService().onVersionClicked(),
                child: Text(
                  'v${_versionService.currentVersion}',
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 版本信息
        CupertinoSettingsTile(
          icon: CupertinoIcons.info,
          iconColor: CupertinoColors.systemBlue,
          title: '版本信息',
          subtitle: 'v${_versionService.currentVersion}',
          showChevron: true,
          onTap: () {
            DeveloperModeService().onVersionClicked();
            _showAboutDialogCupertino(context);
          },
        ),
        const SizedBox(height: 1),
        // 检查更新
        CupertinoSettingsTile(
          icon: CupertinoIcons.arrow_down_circle,
          iconColor: CupertinoColors.systemGreen,
          title: '检查更新',
          subtitle: hasUpdate && latestVersion != null
              ? '发现新版本 ${latestVersion.version}'
              : '查看是否有新版本',
          showChevron: true,
          onTap: () => _checkForUpdateCupertino(context),
        ),
        const SizedBox(height: 1),
        // 自动更新开关
        CupertinoSwitchTile(
          icon: CupertinoIcons.arrow_2_circlepath,
          iconColor: CupertinoColors.systemOrange,
          title: '自动更新',
          subtitle: autoSupported ? '开启后检测到新版本将自动下载并安装' : '当前平台暂不支持自动更新',
          value: autoSupported && _autoUpdateService.isEnabled,
          onChanged: autoSupported
              ? (value) => _toggleAutoUpdate(context, value)
              : null,
        ),
        const SizedBox(height: 1),
        // 用户协议
        CupertinoSettingsTile(
          icon: CupertinoIcons.doc_text,
          iconColor: CupertinoColors.systemPurple,
          title: '用户协议',
          showChevron: true,
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => const UserAgreementPage()),
          ),
        ),
        // 更新状态
        if (showStatus) ...[
          const SizedBox(height: 8),
          _buildCupertinoStatusCard(context),
        ],
      ],
    );
  }

  /// 构建 Cupertino 风格的状态卡片
  Widget _buildCupertinoStatusCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _autoUpdateService.lastError != null
                    ? CupertinoIcons.exclamationmark_circle
                    : _autoUpdateService.requiresRestart
                    ? CupertinoIcons.arrow_clockwise
                    : CupertinoIcons.info_circle,
                color: _autoUpdateService.lastError != null
                    ? CupertinoColors.systemRed
                    : CupertinoColors.systemBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _autoUpdateService.statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: _autoUpdateService.lastError != null
                        ? CupertinoColors.systemRed
                        : (isDark
                              ? CupertinoColors.white
                              : CupertinoColors.black),
                  ),
                ),
              ),
            ],
          ),
          if (_autoUpdateService.isUpdating) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:
                    _autoUpdateService.progress > 0 &&
                        _autoUpdateService.progress < 1
                    ? _autoUpdateService.progress
                    : null,
                backgroundColor: CupertinoColors.systemGrey.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  CupertinoColors.systemBlue,
                ),
              ),
            ),
          ],
          if (_autoUpdateService.requiresRestart) ...[
            const SizedBox(height: 8),
            Text(
              '更新已完成，请退出并重新启动应用以应用最新版本。',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== 对话框和操作方法 ==========

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

  void _showLicensePage(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Cyrene Music',
      applicationVersion: _versionService.currentVersion,
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/icons/new_ico_white.png',
            width: 48,
            height: 48,
          ),
        ),
      ),
    );
  }

  void _showAboutDialogCupertino(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('关于 Cyrene Music'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              Text('版本: ${_versionService.currentVersion}'),
              const SizedBox(height: 8),
              const Text('一个跨平台的音乐与视频聚合播放器'),
              const SizedBox(height: 8),
              const Text('支持网易云音乐、QQ音乐、酷狗音乐、Bilibili等平台'),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
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
        ToastUtils.show('当前已是最新版本');
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      ToastUtils.error('检查更新失败: $e');
    }
  }

  Future<void> _checkForUpdateCupertino(BuildContext context) async {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final versionInfo = await _versionService.checkForUpdate(silent: false);

      if (!mounted) return;

      Navigator.of(context).pop();

      if (versionInfo != null && _versionService.hasUpdate) {
        _showUpdateDialogCupertino(context, versionInfo);
      } else {
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('检查更新'),
            content: const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('当前已是最新版本'),
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('好的'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('检查更新失败'),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('$e'),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
              child: const Text('好的'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _toggleAutoUpdate(BuildContext context, bool value) async {
    await _autoUpdateService.setEnabled(value);
    if (!mounted) return;
    ToastUtils.show(value ? '已开启自动更新' : '已关闭自动更新');
  }

  Future<void> _triggerQuickUpdate(BuildContext context) async {
    VersionInfo? versionInfo = _versionService.latestVersion;

    if (versionInfo == null || !_versionService.hasUpdate) {
      versionInfo = await _versionService.checkForUpdate(silent: false);
      if (!mounted) return;

      if (versionInfo == null || !_versionService.hasUpdate) {
        ToastUtils.show('当前已是最新版本');
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

    ToastUtils.show('已开始下载更新，请稍候查看状态');
  }

  void _showUpdateDialog(BuildContext context, VersionInfo versionInfo) {
    final isForceUpdate = versionInfo.forceUpdate;
    final isFixing = versionInfo.fixing;
    final platformSupported = _autoUpdateService.isPlatformSupported;

    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => PopScope(
        canPop: !isForceUpdate,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                isFixing ? Icons.build : Icons.system_update,
                size: 28,
                color: isFixing ? Colors.orange : null,
              ),
              const SizedBox(width: 12),
              Text(isFixing ? '服务器正在维护' : '发现新版本'),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.5),
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            versionInfo.version,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    versionInfo.changelog,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (isForceUpdate && !isFixing) ...[
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isFixing) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.build,
                          color: Colors.orange.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '服务器正在维护中，请稍后再试',
                            style: TextStyle(
                              color: Colors.orange.shade900,
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
                  await _versionService.ignoreCurrentVersion(
                    versionInfo.version,
                  );
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
            if (!isFixing)
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();

                  if (platformSupported) {
                    await _autoUpdateService.startUpdate(
                      versionInfo: versionInfo,
                      autoTriggered: false,
                    );
                    if (!mounted) return;
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    if (messenger != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.system_update, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(child: Text('正在下载并安装更新，请稍候')),
                            ],
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
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

  void _showUpdateDialogCupertino(
    BuildContext context,
    VersionInfo versionInfo,
  ) {
    final isForceUpdate = versionInfo.forceUpdate;
    final isFixing = versionInfo.fixing;
    final platformSupported = _autoUpdateService.isPlatformSupported;

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => PopScope(
        canPop: !isForceUpdate,
        child: CupertinoAlertDialog(
          title: Text(isFixing ? '服务器正在维护' : '发现新版本'),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                Text('最新版本: ${versionInfo.version}'),
                const SizedBox(height: 4),
                Text('当前版本: ${_versionService.currentVersion}'),
                const SizedBox(height: 12),
                const Text(
                  '更新内容',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(versionInfo.changelog),
                if (isForceUpdate && !isFixing) ...[
                  const SizedBox(height: 12),
                  Text(
                    '此版本为强制更新，请尽快完成安装',
                    style: TextStyle(
                      color: CupertinoColors.systemRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (isFixing) ...[
                  const SizedBox(height: 12),
                  Text(
                    '服务器正在维护中，请稍后再试',
                    style: TextStyle(
                      color: CupertinoColors.systemOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!isForceUpdate)
              CupertinoDialogAction(
                isDestructiveAction: false,
                onPressed: () async {
                  await _versionService.ignoreCurrentVersion(
                    versionInfo.version,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('稍后提醒'),
              ),
            if (!isFixing)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  Navigator.of(context).pop();
                  if (platformSupported) {
                    await _autoUpdateService.startUpdate(
                      versionInfo: versionInfo,
                      autoTriggered: false,
                    );
                  } else {
                    await _openDownloadLink(context, versionInfo.downloadUrl);
                  }
                },
                child: Text(platformSupported ? '一键更新' : '前往下载'),
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
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
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
  }

  Uri _resolveDownloadUri(String rawUrl) {
    final uri = Uri.parse(rawUrl);
    if (uri.hasScheme) {
      return uri;
    }

    final base = UrlService().baseUrl;
    final cleanedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final formattedPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return Uri.parse('$cleanedBase$formattedPath');
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
