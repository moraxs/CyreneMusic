import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/netease_login_service.dart';
import 'netease_qr_dialog.dart';

/// 第三方账号管理组件
class ThirdPartyAccounts extends StatefulWidget {
  const ThirdPartyAccounts({super.key});

  @override
  State<ThirdPartyAccounts> createState() => _ThirdPartyAccountsState();
}

class _ThirdPartyAccountsState extends State<ThirdPartyAccounts> {
  int _refreshKey = 0;

  void _refresh() {
    if (mounted) {
      setState(() {
        _refreshKey++;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    AuthService().addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    
    // 如果未登录，不显示此组件
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '第三方账号'),
        Card(
          child: Column(
            children: [
              // 提示信息
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '绑定第三方账号后，我们可以为您定制首页推荐内容',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // 网易云音乐账号
              FutureBuilder<Map<String, dynamic>>(
                key: ValueKey(_refreshKey),
                future: NeteaseLoginService().fetchBindings(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.cloud),
                      ),
                      title: Text('网易云音乐'),
                      subtitle: Text('加载中...'),
                      trailing: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final bindings = snapshot.data?['data'] as Map<String, dynamic>?;
                  final netease = bindings?['netease'] as Map<String, dynamic>?;
                  final bound = (netease != null) && (netease['bound'] == true);
                  final nickname = netease?['nickname'] as String?;
                  final avatarUrl = netease?['avatarUrl'] as String?;
                  final neteaseUserId = netease?['userId'] as String?;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? const Icon(Icons.cloud) : null,
                    ),
                    title: const Text('网易云音乐'),
                    subtitle: bound
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('昵称: ${nickname ?? '-'}'),
                              Text(
                                '用户ID: ${neteaseUserId ?? '-'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          )
                        : const Text('未绑定'),
                    trailing: bound
                        ? OutlinedButton.icon(
                            onPressed: () => _showUnbindDialog(context),
                            icon: const Icon(Icons.link_off, size: 18),
                            label: const Text('解绑'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: () => _bindNetease(context, user.id),
                            icon: const Icon(Icons.qr_code, size: 18),
                            label: const Text('去绑定'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                  );
                },
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

  Future<void> _bindNetease(BuildContext context, int userId) async {
    final success = await showNeteaseQrDialog(context, userId);
    if (success == true) {
      _refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('网易云账号绑定成功！现在可以为您定制首页了'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showUnbindDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded),
            SizedBox(width: 8),
            Text('解绑网易云账号'),
          ],
        ),
        content: const Text('解绑后将无法为您定制首页推荐内容，确定要解绑吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 显示加载提示
              if (context.mounted) {
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
                        Text('正在解绑...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              }

              final ok = await NeteaseLoginService().unbindNetease();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '已解绑网易云账号' : '解绑失败，请重试'),
                    backgroundColor: ok ? Colors.orange : Colors.red,
                  ),
                );
                
                if (ok) {
                  _refresh();
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('解绑'),
          ),
        ],
      ),
    );
  }
}

