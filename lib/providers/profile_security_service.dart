import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/models/launcher_profile.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profilesKey = 'security_profiles';
const _activeProfileIdKey = 'security_active_profile_id';
const _settingsLockEnabledKey = 'security_settings_lock_enabled';
const _ownerPinHashKey = 'security_owner_pin_hash';
const _ownerPinSaltKey = 'security_owner_pin_salt';

class ProfileSecurityService extends ChangeNotifier
    with WidgetsBindingObserver {
  static const String ownerProfileId = 'owner';
  static const String guestProfileId = 'guest';
  static const String kidsProfileId = 'kids';
  static const Duration unlockSessionDuration = Duration(minutes: 10);

  final SharedPreferences _sharedPreferences;
  final Random _random;

  Map<String, LauncherProfile> _profiles = <String, LauncherProfile>{};
  String _activeProfileId = ownerProfileId;
  bool _settingsLockEnabled = false;
  String _ownerPinHash = '';
  String _ownerPinSalt = '';
  int? _unlockExpiresAtEpochMs;

  List<LauncherProfile> get profiles => _orderedProfiles()
      .map((profile) => profile.unmodifiable())
      .toList(growable: false);
  String get activeProfileId => ownerProfileId;
  LauncherProfile get activeProfile => _ownerProfile;
  bool get settingsLockEnabled => _settingsLockEnabled;
  bool get hasPin => _ownerPinHash.isNotEmpty && _ownerPinSalt.isNotEmpty;
  bool get isOwnerActive => true;
  bool get isRestrictedProfile => false;
  bool get isUnlocked => _isUnlockSessionValid();
  bool get canManageLauncherStructure => isOwnerActive && _isSettingsAccessOpen;
  bool get canAccessSettingsWithoutPin => _isSettingsAccessOpen;
  int get activeHiddenCount => _ownerProfile.hiddenPackages.length;
  int get activeLockedCount => _ownerProfile.lockedPackages.length;

  LauncherProfile get _ownerProfile => _profiles.putIfAbsent(
        ownerProfileId,
        () => LauncherProfile(
          id: ownerProfileId,
          type: LauncherProfileType.owner,
          displayName: 'Owner',
          enabled: true,
        ),
      );

  bool get _isSettingsAccessOpen {
    if (isOwnerActive) {
      if (!_settingsLockEnabled) {
        return true;
      }
      return _isUnlockSessionValid();
    }
    return _isUnlockSessionValid();
  }

  ProfileSecurityService(
    this._sharedPreferences, {
    Random? random,
  }) : _random = random ?? Random.secure() {
    WidgetsBinding.instance.addObserver(this);
    _hydrate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        clearUnlockSession(notify: true);
        break;
      case AppLifecycleState.resumed:
        if (!_isUnlockSessionValid() && _unlockExpiresAtEpochMs != null) {
          clearUnlockSession(notify: true);
        }
        break;
    }
  }

  bool requiresPinForSettingsAccess() {
    if (!hasPin) {
      return isRestrictedProfile;
    }
    if (isOwnerActive) {
      return _settingsLockEnabled && !_isUnlockSessionValid();
    }
    return !_isUnlockSessionValid();
  }

  bool isAppVisible(App app) => !app.hidden;

  bool isAppLocked(App app) => _ownerProfile.lockedPackages.contains(
        app.packageName,
      );

  bool canLaunchApp(App app) => !isAppLocked(app) || _isUnlockSessionValid();

  bool canUseSensitiveAppActions() => isOwnerActive && _isSettingsAccessOpen;

  LauncherProfile profileById(String profileId) =>
      (_profiles[profileId] ?? activeProfile).unmodifiable();

  Future<void> setProfileEnabled(String profileId, bool enabled) async {
    if (profileId != ownerProfileId) {
      return;
    }
    _ownerProfile.enabled = true;
    await _persist();
  }

  Future<void> setProfileDisplayName(String profileId, String value) async {
    if (profileId != ownerProfileId) {
      return;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    _ownerProfile.displayName = normalized;
    await _persist();
  }

  Future<void> switchActiveProfile(String profileId) async {
    if (profileId != ownerProfileId) {
      return;
    }
    _activeProfileId = ownerProfileId;
    await _sharedPreferences.setString(_activeProfileIdKey, ownerProfileId);
    notifyListeners();
  }

  Future<void> setSettingsLockEnabled(bool enabled) async {
    _settingsLockEnabled = enabled;
    if (!enabled) {
      clearUnlockSession();
    }
    await _sharedPreferences.setBool(_settingsLockEnabledKey, enabled);
    notifyListeners();
  }

  Future<bool> setOwnerPin(String pin) async {
    if (!_isValidPin(pin)) {
      return false;
    }
    _ownerPinSalt = _generateSalt();
    _ownerPinHash = _hashPin(pin, _ownerPinSalt);
    await Future.wait([
      _sharedPreferences.setString(_ownerPinHashKey, _ownerPinHash),
      _sharedPreferences.setString(_ownerPinSaltKey, _ownerPinSalt),
    ]);
    unlockSession();
    notifyListeners();
    return true;
  }

  Future<bool> changeOwnerPin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!hasPin || !verifyPin(currentPin)) {
      return false;
    }
    return setOwnerPin(newPin);
  }

  Future<void> clearOwnerPin() async {
    _ownerPinHash = '';
    _ownerPinSalt = '';
    clearUnlockSession();
    await Future.wait([
      _sharedPreferences.remove(_ownerPinHashKey),
      _sharedPreferences.remove(_ownerPinSaltKey),
    ]);
    notifyListeners();
  }

  Future<bool> clearOwnerPinWithVerification(String currentPin) async {
    if (!hasPin || !verifyPin(currentPin)) {
      return false;
    }
    await clearOwnerPin();
    return true;
  }

  bool verifyPin(String pin) {
    if (!hasPin || !_isValidPin(pin)) {
      return false;
    }
    return _hashPin(pin, _ownerPinSalt) == _ownerPinHash;
  }

  bool unlockWithPin(String pin) {
    if (!verifyPin(pin)) {
      return false;
    }
    unlockSession();
    notifyListeners();
    return true;
  }

  void unlockSession() {
    _unlockExpiresAtEpochMs =
        DateTime.now().add(unlockSessionDuration).millisecondsSinceEpoch;
  }

  void clearUnlockSession({bool notify = false}) {
    if (_unlockExpiresAtEpochMs == null) {
      return;
    }
    _unlockExpiresAtEpochMs = null;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> setPackageHiddenForProfile(
    String profileId,
    String packageName,
    bool hidden,
  ) async {
    final profile = _profileStorageFor(profileId);
    if (hidden) {
      profile.hiddenPackages.add(packageName);
      profile.lockedPackages.remove(packageName);
    } else {
      profile.hiddenPackages.remove(packageName);
    }
    await _persist();
  }

  Future<void> setPackageLockedForProfile(
    String profileId,
    String packageName,
    bool locked,
  ) async {
    final profile = _profileStorageFor(profileId);
    if (locked) {
      profile.lockedPackages.add(packageName);
      profile.hiddenPackages.remove(packageName);
    } else {
      profile.lockedPackages.remove(packageName);
    }
    await _persist();
  }

  bool isPackageHiddenForProfile(String profileId, String packageName) =>
      _profileStorageFor(profileId).hiddenPackages.contains(packageName);

  bool isPackageLockedForProfile(String profileId, String packageName) =>
      _profileStorageFor(profileId).lockedPackages.contains(packageName);

  List<LauncherSection> filterLauncherSections(List<LauncherSection> sections) {
    return sections
        .map((section) {
          if (section is LauncherSpacer) {
            return LauncherSpacer(
                id: section.id,
                order: section.order,
                height: section.height) as LauncherSection;
          }
          if (section is Category) {
            final visibleApps = section.applications
                .where(isAppVisible)
                .toList(growable: false);
            return Category.withApplications(
              id: section.id,
              order: section.order,
              name: section.name,
              sort: section.sort,
              type: section.type,
              columnsCount: section.columnsCount,
              rowHeight: section.rowHeight,
              applications: visibleApps,
            );
          }
          return section;
        })
        .where((section) =>
            section is! Category || section.applications.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> toBackupMap() => <String, dynamic>{
        'profiles': _orderedProfiles()
            .map((profile) => <String, dynamic>{
                  ...profile.toJson(),
                  'hiddenPackages': const <String>[],
                })
            .toList(growable: false),
        'activeProfileId': ownerProfileId,
        'settingsLockEnabled': _settingsLockEnabled,
      };

  Future<void> applyBackupMap(Map<String, dynamic> data) async {
    final hadPinBeforeRestore = hasPin;
    if (data.containsKey('profiles')) {
      final restoredProfiles = _readProfiles(data['profiles']);
      _profiles = restoredProfiles;
    }
    _collapseLegacyProfilesIntoOwner();
    _activeProfileId = ownerProfileId;

    if (data.containsKey('settingsLockEnabled')) {
      _settingsLockEnabled =
          data['settingsLockEnabled'] == true && hadPinBeforeRestore;
    }

    clearUnlockSession();
    await _persist();
  }

  void _hydrate() {
    _profiles = _readProfiles(_sharedPreferences.getString(_profilesKey));
    if (_profiles.isEmpty) {
      _profiles = _defaultProfiles();
    }
    _collapseLegacyProfilesIntoOwner();
    _activeProfileId = ownerProfileId;
    _settingsLockEnabled =
        _sharedPreferences.getBool(_settingsLockEnabledKey) ?? false;
    _ownerPinHash = _sharedPreferences.getString(_ownerPinHashKey) ?? '';
    _ownerPinSalt = _sharedPreferences.getString(_ownerPinSaltKey) ?? '';
    notifyListeners();
  }

  Future<void> _persist() async {
    await Future.wait([
      _sharedPreferences.setString(
          _profilesKey,
          jsonEncode(_orderedProfiles()
              .map((profile) => profile.toJson())
              .toList(growable: false))),
      _sharedPreferences.setString(_activeProfileIdKey, _activeProfileId),
      _sharedPreferences.setBool(_settingsLockEnabledKey, _settingsLockEnabled),
      _sharedPreferences.setString(_ownerPinHashKey, _ownerPinHash),
      _sharedPreferences.setString(_ownerPinSaltKey, _ownerPinSalt),
    ]);
    notifyListeners();
  }

  List<LauncherProfile> _orderedProfiles() => <LauncherProfile>[
        _ownerProfile,
      ];

  Map<String, LauncherProfile> _defaultProfiles() => <String, LauncherProfile>{
        ownerProfileId: LauncherProfile(
          id: ownerProfileId,
          type: LauncherProfileType.owner,
          displayName: 'Owner',
          enabled: true,
        ),
        guestProfileId: LauncherProfile(
          id: guestProfileId,
          type: LauncherProfileType.guest,
          displayName: 'Guest',
          enabled: false,
        ),
        kidsProfileId: LauncherProfile(
          id: kidsProfileId,
          type: LauncherProfileType.kids,
          displayName: 'Kids',
          enabled: false,
        ),
      };

  Map<String, LauncherProfile> _readProfiles(dynamic raw) {
    final Map<String, LauncherProfile> profiles = _defaultProfiles();
    List<dynamic>? decoded;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) {
          decoded = parsed;
        }
      } catch (_) {
        decoded = null;
      }
    } else if (raw is List) {
      decoded = raw;
    }
    if (decoded == null) {
      return profiles;
    }

    for (final entry in decoded) {
      if (entry is! Map) {
        continue;
      }
      final profile = LauncherProfile.fromJson(entry.cast<String, dynamic>());
      if (profile.id.isEmpty) {
        continue;
      }
      profiles[profile.id] = profile;
    }

    profiles[ownerProfileId] ??= LauncherProfile(
      id: ownerProfileId,
      type: LauncherProfileType.owner,
      displayName: 'Owner',
      enabled: true,
    );
    profiles[guestProfileId] ??= LauncherProfile(
      id: guestProfileId,
      type: LauncherProfileType.guest,
      displayName: 'Guest',
      enabled: false,
    );
    profiles[kidsProfileId] ??= LauncherProfile(
      id: kidsProfileId,
      type: LauncherProfileType.kids,
      displayName: 'Kids',
      enabled: false,
    );
    profiles[ownerProfileId]!.enabled = true;
    return profiles;
  }

  LauncherProfile _profileStorageFor(String profileId) {
    if (profileId == ownerProfileId) {
      return _ownerProfile;
    }
    return _ownerProfile;
  }

  void _collapseLegacyProfilesIntoOwner() {
    final owner = _ownerProfile;
    for (final entry in _profiles.entries) {
      if (entry.key == ownerProfileId) {
        continue;
      }
      owner.hiddenPackages.addAll(entry.value.hiddenPackages);
      owner.lockedPackages.addAll(entry.value.lockedPackages);
      entry.value.hiddenPackages.clear();
      entry.value.lockedPackages.clear();
      entry.value.enabled = false;
    }
    owner.lockedPackages.removeAll(owner.hiddenPackages);
    owner.enabled = true;
  }

  bool _isUnlockSessionValid() {
    final expiresAt = _unlockExpiresAtEpochMs;
    if (expiresAt == null) {
      return false;
    }
    if (DateTime.now().millisecondsSinceEpoch >= expiresAt) {
      _unlockExpiresAtEpochMs = null;
      return false;
    }
    return true;
  }

  bool _isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  String _generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
