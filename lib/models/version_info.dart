/// 版本信息模型
class VersionInfo {
  final String version;
  final String changelog;
  final bool forceUpdate;
  final String downloadUrl;
  final Map<String, String> platformDownloads;

  VersionInfo({
    required this.version,
    required this.changelog,
    required this.forceUpdate,
    required this.downloadUrl,
    Map<String, String>? platformDownloads,
  }) : platformDownloads = Map.unmodifiable(platformDownloads ?? {});

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final rawPlatformDownloads = json['platform_downloads'];
    Map<String, String>? downloads;
    if (rawPlatformDownloads is Map) {
      downloads = rawPlatformDownloads.map<String, String>(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    return VersionInfo(
      version: json['version'] as String,
      changelog: json['changelog'] as String,
      forceUpdate: json['force_update'] as bool,
      downloadUrl: json['download_url'] as String,
      platformDownloads: downloads,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'changelog': changelog,
      'force_update': forceUpdate,
      'download_url': downloadUrl,
      'platform_downloads': platformDownloads,
    };
  }

  String? platformDownloadUrl(String platformKey) {
    return platformDownloads[platformKey];
  }

  @override
  String toString() {
    return 'VersionInfo(version: $version, forceUpdate: $forceUpdate)';
  }
}

