import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/url_service.dart';

/// 网络设置组件
class NetworkSettings extends StatefulWidget {
  const NetworkSettings({super.key});

  @override
  State<NetworkSettings> createState() => _NetworkSettingsState();
}

class _NetworkSettingsState extends State<NetworkSettings> {
  bool _isTesting = false;
  int? _latencyMs;
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
    setState(() {});
    _testConnection();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _testConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '网络'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.dns),
                title: const Text('后端源'),
                subtitle: Text(UrlService().getSourceDescription()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBackendSourceDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.wifi_tethering),
                title: const Text('测试连接'),
                subtitle: Text(
                  _errorMessage != null
                      ? '无法连接后端服务器'
                      : '自动检测与后端服务器的连接',
                ),
                trailing: _buildLatencyIndicator(context),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已切换到官方源')),
                );
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
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入后端地址')),
                );
                return;
              }
              
              if (!UrlService.isValidUrl(url)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL 格式不正确')),
                );
                return;
              }
              
              UrlService().useCustomSource(url);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已切换到自定义源: $url')),
              );
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

    if (_latencyMs != null) {
      final latency = _latencyMs!.clamp(0, 9999);
      Color displayColor;
      if (latency <= 100) {
        displayColor = Colors.green;
      } else if (latency <= 300) {
        displayColor = Colors.orange;
      } else {
        displayColor = colorScheme.error;
      }

      return Text(
        '${latency} ms',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: displayColor,
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
      style: TextStyle(
        color: colorScheme.outline,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;

    final baseUrl = UrlService().baseUrl;
    if (baseUrl.isEmpty) {
      setState(() {
        _latencyMs = null;
        _errorMessage = '未设置后端地址';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _errorMessage = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$baseUrl/info');
      await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      stopwatch.stop();
      if (!mounted) return;

      setState(() {
        _latencyMs = stopwatch.elapsedMilliseconds == 0
            ? 1
            : stopwatch.elapsedMilliseconds;
        _isTesting = false;
        _errorMessage = null;
      });
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _latencyMs = null;
        _errorMessage = e.toString();
      });
    }
  }
}

