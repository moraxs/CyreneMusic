/// 版本信息模型
class VersionInfo {
  final String version;
  final String changelog;
  final bool forceUpdate;
  final String downloadUrl;

  VersionInfo({
    required this.version,
    required this.changelog,
    required this.forceUpdate,
    required this.downloadUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'] as String,
      changelog: json['changelog'] as String,
      forceUpdate: json['force_update'] as bool,
      downloadUrl: json['download_url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'changelog': changelog,
      'force_update': forceUpdate,
      'download_url': downloadUrl,
    };
  }

  @override
  String toString() {
    return 'VersionInfo(version: $version, forceUpdate: $forceUpdate)';
  }
}

