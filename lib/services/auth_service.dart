import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'url_service.dart';

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
  AuthService._internal();

  User? _currentUser;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  /// 发送注册验证码
  Future<Map<String, dynamic>> sendRegisterCode({
    required String email,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${UrlService().baseUrl}/auth/register/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '发送验证码失败',
        };
      }
    } catch (e) {
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
      final response = await http.post(
        Uri.parse('${UrlService().baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
          'code': code,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '注册失败',
        };
      }
    } catch (e) {
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
      final response = await http.post(
        Uri.parse('${UrlService().baseUrl}/auth/reset-password/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '发送验证码失败',
        };
      }
    } catch (e) {
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
      final response = await http.post(
        Uri.parse('${UrlService().baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '重置密码失败',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '网络错误: ${e.toString()}',
      };
    }
  }

  /// 登出
  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
