import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/url_service.dart';

/// 网络设置组件
class NetworkSettings extends StatelessWidget {
  const NetworkSettings({super.key});

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
                subtitle: const Text('测试与后端服务器的连接'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _testConnection(context),
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

  Future<void> _testConnection(BuildContext context) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final baseUrl = UrlService().baseUrl;
    bool isSuccess = false;
    String errorMessage = '';

    try {
      final response = await http.get(
        Uri.parse(baseUrl),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('连接超时');
        },
      );

      if (response.statusCode == 200 && response.body.trim() == 'OK') {
        isSuccess = true;
      } else {
        errorMessage = '响应码: ${response.statusCode}\n响应内容: ${response.body}';
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    if (!context.mounted) return;
    
    // 关闭加载对话框
    Navigator.pop(context);

    // 显示结果对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            const Text('连接测试'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              UrlService().isUsingOfficialSource
                  ? '官方源'
                  : '后端地址: $baseUrl',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSuccess
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.done : Icons.close,
                    color: isSuccess
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSuccess ? '连接成功' : '连接失败',
                      style: TextStyle(
                        color: isSuccess
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isSuccess) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '错误详情:',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      errorMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
  }
}

