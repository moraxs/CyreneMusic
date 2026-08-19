import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent_ui;
import 'package:http/http.dart' as http;
import '../../services/url_service.dart';
import '../../services/audio_source_service.dart';
import '../../widgets/fluent_settings_card.dart';
import '../../widgets/cupertino/cupertino_settings_widgets.dart';
import '../../utils/theme_manager.dart';
import '../../widgets/material/material_settings_widgets.dart';

/// 网络设置组件
class NetworkSettings extends StatefulWidget {
  /// 点击音源设置时的回调，用于在设置页面中打开子页面
  final VoidCallback? onAudioSourceTap;

  const NetworkSettings({super.key, this.onAudioSourceTap});

  @override
  State<NetworkSettings> createState() => _NetworkSettingsState();
}

class _NetworkSettingsState extends State<NetworkSettings> {
  bool _isTesting = false;
  bool? _isConnected;
  String? _errorMessage;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    UrlService().addListener(_handleUrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testConnection();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    UrlService().removeListener(_handleUrlChanged);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _handleUrlChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      _testConnection();
      _startAutoRefresh();
    });
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _testConnection();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFluent = fluent_ui.FluentTheme.maybeOf(context) != null;
    final isCupertino = ThemeManager().isCupertinoFramework;

    if (isFluent) {
      return FluentSettingsGroup(
        title: '网络',
        children: [
          FluentSettingsTile(
            icon: Icons.dns,
            title: '后端源',
            subtitle: UrlService().getSourceDescription(),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBackendSourceDialogFluent(context),
          ),
          FluentSettingsTile(
            icon: Icons.music_note,
            title: '音源设置',
            subtitle: AudioSourceService().isConfigured
                ? AudioSourceService().getSourceDescription()
                : '未配置（点击配置）',
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onAudioSourceTap,
          ),
          FluentSettingsTile(
            icon: Icons.wifi_tethering,
            title: '测试连接',
            subtitle: _errorMessage != null ? '无法连接后端服务器' : '自动检测与后端服务器的连接',
            trailing: _buildLatencyIndicator(context),
          ),
        ],
      );
    }

    if (isCupertino) {
      return _buildCupertinoUI(context);
    }

    return MD3SettingsSection(
      children: [
        MD3SettingsTile(
          leading: const Icon(Icons.dns_outlined),
          title: '后端源',
          subtitle: UrlService().getSourceDescription(),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showBackendSourceDialog(context),
        ),
        MD3SettingsTile(
          leading: const Icon(Icons.music_note_outlined),
          title: '音源设置',
          subtitle: AudioSourceService().isConfigured
              ? AudioSourceService().getSourceDescription()
              : '未配置（点击配置）',
          trailing: const Icon(Icons.chevron_right),
          onTap: widget.onAudioSourceTap,
        ),
        MD3SettingsTile(
          leading: const Icon(Icons.wifi_tethering_outlined),
          title: '测试连接',
          subtitle: _errorMessage != null ? '无法连接后端服务器' : '自动检测与后端服务器的连接',
          trailing: _buildLatencyIndicator(context),
        ),
      ],
    );
  }

  /// 构建 Cupertino UI 版本
  Widget _buildCupertinoUI(BuildContext context) {
    return Column(
      children: [
        CupertinoSettingsTile(
          icon: CupertinoIcons.globe,
          iconColor: CupertinoColors.systemBlue,
          title: '后端源',
          subtitle: UrlService().getSourceDescription(),
          showChevron: true,
          onTap: () => _showBackendSourceDialogCupertino(context),
        ),
        const SizedBox(height: 1),
        CupertinoSettingsTile(
          icon: CupertinoIcons.music_note,
          iconColor: CupertinoColors.systemPurple,
          title: '音源设置',
          subtitle: AudioSourceService().isConfigured
              ? AudioSourceService().getSourceDescription()
              : '未配置（点击配置）',
          showChevron: true,
          onTap: widget.onAudioSourceTap,
        ),
        const SizedBox(height: 1),
        CupertinoSettingsTile(
          icon: CupertinoIcons.wifi,
          iconColor: CupertinoColors.systemGreen,
          title: '测试连接',
          subtitle: _errorMessage != null ? '无法连接后端服务器' : '自动检测与后端服务器的连接',
          trailing: _buildLatencyIndicatorCupertino(context),
        ),
      ],
    );
  }

  /// 构建 Cupertino 风格的延迟指示器
  Widget _buildLatencyIndicatorCupertino(BuildContext context) {
    if (_isTesting) {
      return const CupertinoActivityIndicator();
    }

    if (_isConnected == true) {
      return Text(
        'OK',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: CupertinoColors.systemGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return Text(
        '失联',
        style: TextStyle(
          color: CupertinoColors.systemRed,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Text(
      '--',
      style: TextStyle(
        color: CupertinoColors.systemGrey,
        fontWeight: FontWeight.bold,
      ),
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

  void _showCustomUrlDialogFluent(BuildContext context) {
    final controller = TextEditingController(text: UrlService().customBaseUrl);

    fluent_ui.showDialog(
      context: context,
      builder: (context) {
        return fluent_ui.ContentDialog(
          title: const Text('自定义后端源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fluent_ui.TextBox(
                controller: controller,
                placeholder: 'http://example.com:4055',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 8),
              const Text('不要在末尾添加斜杠'),
            ],
          ),
          actions: [
            fluent_ui.Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            fluent_ui.FilledButton(
              onPressed: () {
                final url = controller.text.trim();

                if (url.isEmpty) {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  if (messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('请输入后端地址')),
                    );
                  }
                  return;
                }

                if (!UrlService.isValidUrl(url)) {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  if (messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('URL 格式不正确')),
                    );
                  }
                  return;
                }

                UrlService().useCustomSource(url);
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (messenger != null) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('已切换到自定义源: $url')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showBackendSourceDialogFluent(BuildContext context) {
    fluent_ui.showDialog(
      context: context,
      builder: (context) {
        return fluent_ui.ContentDialog(
          title: const Text('选择后端源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fluent_ui.RadioButton(
                content: const Text('官方源'),
                checked: UrlService().sourceType == BackendSourceType.official,
                onChanged: (v) {
                  UrlService().useOfficialSource();
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  if (messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('已切换到官方源')),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              fluent_ui.RadioButton(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('自定义源'),
                    Text(
                      UrlService().customBaseUrl.isNotEmpty
                          ? UrlService().customBaseUrl
                          : '点击设置自定义地址',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                checked: UrlService().sourceType == BackendSourceType.custom,
                onChanged: (v) {
                  Navigator.pop(context);
                  _showCustomUrlDialogFluent(context);
                },
              ),
            ],
          ),
          actions: [
            fluent_ui.Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  void _showBackendSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择后端源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<BackendSourceType>(
              title: const Text('官方源'),
              subtitle: Text(
                '默认后端服务',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: BackendSourceType.official,
              groupValue: UrlService().sourceType,
              onChanged: (value) {
                UrlService().useOfficialSource();
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已切换到官方源')));
              },
            ),
            RadioListTile<BackendSourceType>(
              title: const Text('自定义源'),
              subtitle: Text(
                UrlService().customBaseUrl.isNotEmpty
                    ? UrlService().customBaseUrl
                    : '点击设置自定义地址',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: BackendSourceType.custom,
              groupValue: UrlService().sourceType,
              onChanged: (value) {
                Navigator.pop(context);
                _showCustomUrlDialog(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showCustomUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: UrlService().customBaseUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义后端源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请确保自定义源符合 OmniParse 标准',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '后端地址',
                hintText: 'http://example.com:4055',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
                helperText: '不要在末尾添加斜杠',
              ),
              keyboardType: TextInputType.url,
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
              final url = controller.text.trim();
              if (url.isEmpty) {
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (messenger != null) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('请输入后端地址')),
                  );
                }
                return;
              }
              if (!UrlService.isValidUrl(url)) {
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (messenger != null) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('URL 格式不正确')),
                  );
                }
                return;
              }
              UrlService().useCustomSource(url);
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.maybeOf(context);
              if (messenger != null) {
                messenger.showSnackBar(
                  SnackBar(content: Text('已切换到自定义源: $url')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 显示 Cupertino 风格的后端源选择对话框
  void _showBackendSourceDialogCupertino(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择后端源'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              UrlService().useOfficialSource();
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (UrlService().sourceType == BackendSourceType.official)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark, size: 18),
                  ),
                const Text('官方源'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showCustomUrlDialogCupertino(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (UrlService().sourceType == BackendSourceType.custom)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.checkmark, size: 18),
                  ),
                const Text('自定义源'),
                if (UrlService().customBaseUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    UrlService().customBaseUrl,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  /// 显示 Cupertino 风格的自定义 URL 对话框
  void _showCustomUrlDialogCupertino(BuildContext context) {
    final controller = TextEditingController(text: UrlService().customBaseUrl);

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('自定义后端源'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              CupertinoTextField(
                controller: controller,
                placeholder: 'http://example.com:4055',
                keyboardType: TextInputType.url,
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 8),
              Text(
                '不要在末尾添加斜杠',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final url = controller.text.trim();
              if (url.isEmpty) {
                return;
              }
              if (!UrlService.isValidUrl(url)) {
                return;
              }
              UrlService().useCustomSource(url);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildLatencyIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isTesting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_isConnected == true) {
      return Text(
        'OK',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      );
    }

    if (_errorMessage != null) {
      return Tooltip(
        message: _errorMessage!,
        child: Text(
          '失联',
          style: TextStyle(
            color: colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Text(
      '--',
      style: TextStyle(color: colorScheme.outline, fontWeight: FontWeight.bold),
    );
  }

  Future<void> _testConnection() async {
    if (_isTesting || !mounted) return;

    final baseUrl = UrlService().baseUrl;
    if (baseUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isConnected = null;
        _errorMessage = '未设置后端地址';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isTesting = true;
      _errorMessage = null;
    });

    try {
      await _checkConnection(baseUrl);
      if (!mounted) return;

      setState(() {
        _isConnected = true;
        _isTesting = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _isConnected = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _checkConnection(String baseUrl) async {
    final candidates = <Uri>[
      Uri.parse(UrlService().healthCheckUrl),
      Uri.parse('$baseUrl/info'),
    ];
    final attempted = <String>{};
    Object? lastError;

    for (final uri in candidates) {
      final key = uri.toString();
      if (!attempted.add(key)) continue;

      try {
        await _sendProbe(uri, method: 'HEAD');
        return;
      } catch (_) {
        try {
          await _sendProbe(uri, method: 'GET');
          return;
        } catch (e) {
          lastError = e;
        }
      }
    }

    throw lastError ?? Exception('无法连接后端服务器');
  }

  Future<void> _sendProbe(Uri uri, {required String method}) async {
    final client = http.Client();

    try {
      final request = http.Request(method, uri)
        ..headers['Cache-Control'] = 'no-cache'
        ..headers['Pragma'] = 'no-cache';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 10));

      await response.stream.drain<void>();
    } finally {
      client.close();
    }
  }
}
