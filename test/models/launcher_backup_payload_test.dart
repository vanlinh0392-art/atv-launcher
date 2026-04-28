import 'dart:convert';

import 'package:flauncher/models/launcher_backup_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the current ATV Launcher backup schema', () {
    final payload = LauncherBackupPayload.decodeAndValidate(
      jsonEncode(_validBackup()),
    );

    expect(payload['schema'], LauncherBackupPayload.schemaId);
    expect(
      ((payload['launcherLayout'] as Map)['sections'] as List).length,
      1,
    );
  });

  test('accepts legacy version-only backups from previous builds', () {
    final legacy = _validBackup()..remove('schema');

    final payload = LauncherBackupPayload.decodeAndValidate(
      jsonEncode(legacy),
    );

    expect(payload['version'], LauncherBackupPayload.currentVersion);
    expect(payload['schema'], LauncherBackupPayload.schemaId);
  });

  test('rejects files without an ATV Launcher backup signature', () {
    expect(
      () => LauncherBackupPayload.decodeAndValidate(
        jsonEncode(<String, dynamic>{
          'launcherLayout': <String, dynamic>{
            'sections': <Map<String, dynamic>>[],
          },
        }),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          LauncherBackupPayload.errorInvalidSignature,
        ),
      ),
    );
  });

  test('rejects unsupported launcher layout structures', () {
    expect(
      () => LauncherBackupPayload.decodeAndValidate(
        jsonEncode(<String, dynamic>{
          'schema': LauncherBackupPayload.schemaId,
          'version': LauncherBackupPayload.currentVersion,
          'settings': <String, dynamic>{'appLocaleMode': 'vi'},
          'launcherLayout': <String, dynamic>{
            'sections': <dynamic>[
              <String, dynamic>{'type': 'unknown'},
            ],
          },
        }),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          LauncherBackupPayload.errorInvalidStructure,
        ),
      ),
    );
  });
}

Map<String, dynamic> _validBackup() => <String, dynamic>{
      'schema': LauncherBackupPayload.schemaId,
      'version': LauncherBackupPayload.currentVersion,
      'packageName': 'com.atv.launcher',
      'settings': <String, dynamic>{
        'appLocaleMode': 'vi',
      },
      'launcherLayout': <String, dynamic>{
        'sections': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'category',
            'name': 'Recovered',
            'sort': 'manual',
            'categoryType': 'row',
            'columnsCount': 6,
            'rowHeight': 110,
            'appPackageNames': <String>['tv.app'],
          },
        ],
        'hiddenPackages': <String>['hidden.app'],
      },
      'profileSecurity': <String, dynamic>{
        'profiles': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'owner',
            'type': 'owner',
            'displayName': 'Owner',
            'enabled': true,
            'hiddenPackages': <String>[],
            'lockedPackages': <String>[],
          },
        ],
      },
      'search': <String, dynamic>{
        'recentQueries': <String>['spotify'],
      },
    };
