import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  test('backup export excludes owner PIN secrets', () async {
    final service = await _createService();
    await service.setOwnerPin('1234');
    await service.setSettingsLockEnabled(true);

    final backup = service.toBackupMap();

    expect(backup.containsKey('ownerPinHash'), isFalse);
    expect(backup.containsKey('ownerPinSalt'), isFalse);
    expect(backup['settingsLockEnabled'], isTrue);
    expect(backup['activeProfileId'], ProfileSecurityService.ownerProfileId);
    expect((backup['profiles'] as List).length, 1);
    final ownerProfile = (backup['profiles'] as List).single as Map;
    expect(ownerProfile['hiddenPackages'], isEmpty);
  });

  test(
      'restoring legacy profile backups merges app rules into owner and keeps settings unlocked without a local PIN',
      () async {
    final target = await _createService();
    await target.applyBackupMap(<String, dynamic>{
      'profiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': ProfileSecurityService.ownerProfileId,
          'type': 'owner',
          'displayName': 'Owner',
          'enabled': true,
          'hiddenPackages': <String>['owner.hidden'],
          'lockedPackages': <String>[],
        },
        <String, dynamic>{
          'id': ProfileSecurityService.guestProfileId,
          'type': 'guest',
          'displayName': 'Guest',
          'enabled': true,
          'hiddenPackages': <String>['guest.hidden'],
          'lockedPackages': <String>['guest.locked'],
        },
      ],
      'activeProfileId': ProfileSecurityService.guestProfileId,
      'settingsLockEnabled': true,
    });

    expect(target.hasPin, isFalse);
    expect(target.activeProfileId, ProfileSecurityService.ownerProfileId);
    expect(target.settingsLockEnabled, isFalse);
    expect(
      target.isPackageLockedForProfile(
        ProfileSecurityService.ownerProfileId,
        'guest.locked',
      ),
      isTrue,
    );
  });

  test(
      'restoring preserves the existing target PIN and lock policy while collapsing legacy profiles',
      () async {
    final target = await _createService();
    await target.setOwnerPin('5678');
    await target.applyBackupMap(<String, dynamic>{
      'profiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': ProfileSecurityService.ownerProfileId,
          'type': 'owner',
          'displayName': 'Owner',
          'enabled': true,
          'hiddenPackages': <String>[],
          'lockedPackages': <String>['owner.locked'],
        },
        <String, dynamic>{
          'id': ProfileSecurityService.kidsProfileId,
          'type': 'kids',
          'displayName': 'Kids',
          'enabled': true,
          'hiddenPackages': <String>['kids.hidden'],
          'lockedPackages': <String>[],
        },
      ],
      'activeProfileId': ProfileSecurityService.kidsProfileId,
      'settingsLockEnabled': true,
    });

    expect(target.hasPin, isTrue);
    expect(target.verifyPin('5678'), isTrue);
    expect(target.settingsLockEnabled, isTrue);
    expect(target.activeProfileId, ProfileSecurityService.ownerProfileId);
    expect(
      target.isPackageLockedForProfile(
        ProfileSecurityService.ownerProfileId,
        'owner.locked',
      ),
      isTrue,
    );
  });

  test('legacy hidden packages no longer control app visibility at runtime',
      () async {
    final target = await _createService();
    await target.applyBackupMap(<String, dynamic>{
      'profiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': ProfileSecurityService.ownerProfileId,
          'type': 'owner',
          'displayName': 'Owner',
          'enabled': true,
          'hiddenPackages': <String>['legacy.hidden'],
          'lockedPackages': <String>[],
        },
      ],
      'settingsLockEnabled': false,
    });

    final app = App(
      packageName: 'legacy.hidden',
      name: 'Legacy Hidden',
      version: '1.0.0',
      hidden: false,
    );

    expect(target.isAppVisible(app), isTrue);
    app.hidden = true;
    expect(target.isAppVisible(app), isFalse);
  });

  test('changing the owner PIN requires the current PIN', () async {
    final service = await _createService();
    await service.setOwnerPin('1234');

    expect(
      await service.changeOwnerPin(
        currentPin: '0000',
        newPin: '5678',
      ),
      isFalse,
    );
    expect(service.verifyPin('1234'), isTrue);
    expect(
      await service.changeOwnerPin(
        currentPin: '1234',
        newPin: '5678',
      ),
      isTrue,
    );
    expect(service.verifyPin('1234'), isFalse);
    expect(service.verifyPin('5678'), isTrue);
  });

  test('clearing the owner PIN requires the current PIN', () async {
    final service = await _createService();
    await service.setOwnerPin('1234');

    expect(await service.clearOwnerPinWithVerification('0000'), isFalse);
    expect(service.hasPin, isTrue);

    expect(
      await service.clearOwnerPinWithVerification('1234'),
      isTrue,
    );
    expect(service.hasPin, isFalse);
  });
}

Future<ProfileSecurityService> _createService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final sharedPreferences = await SharedPreferences.getInstance();
  return ProfileSecurityService(sharedPreferences);
}
