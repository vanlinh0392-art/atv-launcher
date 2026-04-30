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
      ['TV Applications', 'Non-TV Applications'],
    );
    expect(
      harness.service.launcherSections
          .whereType<Category>()
          .map((category) => category.name)
          .toList(),
      ['TV Applications', 'Non-TV Applications'],
    );
    expect(harness.service.categories.first.type, CategoryType.grid);
    expect(
      harness.service.categories.first.applications.single.packageName,
      'tv.app',
    );
    expect(
      harness.service.categories.last.applications.single.packageName,
      'sideloaded.app',
    );

    final storedCategories = await harness.database.getCategories();
    expect(
      storedCategories.map((category) => category.name).toList(),
      ['TV Applications', 'Non-TV Applications'],
    );
    expect(storedCategories.first.type, CategoryType.grid);
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
    final recovered = harness.service.categories
        .singleWhere((category) => category.name == 'Recovered');
    expect(
      recovered.applications.map((app) => app.packageName).toList(),
      ['tv.app'],
    );
    expect(
      harness.service.applications
          .firstWhere((app) => app.packageName == 'other.app')
          .hidden,
      isTrue,
    );
  });

  test(
      'restoreLayoutBackup keeps apps already installed on this TV in fallback categories',
      () async {
    final harness = await _createHarness([
      {
        'packageName': 'tv.app',
        'name': 'TV App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'extra.tv.app',
        'name': 'Extra TV App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'extra.side.app',
        'name': 'Extra Sideloaded App',
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
          'appPackageNames': ['tv.app'],
        },
      ],
      'hiddenPackages': const <String>[],
    });

    expect(result['success'], isTrue);
    expect(
      result['preservedPackages'],
      containsAll(<String>['extra.tv.app', 'extra.side.app']),
    );

    final recovered = harness.service.categories
        .singleWhere((category) => category.name == 'Recovered');
    expect(
      recovered.applications.map((app) => app.packageName).toList(),
      ['tv.app'],
    );

    final tvFallback = harness.service.categories
        .singleWhere((category) => category.name == 'TV Applications');
    expect(
      tvFallback.applications.map((app) => app.packageName).toList(),
      ['extra.tv.app'],
    );

    final nonTvFallback = harness.service.categories
        .singleWhere((category) => category.name == 'Non-TV Applications');
    expect(
      nonTvFallback.applications.map((app) => app.packageName).toList(),
      ['extra.side.app'],
    );
  });

  test(
      'exportLayoutBackup keeps hidden app positions so restore can re-show them in place',
      () async {
    final harness = await _createHarness([
      {
        'packageName': 'tv.app',
        'name': 'TV App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'hidden.app',
        'name': 'Hidden App',
        'version': '1.0.0',
        'sideloaded': false,
      },
    ]);
    addTearDown(harness.dispose);

    final hiddenApp = harness.service.applications
        .firstWhere((app) => app.packageName == 'hidden.app');
    await harness.service.hideApplication(hiddenApp);

    final backup = harness.service.exportLayoutBackup();
    final sections = (backup['sections'] as List).cast<Map<String, dynamic>>();
    final categorySection =
        sections.singleWhere((section) => section['type'] == 'category');

    expect(
      (categorySection['appPackageNames'] as List).cast<String>(),
      ['tv.app', 'hidden.app'],
    );
    expect((backup['hiddenPackages'] as List).cast<String>(),
        contains('hidden.app'));

    await harness.service.restoreLayoutBackup(backup);

    final restoredHiddenApp = harness.service.applications
        .firstWhere((app) => app.packageName == 'hidden.app');
    expect(restoredHiddenApp.hidden, isTrue);

    await harness.service.showApplication(restoredHiddenApp);

    final restoredCategory = harness.service.categories.singleWhere(
      (category) =>
          category.applications.any((app) => app.packageName == 'hidden.app'),
    );
    expect(
      restoredCategory.applications.map((app) => app.packageName).toList(),
      ['tv.app', 'hidden.app'],
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

    final service = AppsService(
      channel,
      database,
      liveSyncWarmDelay: Duration.zero,
    );
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

  test('cancelApplicationReorderSession restores original alphabetical order',
      () async {
    final harness = await _createHarness([
      {
        'packageName': 'alpha.app',
        'name': 'Alpha App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'beta.app',
        'name': 'Beta App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'gamma.app',
        'name': 'Gamma App',
        'version': '1.0.0',
        'sideloaded': false,
      },
    ]);
    addTearDown(harness.dispose);

    final category = harness.service.categories.single;
    await harness.service.setCategorySort(category, CategorySort.alphabetical);

    expect(
      harness.service.categories.single.applications
          .map((app) => app.packageName)
          .toList(),
      ['alpha.app', 'beta.app', 'gamma.app'],
    );

    expect(harness.service.beginApplicationReorderSession(category), isTrue);
    expect(harness.service.reorderApplication(category, 2, 0), isTrue);
    expect(
      harness.service.categories.single.applications
          .map((app) => app.packageName)
          .toList(),
      ['gamma.app', 'alpha.app', 'beta.app'],
    );

    await harness.service.cancelApplicationReorderSession(category);

    expect(harness.service.categories.single.sort, CategorySort.alphabetical);
    expect(
      harness.service.categories.single.applications
          .map((app) => app.packageName)
          .toList(),
      ['alpha.app', 'beta.app', 'gamma.app'],
    );
  });

  test(
      'commitApplicationReorderSession persists preview order and switches alphabetical categories to manual',
      () async {
    final harness = await _createHarness([
      {
        'packageName': 'alpha.app',
        'name': 'Alpha App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'beta.app',
        'name': 'Beta App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'gamma.app',
        'name': 'Gamma App',
        'version': '1.0.0',
        'sideloaded': false,
      },
    ]);
    addTearDown(harness.dispose);

    final category = harness.service.categories.single;
    await harness.service.setCategorySort(category, CategorySort.alphabetical);

    expect(harness.service.beginApplicationReorderSession(category), isTrue);
    expect(harness.service.reorderApplication(category, 1, 0), isTrue);

    await harness.service.commitApplicationReorderSession(category);

    final committedCategory = harness.service.categories.single;
    expect(committedCategory.sort, CategorySort.manual);
    expect(
      committedCategory.applications.map((app) => app.packageName).toList(),
      ['beta.app', 'alpha.app', 'gamma.app'],
    );

    final beta = harness.service.applications
        .firstWhere((app) => app.packageName == 'beta.app');
    final alpha = harness.service.applications
        .firstWhere((app) => app.packageName == 'alpha.app');
    expect(beta.categoryOrders[committedCategory.id], 0);
    expect(alpha.categoryOrders[committedCategory.id], 1);

    final storedCategories = await harness.database.getCategories();
    final storedAppsCategories = await harness.database.getAppsCategories();
    storedAppsCategories
        .sort((left, right) => left.order.compareTo(right.order));

    expect(storedCategories.single.sort, CategorySort.manual);
    expect(
      storedAppsCategories.map((row) => row.appPackageName).toList(),
      ['beta.app', 'alpha.app', 'gamma.app'],
    );
  });

  test('disabling home reorder mode restores any unconfirmed preview order',
      () async {
    final harness = await _createHarness([
      {
        'packageName': 'alpha.app',
        'name': 'Alpha App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'beta.app',
        'name': 'Beta App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'gamma.app',
        'name': 'Gamma App',
        'version': '1.0.0',
        'sideloaded': false,
      },
    ]);
    addTearDown(harness.dispose);

    final category = harness.service.categories.single;
    await harness.service.setCategorySort(category, CategorySort.alphabetical);
    harness.service.setHomeReorderModeEnabled(true);

    expect(harness.service.beginApplicationReorderSession(category), isTrue);
    expect(harness.service.reorderApplication(category, 2, 0), isTrue);
    expect(
      harness.service.categories.single.applications
          .map((app) => app.packageName)
          .toList(),
      ['gamma.app', 'alpha.app', 'beta.app'],
    );

    harness.service.setHomeReorderModeEnabled(false);

    expect(harness.service.homeReorderModeEnabled, isFalse);
    expect(harness.service.categories.single.sort, CategorySort.alphabetical);
    expect(
      harness.service.categories.single.applications
          .map((app) => app.packageName)
          .toList(),
      ['alpha.app', 'beta.app', 'gamma.app'],
    );
  });

  test('committed reorder survives AppsService reload from database', () async {
    final systemApps = [
      {
        'packageName': 'alpha.app',
        'name': 'Alpha App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'beta.app',
        'name': 'Beta App',
        'version': '1.0.0',
        'sideloaded': false,
      },
      {
        'packageName': 'gamma.app',
        'name': 'Gamma App',
        'version': '1.0.0',
        'sideloaded': false,
      },
    ];
    final channel = MockFLauncherChannel();
    when(channel.getApplications()).thenAnswer((_) async => systemApps);
    when(channel.applicationExists(any)).thenAnswer((_) async => false);
    when(channel.addAppsChangedListener(any)).thenReturn(null);
    final database = FLauncherDatabase.inMemory();
    addTearDown(database.close);

    Future<AppsService> createService() async {
      final service = AppsService(
        channel,
        database,
        liveSyncWarmDelay: const Duration(days: 1),
      );
      for (var attempt = 0;
          attempt < 50 && !service.initialized;
          attempt += 1) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(service.initialized, isTrue);
      return service;
    }

    final firstService = await createService();

    final category = firstService.categories.single;
    await firstService.setCategorySort(category, CategorySort.alphabetical);
    expect(firstService.beginApplicationReorderSession(category), isTrue);
    expect(firstService.reorderApplication(category, 1, 0), isTrue);
    await firstService.commitApplicationReorderSession(category);

    firstService.dispose();

    final reloadedService = await createService();
    addTearDown(reloadedService.dispose);

    final reloadedCategory = reloadedService.categories.single;
    expect(reloadedCategory.sort, CategorySort.manual);
    expect(
      reloadedCategory.applications.map((app) => app.packageName).toList(),
      ['beta.app', 'alpha.app', 'gamma.app'],
    );
  });
}

class _AppsHarness {
  final MockFLauncherChannel channel;
  final FLauncherDatabase database;
  final AppsService service;

  _AppsHarness(this.channel, this.database, this.service);

  Future<void> dispose() async {
    service.dispose();
    await database.close();
  }
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
