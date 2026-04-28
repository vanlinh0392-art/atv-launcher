import 'dart:convert';

class LauncherBackupPayload {
  static const String schemaId = 'com.atv.launcher.backup.v1';
  static const int currentVersion = 1;

  static const String errorEmpty = 'backup_empty';
  static const String errorInvalidJson = 'backup_invalid_json';
  static const String errorInvalidSignature = 'backup_invalid_signature';
  static const String errorInvalidStructure = 'backup_invalid_structure';

  static Map<String, dynamic> decodeAndValidate(String rawContent) {
    if (rawContent.trim().isEmpty) {
      throw const FormatException(errorEmpty);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(rawContent);
    } catch (_) {
      throw const FormatException(errorInvalidJson);
    }

    if (decoded is! Map) {
      throw const FormatException(errorInvalidStructure);
    }

    return validateMap(decoded.cast<String, dynamic>());
  }

  static Map<String, dynamic> validateMap(Map<String, dynamic> raw) {
    final schema = raw['schema']?.toString() ?? '';
    final version = _readInt(raw['version']);
    if (schema != schemaId && version != currentVersion) {
      throw const FormatException(errorInvalidSignature);
    }

    final settings = _readMap(raw['settings']);
    final launcherLayout = _readMap(raw['launcherLayout']);
    final systemBridge = _readMap(raw['systemBridge']);
    final profileSecurity = _readMap(raw['profileSecurity']);
    final search = _readMap(raw['search']);

    if (!launcherLayout.containsKey('sections')) {
      throw const FormatException(errorInvalidStructure);
    }

    final sections = _readSections(launcherLayout['sections']);
    final hiddenPackages = _readStringList(launcherLayout['hiddenPackages']);
    final profiles = _readRawList(profileSecurity['profiles']);
    final recentQueries = _readStringList(search['recentQueries']);
    final recentSelectionIds = _readStringList(search['recentSelectionIds']);

    final hasMeaningfulPayload = settings.isNotEmpty ||
        sections.isNotEmpty ||
        hiddenPackages.isNotEmpty ||
        systemBridge.isNotEmpty ||
        profileSecurity.isNotEmpty ||
        search.isNotEmpty;
    if (!hasMeaningfulPayload) {
      throw const FormatException(errorInvalidStructure);
    }

    return <String, dynamic>{
      'schema': schema.isEmpty ? schemaId : schema,
      'version': version ?? currentVersion,
      'packageName': raw['packageName']?.toString() ?? '',
      'createdAt': raw['createdAt']?.toString() ?? '',
      'settings': settings,
      'launcherLayout': <String, dynamic>{
        ...launcherLayout,
        'sections': sections,
        if (launcherLayout.containsKey('hiddenPackages'))
          'hiddenPackages': hiddenPackages,
      },
      'systemBridge': systemBridge,
      'profileSecurity': <String, dynamic>{
        ...profileSecurity,
        if (profileSecurity.containsKey('profiles')) 'profiles': profiles,
      },
      'search': <String, dynamic>{
        ...search,
        if (search.containsKey('recentQueries')) 'recentQueries': recentQueries,
        if (search.containsKey('recentSelectionIds'))
          'recentSelectionIds': recentSelectionIds,
      },
    };
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value == null) {
      return <String, dynamic>{};
    }
    if (value is! Map) {
      throw const FormatException(errorInvalidStructure);
    }
    return value.cast<String, dynamic>();
  }

  static List<Map<String, dynamic>> _readSections(dynamic value) {
    if (value == null) {
      return const <Map<String, dynamic>>[];
    }
    if (value is! List) {
      throw const FormatException(errorInvalidStructure);
    }

    return value.map((entry) {
      if (entry is! Map) {
        throw const FormatException(errorInvalidStructure);
      }
      final section = entry.cast<String, dynamic>();
      final type = section['type']?.toString() ?? '';
      if (type != 'category' && type != 'spacer') {
        throw const FormatException(errorInvalidStructure);
      }
      return section;
    }).toList(growable: false);
  }

  static List<dynamic> _readRawList(dynamic value) {
    if (value == null) {
      return const <dynamic>[];
    }
    if (value is! List) {
      throw const FormatException(errorInvalidStructure);
    }
    return List<dynamic>.from(value);
  }

  static List<String> _readStringList(dynamic value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is! List) {
      throw const FormatException(errorInvalidStructure);
    }
    return value
        .whereType<Object>()
        .map((entry) => entry.toString())
        .toList(growable: false);
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
