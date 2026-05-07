import 'dart:async';

import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'delta snapshots update nested bridge state without dropping cached sections',
      () async {
    final channel = MockFLauncherChannel();
    final systemEvents = StreamController<Map<String, dynamic>>();
    addTearDown(systemEvents.close);

    when(channel.getSystemBridgeStatusLite()).thenAnswer(
      (_) async => <String, dynamic>{
        'snapshotKind': 'lite',
        'wallpaper': <String, dynamic>{
          'videoReady': false,
          'currentIndex': 0,
          'lastError': '',
        },
        'provisioning': <String, dynamic>{
          'health': 'healthy',
        },
      },
    );
    when(channel.addSystemChangedListener(any)).thenAnswer((invocation) {
      final listener = invocation.positionalArguments.single as void Function(
          Map<String, dynamic>);
      return systemEvents.stream.listen(listener);
    });

    final service = SystemBridgeService(channel);
    await untilCalled(channel.addSystemChangedListener(any));

    expect(service.wallpaperStatus['videoReady'], isFalse);
    expect(service.provisioningStatus['health'], 'healthy');

    systemEvents.add(<String, dynamic>{
      'wallpaper': <String, dynamic>{
        'videoReady': true,
        'currentIndex': 2,
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.wallpaperStatus['videoReady'], isTrue);
    expect(service.wallpaperStatus['currentIndex'], 2);
    expect(service.provisioningStatus['health'], 'healthy');
  });

  test('unchanged delta snapshots do not emit redundant notifications',
      () async {
    final channel = MockFLauncherChannel();
    final systemEvents = StreamController<Map<String, dynamic>>();
    addTearDown(systemEvents.close);

    when(channel.getSystemBridgeStatusLite()).thenAnswer(
      (_) async => <String, dynamic>{
        'snapshotKind': 'lite',
        'wallpaper': <String, dynamic>{
          'videoReady': true,
          'currentIndex': 1,
        },
      },
    );
    when(channel.addSystemChangedListener(any)).thenAnswer((invocation) {
      final listener = invocation.positionalArguments.single as void Function(
          Map<String, dynamic>);
      return systemEvents.stream.listen(listener);
    });

    final service = SystemBridgeService(channel);
    await untilCalled(channel.addSystemChangedListener(any));

    var notifications = 0;
    service.addListener(() {
      notifications += 1;
    });

    systemEvents.add(<String, dynamic>{
      'wallpaper': <String, dynamic>{
        'videoReady': true,
        'currentIndex': 1,
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 0);
  });

  test('hot snapshots update live sections without dropping cold state',
      () async {
    final channel = MockFLauncherChannel();
    final systemEvents = StreamController<Map<String, dynamic>>();
    addTearDown(systemEvents.close);

    when(channel.getSystemBridgeStatusLite()).thenAnswer(
      (_) async => <String, dynamic>{
        'snapshotKind': 'lite',
        'navigation': <String, dynamic>{
          'homeSequence': 1,
          'reason': 'initial',
        },
        'wallpaper': <String, dynamic>{
          'videoReady': false,
        },
        'memory': <String, dynamic>{
          'availBytes': 100,
          'totalBytes': 200,
        },
        'provisioning': <String, dynamic>{
          'health': 'healthy',
        },
        'updates': <String, dynamic>{
          'state': 'idle',
        },
        'fileAccess': <String, dynamic>{
          'granted': true,
        },
        'backup': <String, dynamic>{
          'lastExportName': 'backup.json',
        },
      },
    );
    when(channel.addSystemChangedListener(any)).thenAnswer((invocation) {
      final listener = invocation.positionalArguments.single as void Function(
          Map<String, dynamic>);
      return systemEvents.stream.listen(listener);
    });

    final service = SystemBridgeService(channel);
    await untilCalled(channel.addSystemChangedListener(any));

    systemEvents.add(<String, dynamic>{
      'snapshotKind': 'hot',
      'navigation': <String, dynamic>{
        'homeSequence': 2,
        'reason': 'home',
      },
      'wallpaper': <String, dynamic>{
        'videoReady': true,
      },
      'memory': <String, dynamic>{
        'availBytes': 120,
        'totalBytes': 200,
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.navigationStatus['homeSequence'], 2);
    expect(service.wallpaperStatus['videoReady'], isTrue);
    expect(service.memoryStatus['availBytes'], 120);
    expect(service.provisioningStatus['health'], 'healthy');
    expect(service.updateStatus['state'], 'idle');
    expect(service.fileAccessStatus['granted'], isTrue);
    expect(service.backupStatus['lastExportName'], 'backup.json');
  });
}
