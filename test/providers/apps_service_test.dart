import 'dart:async';

import 'package:flauncher/database.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:drift/drift.dart';

import '../mocks.mocks.dart';
import '../test_sqlite_setup.dart';

void main() {
  setUpAll(configureSqliteForTests);

  test('initializes default TV and non-TV categories from system apps',
      () async {
    final harness = await _createHarness([
      {
        'packageName': 'tv.app',
        'name': 'TV App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'sideloaded.app',
        'name': 'Sideloaded App',
        'version': '2.0.0',
        'sideloaded': true,
      },
    ]);
    addTearDown(harness.dispose);

    expect(harness.service.initialized, isTrue);
    expect(
      harness.service.categories.map((category) => category.name).toList(),
      ['Non-TV Applications', 'TV Applications'],
    );
    expect(harness.service.categories.last.type, CategoryType.grid);
    expect(
      harness.service.categories.last.applications.single.packageName,
      'tv.app',
    );
    expect(
      harness.service.categories.first.applications.single.packageName,
      'sideloaded.app',
    );
  });

  test('hideApplication removes app from visible category and show restores it',
      () async {
    final harness = await _createHarness([
      {
        'packageName': 'tv.app',
        'name': 'TV App',
        'version': '1.0.0',
        'sideloaded': false,
      },
    ]);
    addTearDown(harness.dispose);

    final category = harness.service.categories.single;
    final application = harness.service.applications.single;

    await harness.service.hideApplication(application);
    expect(harness.service.applications.single.hidden, isTrue);
    expect(
      harness.service.categories
          .singleWhere((item) => item.id == category.id)
          .applications,
      isEmpty,
    );

    await harness.service.showApplication(application);
    expect(harness.service.applications.single.hidden, isFalse);
    expect(
      harness.service.categories
          .singleWhere((item) => item.id == category.id)
          .applications
          .single
          .packageName,
      'tv.app',
    );
  });

  test(
      'restoreLayoutBackup reports unresolved packages and preserves valid apps',
      () async {
    final harness = await _createHarness([
      {
        'packageName': 'tv.app',
        'name': 'TV App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'other.app',
        'name': 'Other App',
        'version': '1.0.0',
        'sideloaded': true,
      },
    ]);
    addTearDown(harness.dispose);

    final result = await harness.service.restoreLayoutBackup({
      'sections': [
        {
          'type': 'category',
          'name': 'Recovered',
          'sort': 'manual',
          'categoryType': 'row',
          'columnsCount': 6,
          'rowHeight': 110,
          'appPackageNames': ['tv.app', 'missing.app'],
        },
      ],
      'hiddenPackages': ['other.app'],
    });

    expect(result['success'], isTrue);
    expect(result['unresolvedPackages'], contains('missing.app'));
    expect(harness.service.categories.single.name, 'Recovered');
    expect(
      harness.service.categories.single.applications
          .map((app) => app.packageName)
          .toList(),
      ['tv.app'],
    );
    expect(
      harness.service.applications
          .firstWhere((app) => app.packageName == 'other.app')
          .hidden,
      isTrue,
    );
  });

  test('moveCategory compatibility wrapper reorders launcher sections',
      () async {
    final harness = await _createHarness([
      {
        'packageName': 'tv.app',
        'name': 'TV App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'other.app',
        'name': 'Other App',
        'version': '1.0.0',
        'sideloaded': true,
      },
    ]);
    addTearDown(harness.dispose);

    await harness.service.moveCategory(1, 0);

    expect(
      harness.service.launcherSections
          .whereType<Category>()
          .map((category) => category.name)
          .toList(),
      ['Non-TV Applications', 'TV Applications'],
    );
  });

  test(
      'bootstraps renderable home from cached database before live sync finishes',
      () async {
    final channel = MockFLauncherChannel();
    final liveApps = Completer<List<Map<dynamic, dynamic>>>();
    when(channel.getApplications()).thenAnswer((_) => liveApps.future);
    when(channel.applicationExists(any)).thenAnswer((_) async => true);
    when(channel.addAppsChangedListener(any)).thenReturn(null);

    final database = FLauncherDatabase.inMemory();
    await database.persistApps([
      AppsCompanion.insert(
        packageName: 'cached.app',
        name: 'Cached App',
        version: '1.0.0',
      ),
    ]);
    final categoryId = await database.insertCategory(
      CategoriesCompanion.insert(
        name: 'Cached',
        order: 0,
        sort: const Value(CategorySort.manual),
        type: const Value(CategoryType.row),
        rowHeight: const Value(Category.RowHeight),
        columnsCount: const Value(Category.ColumnsCount),
      ),
    );
    await database.insertAppsCategories([
      AppsCategoriesCompanion.insert(
        categoryId: categoryId,
        appPackageName: 'cached.app',
        order: 0,
      ),
    ]);

    final service = AppsService(channel, database);
    addTearDown(service.dispose);
    addTearDown(database.close);

    for (var attempt = 0; attempt < 50 && !service.initialized; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(service.initialized, isTrue);
    expect(service.hasRenderableHome, isTrue);
    expect(service.staleCache, isFalse);
    expect(service.startupPhase, AppsService.startupPhaseSyncingLive);
    expect(service.categories.single.name, 'Cached');

    liveApps.complete([
      {
        'packageName': 'cached.app',
        'name': 'Cached App',
        'version': '1.0.1',
        'sideloaded': false,
      },
    ]);

    for (var attempt = 0;
        attempt < 80 && service.startupPhase != AppsService.startupPhaseReady;
        attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(service.startupPhase, AppsService.startupPhaseReady);
    expect(service.lastLiveSyncAt, greaterThan(0));
  });
}

class _AppsHarness {
  final MockFLauncherChannel channel;
  final FLauncherDatabase database;
  final AppsService service;

  _AppsHarness(this.channel, this.database, this.service);

  Future<void> dispose() => database.close();
}

Future<_AppsHarness> _createHarness(
  List<Map<String, dynamic>> systemApps,
) async {
  final channel = MockFLauncherChannel();
  when(channel.getApplications()).thenAnswer((_) async => systemApps);
  when(channel.applicationExists(any)).thenAnswer((_) async => false);
  when(channel.addAppsChangedListener(any)).thenReturn(null);
  final database = FLauncherDatabase.inMemory();
  final service = AppsService(channel, database);

  for (var attempt = 0; attempt < 50 && !service.initialized; attempt += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  expect(service.initialized, isTrue);
  return _AppsHarness(channel, database, service);
}
