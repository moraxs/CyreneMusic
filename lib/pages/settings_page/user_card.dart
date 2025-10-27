import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../auth/auth_page.dart';

/// 用户卡片组件
class UserCard extends StatefulWidget {
  const UserCard({super.key});

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  @override
  void initState() {
    super.initState();
    AuthService().addListener(_onAuthChanged);
    LocationService().addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    LocationService().removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService().isLoggedIn;
    final user = AuthService().currentUser;
    
    if (!isLoggedIn || user == null) {
      return _buildLoginCard(context);
    }
    
    return _buildUserInfoCard(context, user);
  }

  /// 构建登录卡片（未登录状态）
  Widget _buildLoginCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '未登录',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '登录后可享受更多功能',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => _handleLogin(context),
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建用户信息卡片（已登录状态）
  Widget _buildUserInfoCard(BuildContext context, User user) {
    final colorScheme = Theme.of(context).colorScheme;
    final qqNumber = _extractQQNumber(user.email);
    final avatarUrl = _getQQAvatarUrl(qqNumber);
    
    return AnimatedBuilder(
      animation: LocationService(),
      builder: (context, child) {
        final location = LocationService().currentLocation;
        final isLoadingLocation = LocationService().isLoading;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // QQ 头像
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: avatarUrl != null 
                          ? NetworkImage(avatarUrl) 
                          : null,
                      child: avatarUrl == null 
                          ? Icon(
                              Icons.person,
                              size: 32,
                              color: colorScheme.onPrimaryContainer,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 用户名
                          Text(
                            user.username,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 邮箱
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // IP 归属地
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              if (isLoadingLocation)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '获取中...',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                )
                              else if (location != null)
                                Expanded(
                                  child: Text(
                                    location.shortDescription,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              else
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        '获取失败',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.error,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () {
                                          print('🔄 [UserCard] 手动刷新IP归属地...');
                                          LocationService().fetchLocation();
                                        },
                                        child: Icon(
                                          Icons.refresh,
                                          size: 14,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout),
                      tooltip: '退出登录',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 从邮箱中提取 QQ 号
  String? _extractQQNumber(String email) {
    final qqEmailPattern = RegExp(r'^(\d+)@qq\.com$');
    final match = qqEmailPattern.firstMatch(email.toLowerCase());
    
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    
    return null;
  }

  /// 获取 QQ 头像 URL
  String? _getQQAvatarUrl(String? qqNumber) {
    if (qqNumber == null || qqNumber.isEmpty) {
      return null;
    }
    
    return 'https://q1.qlogo.cn/g?b=qq&nk=$qqNumber&s=100';
  }

  /// 处理登录
  Future<void> _handleLogin(BuildContext context) async {
    print('👤 [UserCard] 打开登录页面...');
    
    final result = await showAuthDialog(context);
    
    print('👤 [UserCard] 登录页面返回，结果: $result');
    
    if (result == true && AuthService().isLoggedIn) {
      print('👤 [UserCard] 登录成功，开始获取IP归属地...');
      LocationService().fetchLocation();
    }
  }

  /// 处理退出登录
  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              AuthService().logout();
              LocationService().clearLocation();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出登录')),
              );
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

}

