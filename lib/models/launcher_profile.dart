import 'dart:collection';

enum LauncherProfileType {
  owner,
  guest,
  kids,
}

class LauncherProfile {
  final String id;
  final LauncherProfileType type;
  String displayName;
  bool enabled;
  final Set<String> hiddenPackages;
  final Set<String> lockedPackages;

  LauncherProfile({
    required this.id,
    required this.type,
    required this.displayName,
    required this.enabled,
    Set<String>? hiddenPackages,
    Set<String>? lockedPackages,
  })  : hiddenPackages = hiddenPackages ?? <String>{},
        lockedPackages = lockedPackages ?? <String>{};

  LauncherProfile copy() => LauncherProfile(
        id: id,
        type: type,
        displayName: displayName,
        enabled: enabled,
        hiddenPackages: Set<String>.from(hiddenPackages),
        lockedPackages: Set<String>.from(lockedPackages),
      );

  LauncherProfile unmodifiable() => LauncherProfile(
        id: id,
        type: type,
        displayName: displayName,
        enabled: enabled,
        hiddenPackages: UnmodifiableSetView(hiddenPackages),
        lockedPackages: UnmodifiableSetView(lockedPackages),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'displayName': displayName,
        'enabled': enabled,
        'hiddenPackages': hiddenPackages.toList(growable: false),
        'lockedPackages': lockedPackages.toList(growable: false),
      };

  static LauncherProfile fromJson(Map<String, dynamic> json) => LauncherProfile(
        id: json['id']?.toString() ?? '',
        type: LauncherProfileType.values.firstWhere(
          (candidate) => candidate.name == json['type']?.toString(),
          orElse: () => LauncherProfileType.owner,
        ),
        displayName: json['displayName']?.toString() ?? '',
        enabled: json['enabled'] != false,
        hiddenPackages: _readStringSet(json['hiddenPackages']),
        lockedPackages: _readStringSet(json['lockedPackages']),
      );

  static Set<String> _readStringSet(dynamic value) {
    if (value is! List) {
      return <String>{};
    }
    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }
}
