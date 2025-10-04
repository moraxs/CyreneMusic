import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'url_service.dart';
import 'developer_mode_service.dart';
import 'location_service.dart';

/// 用户信息模型
class User {
  final int id;
  final String email;
  final String username;
  final bool isVerified;
  final String? lastLogin;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.isVerified,
    this.lastLogin,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      isVerified: json['isVerified'] ?? false,
      lastLogin: json['lastLogin'],
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'isVerified': isVerified,
      'lastLogin': lastLogin,
      'avatarUrl': avatarUrl,
    };
  }
}

/// 认证服务 - 管理用户登录状态
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _loadUserFromStorage();
  }

  User? _currentUser;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  
  /// 获取认证令牌（格式：user_{userId}）
  String? get token {
    if (_currentUser == null) return null;
    return 'user_${_currentUser!.id}';
  }

  /// 从本地存储加载用户信息
  Future<void> _loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      
      if (userJson != null && userJson.isNotEmpty) {
        final userData = jsonDecode(userJson);
        _currentUser = User.fromJson(userData);
        _isLoggedIn = true;
        print('👤 [AuthService] 从本地存储加载用户: ${_currentUser?.username}');
        notifyListeners();
      }
    } catch (e) {
      print('❌ [AuthService] 加载用户信息失败: $e');
    }
  }

  /// 保存用户信息到本地存储
  Future<void> _saveUserToStorage(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(user.toJson()));
      print('💾 [AuthService] 用户信息已保存到本地');
    } catch (e) {
      print('❌ [AuthService] 保存用户信息失败: $e');
    }
  }

  /// 清除本地存储的用户信息
  Future<void> _clearUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      print('🗑️ [AuthService] 已清除本地用户信息');
    } catch (e) {
      print('❌ [AuthService] 清除用户信息失败: $e');
    }
  }

  /// 发送注册验证码
  Future<Map<String, dynamic>> sendRegisterCode({
    required String email,
    required String username,
  }) async {
    try {
      final url = '${UrlService().baseUrl}/auth/register/send-code';
      final requestBody = {
        'email': email,
        'username': username,
      };
      
      DeveloperModeService().addLog('🌐 [Network] POST $url');
      DeveloperModeService().addLog('📤 [Network] 请求体: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      DeveloperModeService().addLog('📥 [Network] 状态码: ${response.statusCode}');
      DeveloperModeService().addLog('📄 [Network] 响应体: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        DeveloperModeService().addLog('✅ [AuthService] 验证码发送成功');
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        DeveloperModeService().addLog('❌ [AuthService] 验证码发送失败');
        return {
          'success': false,
          'message': data['message'] ?? '发送验证码失败',
        };
      }
    } catch (e) {
      DeveloperModeService().addLog('❌ [AuthService] 网络错误: $e');
      return {
        'success': false,
        'message': '网络错误: ${e.toString()}',
      };
    }
  }

  /// 用户注册
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    required String code,
  }) async {
    try {
      final url = '${UrlService().baseUrl}/auth/register';
      final requestBody = {
        'email': email,
        'username': username,
        'password': '***', // 密码不记录
        'code': code,
      };
      
      DeveloperModeService().addLog('🌐 [Network] POST $url');
      DeveloperModeService().addLog('📤 [Network] 请求体: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
          'code': code,
        }),
      );

      DeveloperModeService().addLog('📥 [Network] 状态码: ${response.statusCode}');
      DeveloperModeService().addLog('📄 [Network] 响应体: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        DeveloperModeService().addLog('✅ [AuthService] 用户注册成功: $username');
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        DeveloperModeService().addLog('❌ [AuthService] 注册失败');
        return {
          'success': false,
          'message': data['message'] ?? '注册失败',
        };
      }
    } catch (e) {
      DeveloperModeService().addLog('❌ [AuthService] 网络错误: $e');
      return {
        'success': false,
        'message': '网络错误: ${e.toString()}',
      };
    }
  }

  /// 用户登录
  Future<Map<String, dynamic>> login({
    required String account,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${UrlService().baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'account': account,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        _currentUser = User.fromJson(data['data']);
        _isLoggedIn = true;
        
        // 保存用户信息到本地
        await _saveUserToStorage(_currentUser!);
        
        notifyListeners();
        
        return {
          'success': true,
          'message': data['message'],
          'user': _currentUser,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '登录失败',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '网络错误: ${e.toString()}',
      };
    }
  }

  /// 发送重置密码验证码
  Future<Map<String, dynamic>> sendResetCode({
    required String email,
  }) async {
    try {
      final url = '${UrlService().baseUrl}/auth/reset-password/send-code';
      final requestBody = {'email': email};
      
      DeveloperModeService().addLog('🌐 [Network] POST $url');
      DeveloperModeService().addLog('📤 [Network] 请求体: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      DeveloperModeService().addLog('📥 [Network] 状态码: ${response.statusCode}');
      DeveloperModeService().addLog('📄 [Network] 响应体: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        DeveloperModeService().addLog('✅ [AuthService] 重置验证码发送成功');
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        DeveloperModeService().addLog('❌ [AuthService] 验证码发送失败');
        return {
          'success': false,
          'message': data['message'] ?? '发送验证码失败',
        };
      }
    } catch (e) {
      DeveloperModeService().addLog('❌ [AuthService] 网络错误: $e');
      return {
        'success': false,
        'message': '网络错误: ${e.toString()}',
      };
    }
  }

  /// 重置密码
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final url = '${UrlService().baseUrl}/auth/reset-password';
      final requestBody = {
        'email': email,
        'code': code,
        'newPassword': '***', // 密码不记录
      };
      
      DeveloperModeService().addLog('🌐 [Network] POST $url');
      DeveloperModeService().addLog('📤 [Network] 请求体: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      );

      DeveloperModeService().addLog('📥 [Network] 状态码: ${response.statusCode}');
      DeveloperModeService().addLog('📄 [Network] 响应体: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        DeveloperModeService().addLog('✅ [AuthService] 密码重置成功');
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        DeveloperModeService().addLog('❌ [AuthService] 密码重置失败');
        return {
          'success': false,
          'message': data['message'] ?? '重置密码失败',
        };
      }
    } catch (e) {
      DeveloperModeService().addLog('❌ [AuthService] 网络错误: $e');
      return {
        'success': false,
        'message': '网络错误: ${e.toString()}',
      };
    }
  }

  /// 登出
  Future<void> logout() async {
    final username = _currentUser?.username;
    _currentUser = null;
    _isLoggedIn = false;
    
    // 清除本地存储
    await _clearUserFromStorage();
    
    // 清除收藏列表（需要在这里导入 FavoriteService，但为避免循环依赖，改为在 FavoriteService 中监听登出）
    
    DeveloperModeService().addLog('👋 [AuthService] 用户退出登录: $username');
    
    notifyListeners();
  }

  /// 更新用户IP归属地
  Future<Map<String, dynamic>> updateLocation() async {
    // 检查用户是否已登录
    if (!_isLoggedIn || _currentUser == null) {
      DeveloperModeService().addLog('⚠️ [AuthService] 用户未登录，无法更新IP归属地');
      return {
        'success': false,
        'message': '用户未登录',
      };
    }

    try {
      // 获取IP归属地信息
      DeveloperModeService().addLog('🌍 [AuthService] 开始获取IP归属地...');
      final locationInfo = await LocationService().fetchLocation();
      
      if (locationInfo == null) {
        DeveloperModeService().addLog('❌ [AuthService] 获取IP归属地失败');
        return {
          'success': false,
          'message': '获取IP归属地失败',
        };
      }

      // 准备发送到后端的数据
      final url = '${UrlService().baseUrl}/auth/update-location';
      final requestBody = {
        'userId': _currentUser!.id,
        'ip': locationInfo.ip,
        'location': locationInfo.shortDescription,
      };

      DeveloperModeService().addLog('🌐 [Network] POST $url');
      DeveloperModeService().addLog('📤 [Network] 请求体: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      DeveloperModeService().addLog('📥 [Network] 状态码: ${response.statusCode}');
      DeveloperModeService().addLog('📄 [Network] 响应体: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        DeveloperModeService().addLog('✅ [AuthService] IP归属地更新成功: ${locationInfo.shortDescription}');
        return {
          'success': true,
          'message': data['message'],
          'data': {
            'ip': locationInfo.ip,
            'location': locationInfo.shortDescription,
          },
        };
      } else {
        DeveloperModeService().addLog('❌ [AuthService] IP归属地更新失败');
        return {
          'success': false,
          'message': data['message'] ?? '更新IP归属地失败',
        };
      }
    } catch (e) {
      DeveloperModeService().addLog('❌ [AuthService] 更新IP归属地异常: $e');
      return {
        'success': false,
        'message': '网络错误: ${e.toString()}',
      };
    }
  }
}
