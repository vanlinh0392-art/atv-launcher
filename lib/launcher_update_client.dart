import 'dart:convert';
import 'dart:io';

class LauncherUpdateClient {
  static const String githubOwner = 'xfire0392-netizen';
  static const String githubRepo = 'atv-launcher';

  final HttpClient Function() _httpClientFactory;

  LauncherUpdateClient({
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static Uri get latestReleaseUri => Uri.https(
        'api.github.com',
        '/repos/$githubOwner/$githubRepo/releases/latest',
      );

  Future<LauncherUpdateRelease> fetchLatestRelease() async {
    final client = _httpClientFactory();
    try {
      final request = await client.getUrl(latestReleaseUri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ATVLauncher/$githubOwner-$githubRepo',
      );
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'GitHub release check failed with HTTP ${response.statusCode}.',
          uri: latestReleaseUri,
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('GitHub latest release response is invalid.');
      }
      return LauncherUpdateRelease.fromGitHubJson(decoded);
    } finally {
      client.close(force: true);
    }
  }
}

class LauncherUpdateRelease {
  final String tagName;
  final String name;
  final String htmlUrl;
  final DateTime? publishedAt;
  final String body;
  final List<LauncherUpdateAsset> assets;

  const LauncherUpdateRelease({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    required this.publishedAt,
    required this.body,
    required this.assets,
  });

  factory LauncherUpdateRelease.fromGitHubJson(Map<String, dynamic> json) {
    final rawAssets = (json['assets'] as List?) ?? const [];
    return LauncherUpdateRelease(
      tagName: json['tag_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      htmlUrl: json['html_url']?.toString() ?? '',
      publishedAt: _parseDateTime(json['published_at']?.toString()),
      body: json['body']?.toString() ?? '',
      assets: rawAssets
          .whereType<Map>()
          .map(
            (asset) => LauncherUpdateAsset.fromGitHubJson(
              asset.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }

  String get displayName => name.trim().isNotEmpty ? name : tagName.trim();

  LauncherUpdateAsset? get preferredApkAsset {
    final apkAssets = assets
        .where(
          (asset) => asset.name.toLowerCase().trim().endsWith('.apk'),
        )
        .toList(growable: false);
    if (apkAssets.isEmpty) {
      return null;
    }
    apkAssets.sort(
      (left, right) => _apkAssetScore(right).compareTo(_apkAssetScore(left)),
    );
    return apkAssets.first;
  }

  bool matchesInstalledVersion(String installedVersion) {
    final normalizedInstalled = normalizeVersionToken(installedVersion);
    if (normalizedInstalled.isEmpty) {
      return false;
    }
    final candidates = <String>[
      tagName,
      name,
      preferredApkAsset?.name ?? '',
    ];
    for (final candidate in candidates) {
      final normalizedCandidate = normalizeVersionToken(candidate);
      if (normalizedCandidate.isEmpty) {
        continue;
      }
      if (normalizedCandidate == normalizedInstalled ||
          normalizedCandidate.contains(normalizedInstalled) ||
          normalizedInstalled.contains(normalizedCandidate)) {
        return true;
      }
    }
    return false;
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  static int _apkAssetScore(LauncherUpdateAsset asset) {
    final name = asset.name.toLowerCase();
    var score = 0;
    if (name.endsWith('.apk')) {
      score += 200;
    }
    if (name.contains('release')) {
      score += 90;
    }
    if (!name.contains('debug')) {
      score += 25;
    }
    if (name.contains('armeabi') || name.contains('v7a') || name.contains('arm')) {
      score += 18;
    }
    if (name.contains('universal')) {
      score -= 8;
    }
    score += asset.downloadCount;
    return score;
  }
}

class LauncherUpdateAsset {
  final String name;
  final String browserDownloadUrl;
  final int sizeBytes;
  final int downloadCount;
  final String contentType;

  const LauncherUpdateAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.sizeBytes,
    required this.downloadCount,
    required this.contentType,
  });

  factory LauncherUpdateAsset.fromGitHubJson(Map<String, dynamic> json) {
    return LauncherUpdateAsset(
      name: json['name']?.toString() ?? '',
      browserDownloadUrl: json['browser_download_url']?.toString() ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
      contentType: json['content_type']?.toString() ?? '',
    );
  }

  Uri? get downloadUri => Uri.tryParse(browserDownloadUrl);
}

String normalizeVersionToken(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) {
    return '';
  }
  final match = RegExp(r'(?:v)?(\d{4}\.\d{2}(?:\.\d+)?(?:\+\d+)?)').firstMatch(value);
  if (match != null) {
    return match.group(1) ?? '';
  }
  return value
      .replaceAll(RegExp(r'[^0-9a-z.+-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String formatUpdateFileSize(int sizeBytes) {
  if (sizeBytes <= 0) {
    return '0 B';
  }
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var size = sizeBytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  final precision = size >= 10 || unitIndex == 0 ? 0 : 1;
  final formatted = size.toStringAsFixed(precision);
  final normalized = formatted.endsWith('.0')
      ? formatted.substring(0, formatted.length - 2)
      : formatted;
  return '$normalized ${units[unitIndex]}';
}
