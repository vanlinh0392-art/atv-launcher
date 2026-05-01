import 'dart:convert';
import 'dart:io';

class LauncherUpdateClient {
  static const String githubOwner = 'xfire0392-netizen';
  static const String githubRepo = 'atv-launcher';
  static const String officialChannelSlug = 'xfire0392-netizen-official';
  static const String officialChannelMarker =
      'Updater-Channel: $officialChannelSlug';
  static const int releasePageSize = 50;
  static const int maxReleasePages = 6;

  final HttpClient Function() _httpClientFactory;
  final Uri? _releasesBaseUriOverride;

  LauncherUpdateClient({
    HttpClient Function()? httpClientFactory,
    Uri? releasesBaseUri,
  })  : _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _releasesBaseUriOverride = releasesBaseUri;

  static Uri _defaultReleasesUri(int page) => Uri.https(
        'api.github.com',
        '/repos/$githubOwner/$githubRepo/releases',
        <String, String>{
          'per_page': '$releasePageSize',
          'page': '$page',
        },
      );

  Uri _releasePageUri(int page) {
    final override = _releasesBaseUriOverride;
    if (override == null) {
      return _defaultReleasesUri(page).replace(
        queryParameters: <String, String>{
          ..._defaultReleasesUri(page).queryParameters,
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
    }
    return override.replace(
      queryParameters: <String, String>{
        ...override.queryParameters,
        'per_page': '$releasePageSize',
        'page': '$page',
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  Future<LauncherUpdateRelease?> fetchLatestOfficialRelease() async {
    for (var page = 1; page <= maxReleasePages; page += 1) {
      final decoded = await _fetchJson(_releasePageUri(page));
      if (decoded is! List) {
        throw const FormatException('GitHub releases response is invalid.');
      }
      final releases = decoded
          .whereType<Map>()
          .map(
            (release) => LauncherUpdateRelease.fromGitHubJson(
              release.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false);
      final selected =
          LauncherUpdateRelease.pickLatestOfficialRelease(releases);
      if (selected != null) {
        return selected;
      }
      if (releases.length < releasePageSize) {
        break;
      }
    }
    return null;
  }

  Future<LauncherDownloadedApk> downloadApkAsset({
    required LauncherUpdateAsset asset,
    required File destinationFile,
    required void Function(LauncherUpdateDownloadProgress progress) onProgress,
  }) async {
    final downloadUri = asset.downloadUri;
    if (downloadUri == null) {
      throw const FormatException('GitHub APK asset URL is invalid.');
    }

    final client = _httpClientFactory();
    IOSink? sink;
    try {
      final request = await client.getUrl(downloadUri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ATVLauncher/$githubOwner-$githubRepo',
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'GitHub asset download failed with HTTP ${response.statusCode}.',
          uri: downloadUri,
        );
      }

      sink = destinationFile.openWrite();
      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastProgressAt).inMilliseconds >= 120 ||
            (totalBytes > 0 && receivedBytes >= totalBytes)) {
          lastProgressAt = now;
          onProgress(
            LauncherUpdateDownloadProgress(
              fileName: asset.name,
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
            ),
          );
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      return LauncherDownloadedApk(
        fileName: asset.name,
        filePath: destinationFile.path,
      );
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }

  Future<dynamic> _fetchJson(Uri uri) async {
    final client = _httpClientFactory();
    try {
      final request = await client.getUrl(uri);
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ATVLauncher/$githubOwner-$githubRepo',
      );
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'GitHub release check failed with HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      return jsonDecode(body);
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
  final bool isDraft;
  final bool isPrerelease;
  final List<LauncherUpdateAsset> assets;

  const LauncherUpdateRelease({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    required this.publishedAt,
    required this.body,
    required this.isDraft,
    required this.isPrerelease,
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
      isDraft: json['draft'] == true,
      isPrerelease: json['prerelease'] == true,
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
    final apkAssets = eligibleApkAssets.toList(growable: false);
    if (apkAssets.isEmpty) {
      return null;
    }
    apkAssets.sort(_compareApkAssets);
    return apkAssets.first;
  }

  Iterable<LauncherUpdateAsset> get eligibleApkAssets =>
      assets.where((asset) => asset.isOfficialApkAsset);

  bool get isOfficialRelease =>
      !isDraft &&
      !isPrerelease &&
      !_looksLikeDebugRelease &&
      _hasOfficialChannelMarker &&
      _looksLikeManagedRelease &&
      preferredApkAsset != null;

  bool get _looksLikeDebugRelease {
    final token = '${tagName.toLowerCase()} ${name.toLowerCase()}';
    return token.contains('debug');
  }

  bool get _hasOfficialChannelMarker =>
      _normalizedBody.contains(
            LauncherUpdateClient.officialChannelMarker.toLowerCase(),
          ) ||
      (_normalizedBody.contains('updater-channel:') &&
          _normalizedBody.contains(
            LauncherUpdateClient.officialChannelSlug.toLowerCase(),
          ));

  String get _normalizedBody => body.toLowerCase().replaceAll('`', '');

  bool get _looksLikeManagedRelease {
    final normalizedTag = tagName.trim().toLowerCase();
    final normalizedName = name.trim().toLowerCase();
    return normalizedTag.endsWith('-release') &&
        normalizedName.contains('atv launcher');
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

  static LauncherUpdateRelease? pickLatestOfficialRelease(
    Iterable<LauncherUpdateRelease> releases,
  ) {
    final officialReleases = releases
        .where((release) => release.isOfficialRelease)
        .toList(growable: false);
    if (officialReleases.isEmpty) {
      return null;
    }
    officialReleases.sort(_compareOfficialReleases);
    return officialReleases.first;
  }

  String get _versionSortKey {
    final candidates = <String>[
      tagName,
      name,
      preferredApkAsset?.name ?? '',
    ];
    for (final candidate in candidates) {
      final normalized = normalizeVersionToken(candidate);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  static int _compareOfficialReleases(
    LauncherUpdateRelease left,
    LauncherUpdateRelease right,
  ) {
    final publishedPriority = (right.publishedAt?.millisecondsSinceEpoch ?? -1)
        .compareTo(left.publishedAt?.millisecondsSinceEpoch ?? -1);
    if (publishedPriority != 0) {
      return publishedPriority;
    }

    final versionPriority =
        _compareVersionSortKeys(left._versionSortKey, right._versionSortKey);
    if (versionPriority != 0) {
      return versionPriority;
    }

    final uploadedPriority = (right.preferredApkAsset?.uploadedAt
                ?.millisecondsSinceEpoch ??
            -1)
        .compareTo(
      left.preferredApkAsset?.uploadedAt?.millisecondsSinceEpoch ?? -1,
    );
    if (uploadedPriority != 0) {
      return uploadedPriority;
    }

    return right.tagName.toLowerCase().compareTo(left.tagName.toLowerCase());
  }

  static int _compareVersionSortKeys(String left, String right) {
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }
    final leftParts = _parseVersionParts(left);
    final rightParts = _parseVersionParts(right);
    final maxLength =
        leftParts.length > rightParts.length ? leftParts.length : rightParts.length;
    for (var index = 0; index < maxLength; index += 1) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return rightValue.compareTo(leftValue);
      }
    }
    return 0;
  }

  static List<int> _parseVersionParts(String value) => value
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList(growable: false);

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  static int _compareApkAssets(
    LauncherUpdateAsset left,
    LauncherUpdateAsset right,
  ) {
    final releasePriority =
        _releaseAssetPriority(right).compareTo(_releaseAssetPriority(left));
    if (releasePriority != 0) {
      return releasePriority;
    }

    final architecturePriority =
        _architecturePriority(right).compareTo(_architecturePriority(left));
    if (architecturePriority != 0) {
      return architecturePriority;
    }

    final universalPenalty =
        _universalPenalty(left).compareTo(_universalPenalty(right));
    if (universalPenalty != 0) {
      return universalPenalty;
    }

    final downloadPriority = right.downloadCount.compareTo(left.downloadCount);
    if (downloadPriority != 0) {
      return downloadPriority;
    }

    return right.sizeBytes.compareTo(left.sizeBytes);
  }

  static int _releaseAssetPriority(LauncherUpdateAsset asset) {
    final name = asset.name.toLowerCase();
    if (name.contains('release')) {
      return 2;
    }
    if (name.endsWith('.apk')) {
      return 1;
    }
    return 0;
  }

  static int _architecturePriority(LauncherUpdateAsset asset) {
    final name = asset.name.toLowerCase();
    if (name.contains('armeabi') || name.contains('v7a')) {
      return 3;
    }
    if (name.contains('arm64') || name.contains('aarch64')) {
      return 2;
    }
    if (name.contains('arm')) {
      return 1;
    }
    return 0;
  }

  static int _universalPenalty(LauncherUpdateAsset asset) {
    final name = asset.name.toLowerCase();
    return name.contains('universal') ? 1 : 0;
  }
}

class LauncherUpdateAsset {
  final String name;
  final String browserDownloadUrl;
  final int sizeBytes;
  final int downloadCount;
  final String contentType;
  final DateTime? uploadedAt;

  const LauncherUpdateAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.sizeBytes,
    required this.downloadCount,
    required this.contentType,
    required this.uploadedAt,
  });

  factory LauncherUpdateAsset.fromGitHubJson(Map<String, dynamic> json) {
    return LauncherUpdateAsset(
      name: json['name']?.toString() ?? '',
      browserDownloadUrl: json['browser_download_url']?.toString() ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
      contentType: json['content_type']?.toString() ?? '',
      uploadedAt: LauncherUpdateRelease._parseDateTime(
        json['updated_at']?.toString() ?? json['created_at']?.toString(),
      ),
    );
  }

  Uri? get downloadUri => Uri.tryParse(browserDownloadUrl);

  bool get isOfficialApkAsset {
    final lowerName = name.toLowerCase().trim();
    return lowerName.endsWith('.apk') &&
        !lowerName.contains('debug') &&
        lowerName.startsWith('atv-launcher');
  }
}

class LauncherUpdateDownloadProgress {
  final String fileName;
  final int receivedBytes;
  final int totalBytes;

  const LauncherUpdateDownloadProgress({
    required this.fileName,
    required this.receivedBytes,
    required this.totalBytes,
  });

  double? get fraction {
    if (totalBytes <= 0) {
      return null;
    }
    return (receivedBytes / totalBytes).clamp(0, 1).toDouble();
  }
}

class LauncherDownloadedApk {
  final String fileName;
  final String filePath;

  const LauncherDownloadedApk({
    required this.fileName,
    required this.filePath,
  });
}

String normalizeVersionToken(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) {
    return '';
  }
  final match =
      RegExp(r'(?:v)?(\d{4}\.\d{2}(?:\.\d+)?(?:\+\d+)?)').firstMatch(value);
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
