import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:http/http.dart' as http;

/// 本地 HTTP 代理服务
/// 用于处理 QQ 音乐等需要特殊请求头的音频流
class ProxyService {
  static final ProxyService _instance = ProxyService._internal();
  factory ProxyService() => _instance;
  ProxyService._internal();

  HttpServer? _server;
  int _port = 8888;
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  int get port => _port;

  /// 启动代理服务器
  Future<bool> start() async {
    if (_isRunning) {
      print('🌐 [ProxyService] 代理服务器已在运行');
      return true;
    }

    try {
      // 尝试多个端口，避免端口冲突
      for (int port = 8888; port < 8898; port++) {
        try {
          _server = await shelf_io.serve(
            _handleRequest,
            InternetAddress.loopbackIPv4,
            port,
          );
          _port = port;
          _isRunning = true;
          print('✅ [ProxyService] 代理服务器已启动: http://localhost:$_port');
          return true;
        } catch (e) {
          // 端口被占用，尝试下一个
          if (port == 8897) {
            throw Exception('无法找到可用端口');
          }
        }
      }
      return false;
    } catch (e) {
      print('❌ [ProxyService] 启动代理服务器失败: $e');
      _isRunning = false;
      return false;
    }
  }

  /// 停止代理服务器
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _isRunning = false;
      print('⏹️ [ProxyService] 代理服务器已停止');
    }
  }

  /// 处理代理请求
  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    try {
      // 获取原始 URL
      final targetUrl = request.url.queryParameters['url'];
      if (targetUrl == null || targetUrl.isEmpty) {
        return shelf.Response.badRequest(body: 'Missing url parameter');
      }

      // 获取平台类型（用于设置不同的 referer）
      final platform = request.url.queryParameters['platform'] ?? 'qq';

      print('🌐 [ProxyService] 代理请求: $targetUrl');

      // 设置请求头
      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      };

      // 根据平台设置 referer
      if (platform == 'qq') {
        headers['referer'] = 'https://y.qq.com';
      } else if (platform == 'kugou') {
        headers['referer'] = 'https://www.kugou.com';
      }

      // 发起请求（使用流式传输）
      final client = http.Client();
      final streamedRequest = http.Request('GET', Uri.parse(targetUrl));
      streamedRequest.headers.addAll(headers);

      final streamedResponse = await client.send(streamedRequest);

      if (streamedResponse.statusCode == 200) {
        // 设置响应头
        final responseHeaders = {
          'Content-Type': streamedResponse.headers['content-type'] ?? 'audio/mpeg',
          'Accept-Ranges': 'bytes',
          'Cache-Control': 'no-cache',
        };

        // 如果有 Content-Length，也传递给客户端
        if (streamedResponse.headers['content-length'] != null) {
          responseHeaders['Content-Length'] = streamedResponse.headers['content-length']!;
        }

        print('✅ [ProxyService] 开始流式传输音频数据');

        // 流式传输响应数据
        return shelf.Response.ok(
          streamedResponse.stream,
          headers: responseHeaders,
        );
      } else {
        print('❌ [ProxyService] 上游服务器返回: ${streamedResponse.statusCode}');
        return shelf.Response(
          streamedResponse.statusCode,
          body: 'Upstream server error: ${streamedResponse.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ [ProxyService] 处理请求失败: $e');
      print('Stack trace: $stackTrace');
      return shelf.Response.internalServerError(
        body: 'Proxy error: $e',
      );
    }
  }

  /// 生成代理 URL
  String getProxyUrl(String originalUrl, String platform) {
    if (!_isRunning) {
      print('⚠️ [ProxyService] 代理服务器未运行，返回原始 URL');
      return originalUrl;
    }
    
    final encodedUrl = Uri.encodeComponent(originalUrl);
    final proxyUrl = 'http://localhost:$_port/proxy?url=$encodedUrl&platform=$platform';
    
    print('🔗 [ProxyService] 生成代理 URL: $proxyUrl');
    return proxyUrl;
  }

  /// 清理资源
  Future<void> dispose() async {
    await stop();
  }
}

