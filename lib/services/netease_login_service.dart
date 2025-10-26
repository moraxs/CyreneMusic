import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'url_service.dart';
import 'auth_service.dart';

class NeteaseQrCreateResult {
  final String key;
  final String? qrimg;
  final String qrUrl;
  NeteaseQrCreateResult({required this.key, required this.qrUrl, this.qrimg});
}

class NeteaseQrCheckResult {
  final int code; // 800 801 802 803
  final String? message;
  final Map<String, dynamic>? profile;
  NeteaseQrCheckResult({required this.code, this.message, this.profile});
}

class NeteaseLoginService extends ChangeNotifier {
  static final NeteaseLoginService _instance = NeteaseLoginService._internal();
  factory NeteaseLoginService() => _instance;
  NeteaseLoginService._internal();

  Future<NeteaseQrCreateResult> createQrKey() async {
    // align with reference: first get key, then build login url; optional create
    final keyResp = await http.get(Uri.parse(UrlService().neteaseQrKeyUrl)).timeout(const Duration(seconds: 10));
    if (keyResp.statusCode != 200) {
      throw Exception('HTTP ${keyResp.statusCode}');
    }
    final keyData = json.decode(utf8.decode(keyResp.bodyBytes)) as Map<String, dynamic>;
    if ((keyData['code'] as int?) != 200) {
      throw Exception(keyData['message'] ?? '获取二维码 key 失败');
    }
    final unikey = (keyData['data'] as Map<String, dynamic>)['unikey'] as String;
    final qrUrl = 'https://music.163.com/login?codekey=$unikey';

    // optional: try create image (not required since we render locally)
    try {
      await http.get(Uri.parse('${UrlService().neteaseQrCreateUrl}?key=$unikey&qrimg=true&timestamp=${DateTime.now().millisecondsSinceEpoch}'));
    } catch (_) {}

    return NeteaseQrCreateResult(key: unikey, qrUrl: qrUrl);
  }

  Future<NeteaseQrCheckResult> checkQrStatus({required String key, int? userId}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final primary = Uri.parse('${UrlService().neteaseQrCheckUrl}?key=$key${userId != null ? '&userId=$userId' : ''}&timestamp=$ts');

    Future<Map<String, dynamic>> doGet(Uri u) async {
      final r = await http.get(u).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) {
        throw Exception('HTTP ${r.statusCode}');
      }
      return json.decode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    }

    Map<String, dynamic> data = await doGet(primary);

    // 兼容老服务路径：若返回 404/接口未找到，则尝试 /netease/login/qr/check
    final codeVal = data['code'];
    final msgVal = (data['message'] ?? data['msg']) as String?;
    if ((codeVal == 404 || (msgVal != null && msgVal.contains('接口未找到'))) && UrlService().neteaseQrCheckUrl.contains('/login/qr/check')) {
      final altUrl = UrlService().neteaseQrCheckUrl.replaceFirst('/login/qr/check', '/netease/login/qr/check');
      final alt = Uri.parse('$altUrl?key=$key${userId != null ? '&userId=$userId' : ''}&timestamp=$ts');
      data = await doGet(alt);
    }

    // 后端直接返回二维码状态码：800/801/802/803
    final statusCode = (data['code'] as num?)?.toInt();
    if (statusCode == null) {
      throw Exception('无效响应');
    }

    return NeteaseQrCheckResult(
      code: statusCode,
      message: (data['message'] ?? data['msg']) as String?,
      profile: data['profile'] as Map<String, dynamic>?,
    );
  }

  // ===== Third-party accounts =====
  Future<Map<String, dynamic>> fetchBindings() async {
    final token = AuthService().token;
    final r = await http.get(
      Uri.parse(UrlService().accountsBindingsUrl),
      headers: token != null ? { 'Authorization': 'Bearer $token' } : {},
    ).timeout(const Duration(seconds: 10));
    final data = json.decode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return data;
  }

  Future<bool> unbindNetease() async {
    final token = AuthService().token;
    final r = await http.delete(
      Uri.parse(UrlService().accountsUnbindNeteaseUrl),
      headers: token != null ? { 'Authorization': 'Bearer $token' } : {},
    ).timeout(const Duration(seconds: 10));
    return r.statusCode == 200;
  }
}


