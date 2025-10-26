import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// IP 归属地信息模型
class LocationInfo {
  final String ip;
  final String country;
  final String province;
  final String city;
  final String isp;
  final String latitude;
  final String longitude;

  LocationInfo({
    required this.ip,
    required this.country,
    required this.province,
    required this.city,
    required this.isp,
    required this.latitude,
    required this.longitude,
  });

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? {};
    return LocationInfo(
      ip: json['ip'] ?? '',
      country: location['country'] ?? '',
      province: location['province'] ?? '',
      city: location['city'] ?? '',
      isp: location['isp'] ?? '',
      latitude: location['latitude'] ?? '',
      longitude: location['longitude'] ?? '',
    );
  }

  /// 获取简短的归属地描述
  String get shortDescription {
    if (country.isEmpty) return '未知';
    
    // 如果是中国，显示省份和城市
    if (country == '中国') {
      if (province.isNotEmpty && city.isNotEmpty) {
        return '$province $city';
      } else if (province.isNotEmpty) {
        return province;
      } else if (city.isNotEmpty) {
        return city;
      }
      return country;
    }
    
    // 其他国家只显示国家名
    return country;
  }

  /// 获取完整的归属地描述
  String get fullDescription {
    final parts = <String>[];
    
    if (country.isNotEmpty) parts.add(country);
    if (province.isNotEmpty && province != country) parts.add(province);
    if (city.isNotEmpty) parts.add(city);
    
    return parts.isNotEmpty ? parts.join(' ') : '未知';
  }
}

/// IP 归属地服务
class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// IP 归属地查询 API
  static const String locationApiUrl = 'https://drive-backend.cyrene.ltd/api/userip';

  LocationInfo? _currentLocation;
  bool _isLoading = false;
  String? _errorMessage;

  LocationInfo? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLocation => _currentLocation != null;

  /// 获取当前 IP 归属地
  Future<LocationInfo?> fetchLocation() async {
    print('🌍 [LocationService] 开始获取IP归属地...');
    print('🌍 [LocationService] API URL: $locationApiUrl');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🌍 [LocationService] 发送 HTTP GET 请求...');
      
      final response = await http.get(
        Uri.parse(locationApiUrl),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ [LocationService] 请求超时！');
          throw Exception('请求超时');
        },
      );

      print('🌍 [LocationService] 收到响应 - 状态码: ${response.statusCode}');
      print('🌍 [LocationService] 响应体: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ [LocationService] 响应成功，开始解析JSON...');
        
        final data = jsonDecode(response.body);
        print('🌍 [LocationService] JSON 解析成功: $data');
        
        _currentLocation = LocationInfo.fromJson(data);
        print('✅ [LocationService] LocationInfo 创建成功');
        print('🌍 [LocationService] IP: ${_currentLocation?.ip}');
        print('🌍 [LocationService] 归属地: ${_currentLocation?.shortDescription}');
        
        _isLoading = false;
        notifyListeners();
        print('✅ [LocationService] 获取IP归属地完成！');
        return _currentLocation;
      } else {
        print('❌ [LocationService] 请求失败 - 状态码: ${response.statusCode}');
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ [LocationService] 发生错误: $e');
      print('❌ [LocationService] 错误堆栈: $stackTrace');
      
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// 清除位置信息
  void clearLocation() {
    _currentLocation = null;
    _errorMessage = null;
    notifyListeners();
  }
}

