/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'package:collection/collection.dart' as collection;

import 'package:drift/drift.dart';
import 'package:flauncher/app_image_cache_invalidator.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:tuple/tuple.dart';

import '../models/app.dart';
import '../models/category.dart';

class AppsService extends ChangeNotifier {
  static const bool fastStartupEnabled = true;
  static const String startupPhaseBootstrapCached = 'bootstrap_cached';
  static const String startupPhaseSyncingLive = 'syncing_live';
  static const String startupPhaseReady = 'ready';
  static const String startupPhaseDegradedCached = 'degraded_cached';
  static const Duration _liveSyncRetryDelay = Duration(seconds: 6);
  static const Duration _liveSyncWarmDelay = Duration(milliseconds: 350);

  final FLauncherChannel _fLauncherChannel;
  final FLauncherDatabase _database;

  bool _initialized = false;
  bool _staleCache = false;
  String _startupPhase = startupPhaseBootstrapCached;
  int _lastLiveSyncAt = 0;
  Timer? _liveSyncRetryTimer;
  Future<void>? _liveSyncFuture;
  final int _bootstrapStartedAt = DateTime.now().millisecondsSinceEpoch;
  bool _firstRenderableLogged = false;

  List<LauncherSection> _launcherSections = List.empty(growable: true);
  Map<String, App> _applications = Map();
  Map<int, Category> _categoriesById = Map();
  List<App>? _applicationsSnapshot;
  List<LauncherSection>? _launcherSectionsSnapshot;
  List<Category>? _categoriesSnapshot;
  List<CategoryWithApps>? _categoriesWithAppsSnapshot;

  bool get initialized => _initialized;
  bool get staleCache => _staleCache;
  bool get hasRenderableHome =>
      _launcherSections.isNotEmpty ||
      _applications.isNotEmpty ||
      _categoriesById.isNotEmpty;
  String get startupPhase => _startupPhase;
  int get lastLiveSyncAt => _lastLiveSyncAt;

  List<App> get applications => _applicationsSnapshot ??= List.unmodifiable(
      _applications.values.sortedBy((application) => application.name));

  List<LauncherSection> get launcherSections =>
      _launcherSectionsSnapshot ??= List.unmodifiable(_launcherSections);
  List<Category> get categories =>
      _categoriesSnapshot ??= _categoriesById.values
          .map((category) => category.unmodifiable())
          .toList(growable: false);
  List<CategoryWithApps> get categoriesWithApps =>
      _categoriesWithAppsSnapshot ??= categories
          .map(
            (category) => CategoryWithApps(
              category,
              List<App>.unmodifiable(category.applications),
            ),
          )
          .toList(growable: false);

  AppsService(this._fLauncherChannel, this._database) {
    _init();
  }

  @override
  void notifyListeners() {
    _clearSnapshots();
    super.notifyListeners();
  }

  void _clearSnapshots() {
    _applicationsSnapshot = null;
    _launcherSectionsSnapshot = null;
    _categoriesSnapshot = null;
    _categoriesWithAppsSnapshot = null;
  }

  void _invalidateAppImageCache(String? packageName) {
    AppImageCacheInvalidator.instance.invalidate(packageName);
  }

  Future<void> _init() async {
    _fLauncherChannel.addAppsChangedListener((event) async {
      String? changedImagePackageName;
      switch (event["action"]) {
        case "PACKAGE_ADDED":
        case "PACKAGE_CHANGED":
          Map<dynamic, dynamic> applicationInfo = event['activityInfo'];
          await _database.persistApps([_buildAppCompanion(applicationInfo)]);

          App application = App.fromSystem(applicationInfo);
          _applications[application.packageName] = application;
          changedImagePackageName = application.packageName;
          break;
        case "PACKAGES_AVAILABLE":
          List<dynamic> applicationsInfo = event["activitiesInfo"];
          await _database
              .persistApps((applicationsInfo).map(_buildAppCompanion));

          for (Map<dynamic, dynamic> applicationInfo in applicationsInfo) {
            App application = App.fromSystem(applicationInfo);
            _applications[application.packageName] = application;
          }
          _invalidateAppImageCache(null);
          break;
        case "PACKAGE_REMOVED":
          String packageName = event['packageName'];
          await _database.deleteApps([packageName]);
          changedImagePackageName = packageName;

          App? application = _applications.remove(packageName);

          if (application != null) {
            for (int categoryId in application.categoryOrders.keys) {
              if (_categoriesById.containsKey(categoryId)) {
                Category category = _categoriesById[categoryId]!;
                category.applications.remove(application);
              }
            }
          }
          break;
      }

      if (changedImagePackageName != null) {
        _invalidateAppImageCache(changedImagePackageName);
      }
      _staleCache = false;
      _lastLiveSyncAt = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
    });

    await _loadStateFromDatabase(shouldNotifyListeners: false);
    if (fastStartupEnabled && hasRenderableHome) {
      _initialized = true;
      _staleCache = false;
      _startupPhase = startupPhaseSyncingLive;
      _logFirstRenderableHome('cached');
      notifyListeners();
      _scheduleLiveSync(reason: 'startup_cached');
      return;
    }

    await _runLiveSync(
      reason: 'startup_cold',
      initializeDefaultCategoriesIfNeeded: _database.wasCreated,
    );
  }

  AppsCompanion _buildAppCompanion(dynamic data) {
    String? version = data["version"];
    if (version == null) {
      version = "";
    }

    return AppsCompanion(
        packageName: Value(data["packageName"]),
        name: Value(data["name"]),
        version: Value(version),
        hidden: const Value.absent());
  }

  Future<void> _initDefaultCategories() {
    final tvApplications = _applications.values
        .where((application) => application.sideloaded == false);
    final nonTvApplications = _applications.values
        .where((application) => application.sideloaded == true);

    return _database.transaction(() async {
      if (tvApplications.isNotEmpty) {
        int categoryId = await addCategory("TV Applications",
            type: CategoryType.grid, shouldNotifyListeners: false);

        Category tvAppsCategory = _categoriesById[categoryId]!;
        for (final app in tvApplications) {
          await addToCategory(app, tvAppsCategory,
              shouldNotifyListeners: false);
        }
      }
      if (nonTvApplications.isNotEmpty) {
        int categoryId = await addCategory(
          "Non-TV Applications",
          shouldNotifyListeners: false,
        );
        Category nonTvAppsCategory = _categoriesById[categoryId]!;
        for (final app in nonTvApplications) {
          await addToCategory(app, nonTvAppsCategory,
              shouldNotifyListeners: false);
        }
      }
    });
  }

  Future<void> _loadStateFromDatabase({
    bool shouldNotifyListeners = true,
    Map<String, Tuple2<Map, AppsCompanion>>? appsFromSystemByPackageName,
  }) async {
    final appsFromDatabaseFuture = _database.getApplications();
    final appsCategoriesFuture = _database.getAppsCategories();
    final categoriesFuture = _database.getCategories();
    final spacersFuture = _database.getLauncherSpacers();

    await Future.wait([
      appsFromDatabaseFuture,
      appsCategoriesFuture,
      categoriesFuture,
      spacersFuture,
    ]);

    final appsFromDatabase = await appsFromDatabaseFuture;
    final appsCategories = await appsCategoriesFuture;
    final categories = await categoriesFuture;
    final spacers = await spacersFuture;

    _categoriesById = Map.fromEntries(
      categories.map((category) => MapEntry(category.id, category)),
    );
    _applications = Map.fromEntries(
      appsFromDatabase.map(
        (application) => MapEntry(application.packageName, application),
      ),
    );

    _launcherSections.clear();
    _launcherSections.addAll(categories);
    _launcherSections.addAll(spacers);
    _launcherSections.sort((ls0, ls1) => ls0.order.compareTo(ls1.order));

    for (final application in _applications.values) {
      final applicationFromSystem =
          appsFromSystemByPackageName?[application.packageName]?.item1;

      if (applicationFromSystem != null) {
        if (applicationFromSystem.containsKey('action')) {
          application.action = applicationFromSystem['action'];
        }
        if (applicationFromSystem.containsKey('sideloaded')) {
          application.sideloaded = applicationFromSystem['sideloaded'];
        }
      }

      if (appsCategories.isNotEmpty && !application.hidden) {
        final currentApplicationCategories = appsCategories.where(
          (appCategory) =>
              appCategory.appPackageName == application.packageName,
        );

        for (final appCategory in currentApplicationCategories) {
          if (_categoriesById.containsKey(appCategory.categoryId)) {
            final category = _categoriesById[appCategory.categoryId]!;
            application.categoryOrders[category.id] = appCategory.order;
            category.applications.add(application);
          }
        }
      }
    }

    for (final category in _categoriesById.values) {
      sortCategory(category);
    }

    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> _refreshState({bool shouldNotifyListeners = true}) async {
    List<Map<dynamic, dynamic>> appsFromSystem =
        await _fLauncherChannel.getApplications();
    Iterable<MapEntry<String, Tuple2<Map, AppsCompanion>>> appEntries =
        appsFromSystem.map((appFromSystem) => new MapEntry(
            appFromSystem['packageName'],
            Tuple2(appFromSystem, _buildAppCompanion(appFromSystem))));
    Map<String, Tuple2<Map, AppsCompanion>> appsFromSystemByPackageName =
        Map.fromEntries(appEntries);

    List<App> appsFromDatabase = await _database.getApplications();
    final Iterable<App> appsRemovedFromSystem = appsFromDatabase.where(
        (app) => !appsFromSystemByPackageName.containsKey(app.packageName));

    final List<String> uninstalledApplications = [];
    for (App app in appsRemovedFromSystem) {
      String packageName = app.packageName;

      // TODO: Is this really necessary? Can't we get this information from the getApplications method?
      bool appExists = await _fLauncherChannel.applicationExists(packageName);
      if (!appExists) {
        uninstalledApplications.add(packageName);
      }
    }

    await _database.transaction(() async {
      await _database.persistApps(
          appsFromSystemByPackageName.values.map((tuple) => tuple.item2));
      await _database.deleteApps(uninstalledApplications);
    });
    await _loadStateFromDatabase(
      shouldNotifyListeners: shouldNotifyListeners,
      appsFromSystemByPackageName: appsFromSystemByPackageName,
    );
  }

  Future<void> _runLiveSync({
    required String reason,
    bool initializeDefaultCategoriesIfNeeded = false,
  }) async {
    final currentSync = _liveSyncFuture;
    if (currentSync != null) {
      await currentSync;
      return;
    }

    final completer = Completer<void>();
    _liveSyncFuture = completer.future;
    final startedAt = DateTime.now().millisecondsSinceEpoch;

    try {
      if (_initialized &&
          hasRenderableHome &&
          _startupPhase != startupPhaseSyncingLive) {
        _startupPhase = startupPhaseSyncingLive;
        notifyListeners();
      }
      await _refreshState(shouldNotifyListeners: false);
      if (initializeDefaultCategoriesIfNeeded && _database.wasCreated) {
        await _initDefaultCategories();
      }
      _initialized = true;
      _staleCache = false;
      _startupPhase = startupPhaseReady;
      _lastLiveSyncAt = DateTime.now().millisecondsSinceEpoch;
      _logFirstRenderableHome('live');
      _logStartupMetric(
        'time_to_first_live_sync',
        DateTime.now().millisecondsSinceEpoch - _bootstrapStartedAt,
      );
      _logStartupMetric(
        'live_sync_duration',
        DateTime.now().millisecondsSinceEpoch - startedAt,
      );
      notifyListeners();
      completer.complete();
    } catch (error, stackTrace) {
      debugPrint('FLauncherPerf live_sync_failed reason=$reason error=$error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'apps_service',
          context: ErrorDescription('while syncing launcher apps live'),
        ),
      );
      if (hasRenderableHome) {
        _initialized = true;
        _staleCache = true;
        _startupPhase = startupPhaseDegradedCached;
        notifyListeners();
      }
      _scheduleLiveSyncRetry();
      completer.complete();
    } finally {
      _liveSyncFuture = null;
    }
  }

  void _scheduleLiveSync({required String reason}) {
    _liveSyncRetryTimer?.cancel();
    _liveSyncRetryTimer = Timer(_liveSyncWarmDelay, () {
      unawaited(_runLiveSync(reason: reason));
    });
  }

  void _scheduleLiveSyncRetry() {
    _liveSyncRetryTimer?.cancel();
    _liveSyncRetryTimer = Timer(_liveSyncRetryDelay, () {
      unawaited(_runLiveSync(reason: 'retry_live_sync'));
    });
  }

  void _logFirstRenderableHome(String source) {
    if (_firstRenderableLogged || !hasRenderableHome) {
      return;
    }
    _firstRenderableLogged = true;
    _logStartupMetric(
      'time_to_first_home($source)',
      DateTime.now().millisecondsSinceEpoch - _bootstrapStartedAt,
    );
  }

  void _logStartupMetric(String label, int elapsedMs) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('FLauncherPerf $label elapsedMs=$elapsedMs');
  }

  void sortCategory(Category category) {
    if (category.sort == CategorySort.alphabetical) {
      category.applications.sortBy((application) => application.name);
    } else {
      category.applications.sortBy<num>(
          (application) => application.categoryOrders[category.id]!);
    }
  }

  Future<Uint8List> getAppBanner(String packageName) {
    return _fLauncherChannel.getApplicationBanner(packageName);
  }

  Future<Uint8List> getAppIcon(String packageName) {
    return _fLauncherChannel.getApplicationIcon(packageName);
  }

  Future<void> launchApp(App app) {
    Future<void> future;
    if (app.action == null) {
      future = _fLauncherChannel.launchApp(app.packageName);
    } else {
      future = _fLauncherChannel.launchActivityFromAction(app.action!);
    }

    return future;
  }

  Future<void> openAppInfo(App app) =>
      _fLauncherChannel.openAppInfo(app.packageName);

  Future<void> uninstallApp(App app) =>
      _fLauncherChannel.uninstallApp(app.packageName);

  Future<void> openSettings() => _fLauncherChannel.openSettings();

  Future<bool> isDefaultLauncher() => _fLauncherChannel.isDefaultLauncher();

  Future<void> startAmbientMode() => _fLauncherChannel.startAmbientMode();

  Future<void> addToCategory(App app, Category category,
      {bool shouldNotifyListeners = true}) async {
    int index = await _database.nextAppCategoryOrder(category.id) ?? 0;
    await _database.insertAppsCategories([
      AppsCategoriesCompanion.insert(
        categoryId: category.id,
        appPackageName: app.packageName,
        order: index,
      )
    ]);

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      app.categoryOrders[categoryFound.id] = index;
      categoryFound.applications.add(app);

      if (shouldNotifyListeners) {
        sortCategory(categoryFound);
        notifyListeners();
      }
    }
  }

  Future<void> removeFromCategory(App application, Category category) async {
    await _database.deleteAppCategory(category.id, application.packageName);
    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      application.categoryOrders.remove(categoryFound.id);
      categoryFound.applications.remove(application);

      notifyListeners();
    }
  }

  Future<void> saveApplicationOrderInCategory(Category category) async {
    if (!_categoriesById.containsKey(category.id)) {
      return;
    }

    Category categoryFound = _categoriesById[category.id]!;
    List<App> applications = categoryFound.applications;
    List<AppsCategoriesCompanion> orderedAppCategories = [];

    for (int i = 0; i < applications.length; ++i) {
      orderedAppCategories.add(AppsCategoriesCompanion(
        categoryId: Value(categoryFound.id),
        appPackageName: Value(applications[i].packageName),
        order: Value(i),
      ));
    }
    await _database.replaceAppsCategories(orderedAppCategories);
    notifyListeners();
  }

  void reorderApplication(Category category, int oldIndex, int newIndex) {
    if (!_categoriesById.containsKey(category.id)) {
      return;
    }
    Category categoryFound = _categoriesById[category.id]!;
    List<App> applications = categoryFound.applications;
    App application = applications.removeAt(oldIndex);
    applications.insert(newIndex, application);

    notifyListeners();
  }

  Future<int> addCategory(String categoryName,
      {CategorySort sort = Category.Sort,
      CategoryType type = Category.Type,
      int columnsCount = Category.ColumnsCount,
      int rowHeight = Category.RowHeight,
      bool shouldNotifyListeners = true}) async {
    List<CategoriesCompanion> orderedCategories = [];
    int categoryOrder = 1, newCategoryId = -1;
    for (Category category in _categoriesById.values) {
      orderedCategories.add(CategoriesCompanion(
          id: Value(category.id), order: Value(categoryOrder++)));
    }

    try {
      newCategoryId = await _database.transaction(() async {
        int newCategoryId = await _database.insertCategory(
            CategoriesCompanion.insert(name: categoryName, order: 0));
        await _database.updateCategories(orderedCategories);

        return newCategoryId;
      });

      Map<int, Category> newCategories = Map();
      Category newCategory = Category(
          id: newCategoryId,
          name: categoryName,
          sort: sort,
          type: type,
          columnsCount: columnsCount,
          rowHeight: rowHeight,
          order: 0);
      newCategories[newCategoryId] = newCategory;

      categoryOrder = 1;
      for (Category category in _categoriesById.values) {
        newCategories[category.id] = category;
        category.order = categoryOrder++;
      }

      _categoriesById = newCategories;
      _launcherSections.add(newCategory);

      if (shouldNotifyListeners) {
        notifyListeners();
      }
    } catch (ex) {}

    return newCategoryId;
  }

  Future<void> updateCategory(int categoryId, String name, CategorySort sort,
      CategoryType type, int columnsCount, int rowHeight,
      {bool shouldNotifyListeners = true}) async {
    Category? category = _categoriesById[categoryId];
    assert(category != null);

    await _database.updateCategory(
        categoryId,
        CategoriesCompanion(
            name: Value(name),
            sort: Value(sort),
            type: Value(type),
            columnsCount: Value(columnsCount),
            rowHeight: Value(rowHeight)));

    CategorySort oldSort = category!.sort;

    category.name = name;
    category.sort = sort;
    category.type = type;
    category.columnsCount = columnsCount;
    category.rowHeight = rowHeight;

    if (oldSort != sort) {
      sortCategory(category);
    }

    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> addSpacer(int height) async {
    int order = launcherSections.length;
    int spacerId = await _database.insertSpacer(
        LauncherSpacersCompanion.insert(height: height, order: order));

    _launcherSections
        .add(LauncherSpacer(id: spacerId, height: height, order: order));

    notifyListeners();
  }

  Future<void> updateSpacerHeight(LauncherSpacer spacer, int height) async {
    await _database.updateSpacer(
        spacer.id, LauncherSpacersCompanion(height: Value(height)));

    spacer.height = height;
    notifyListeners();
  }

  Future<void> renameCategory(Category category, String categoryName) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(name: Value(categoryName)));

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.name = categoryName;
      notifyListeners();
    }
  }

  Future<void> deleteSection(int index) async {
    assert(index < _launcherSections.length);

    LauncherSection section = _launcherSections[index];
    if (section is Category) {
      await _database.deleteCategory(section.id);
      _categoriesById.remove(section.id);
    } else {
      await _database.deleteSpacer(section.id);
    }

    _launcherSections.removeAt(index);

    notifyListeners();
  }

  Future<void> moveSection(int oldIndex, int newIndex) async {
    List<LauncherSection> newSectionsList = List.of(_launcherSections);
    LauncherSection sectionToMove = newSectionsList.removeAt(oldIndex);
    newSectionsList.insert(newIndex, sectionToMove);

    List<CategoriesCompanion> orderedCategories = [];
    List<LauncherSpacersCompanion> orderedSpacers = [];
    for (int i = 0; i < newSectionsList.length; ++i) {
      LauncherSection section = newSectionsList[i];

      if (section is Category) {
        orderedCategories
            .add(CategoriesCompanion(id: Value(section.id), order: Value(i)));
      } else {
        orderedSpacers.add(
            LauncherSpacersCompanion(id: Value(section.id), order: Value(i)));
      }
    }

    await Future.wait([
      _database.updateCategories(orderedCategories),
      _database.updateSpacers(orderedSpacers)
    ]);

    _launcherSections = newSectionsList;
    notifyListeners();
  }

  Future<void> hideApplication(App application) async {
    await _database.updateApp(
        application.packageName, const AppsCompanion(hidden: Value(true)));

    if (_applications.containsKey(application.packageName)) {
      App applicationFound = _applications[application.packageName]!;
      applicationFound.hidden = true;

      for (int categoryId in applicationFound.categoryOrders.keys) {
        if (_categoriesById.containsKey(categoryId)) {
          Category category = _categoriesById[categoryId]!;
          category.applications.removeWhere((application0) =>
              application0.packageName == application.packageName);
        }
      }

      notifyListeners();
    }
  }

  Future<void> showApplication(App application) async {
    await _database.updateApp(
        application.packageName, const AppsCompanion(hidden: Value(false)));

    if (_applications.containsKey(application.packageName)) {
      App applicationFound = _applications[application.packageName]!;
      applicationFound.hidden = false;

      for (int categoryId in application.categoryOrders.keys) {
        if (_categoriesById.containsKey(categoryId)) {
          Category category = _categoriesById[categoryId]!;
          category.applications.add(application);
          sortCategory(category);
        }
      }

      notifyListeners();
    }
  }

  Future<void> unHideApplication(App application) =>
      showApplication(application);

  Future<void> setCategoryType(Category category, CategoryType type,
      {bool shouldNotifyListeners = true}) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(type: Value(type)));

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.type = type;

      if (shouldNotifyListeners) {
        notifyListeners();
      }
    }
  }

  Future<void> setCategorySort(Category category, CategorySort sort) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(sort: Value(sort)));
    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.sort = sort;
      sortCategory(categoryFound);

      notifyListeners();
    }
  }

  Future<void> moveCategory(int oldIndex, int newIndex) =>
      moveSection(oldIndex, newIndex);

  Future<void> setCategoryColumnsCount(
      Category category, int columnsCount) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(columnsCount: Value(columnsCount)));

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.columnsCount = columnsCount;

      notifyListeners();
    }
  }

  Future<void> setCategoryRowHeight(Category category, int rowHeight) async {
    await _database.updateCategory(
        category.id, CategoriesCompanion(rowHeight: Value(rowHeight)));

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.rowHeight = rowHeight;
      notifyListeners();
    }
  }

  Map<String, dynamic> exportLayoutBackup() {
    final sections = _launcherSections.map((section) {
      if (section is LauncherSpacer) {
        return <String, dynamic>{
          'type': 'spacer',
          'order': section.order,
          'height': section.height,
        };
      }

      final category = section as Category;
      return <String, dynamic>{
        'type': 'category',
        'legacyId': category.id,
        'order': category.order,
        'name': category.name,
        'sort': category.sort.name,
        'categoryType': category.type.name,
        'columnsCount': category.columnsCount,
        'rowHeight': category.rowHeight,
        'appPackageNames': category.applications
            .map((app) => app.packageName)
            .toList(growable: false),
      };
    }).toList(growable: false);

    final hiddenPackages = _applications.values
        .where((application) => application.hidden)
        .map((application) => application.packageName)
        .toList(growable: false);

    return <String, dynamic>{
      'sections': sections,
      'hiddenPackages': hiddenPackages,
    };
  }

  Future<Map<String, dynamic>> restoreLayoutBackup(
      Map<String, dynamic> data) async {
    final sections = data['sections'];
    if (sections is! List) {
      return <String, dynamic>{
        'success': false,
        'message': 'Backup is missing launcher sections.',
        'unresolvedPackages': const <String>[],
      };
    }

    final unresolvedPackages = <String>{};
    final hiddenPackages = ((data['hiddenPackages'] as List?) ?? const [])
        .map((entry) => entry.toString())
        .where((entry) => entry.trim().isNotEmpty)
        .toSet();

    await _database.transaction(() async {
      await _database.clearLauncherLayout();

      for (var index = 0; index < sections.length; index += 1) {
        final rawSection = sections[index];
        if (rawSection is! Map) {
          continue;
        }
        final section = rawSection.cast<String, dynamic>();
        final type = section['type']?.toString() ?? '';
        if (type == 'spacer') {
          await _database.insertSpacer(
            LauncherSpacersCompanion.insert(
              height: _readInt(section, 'height', 24),
              order: index,
            ),
          );
          continue;
        }

        final newCategoryId = await _database.insertCategory(
          CategoriesCompanion.insert(
            name: _readString(section, 'name', 'Category'),
            order: index,
            sort: Value(_readCategorySort(section, 'sort', Category.Sort)),
            type: Value(
                _readCategoryType(section, 'categoryType', Category.Type)),
            rowHeight:
                Value(_readInt(section, 'rowHeight', Category.RowHeight)),
            columnsCount:
                Value(_readInt(section, 'columnsCount', Category.ColumnsCount)),
          ),
        );
        final packageNames = ((section['appPackageNames'] as List?) ?? const [])
            .map((entry) => entry.toString())
            .where((entry) => entry.trim().isNotEmpty)
            .toList(growable: false);
        final appRows = <AppsCategoriesCompanion>[];
        for (var appIndex = 0; appIndex < packageNames.length; appIndex += 1) {
          final packageName = packageNames[appIndex];
          if (!_applications.containsKey(packageName)) {
            unresolvedPackages.add(packageName);
            continue;
          }
          appRows.add(
            AppsCategoriesCompanion.insert(
              categoryId: newCategoryId,
              appPackageName: packageName,
              order: appIndex,
            ),
          );
        }
        if (appRows.isNotEmpty) {
          await _database.insertAppsCategories(appRows);
        }
      }

      for (final application in _applications.values) {
        final shouldBeHidden = hiddenPackages.contains(application.packageName);
        if (application.hidden != shouldBeHidden) {
          await _database.updateApp(
            application.packageName,
            AppsCompanion(hidden: Value(shouldBeHidden)),
          );
        }
      }
    });

    await _loadStateFromDatabase();
    return <String, dynamic>{
      'success': true,
      'message': unresolvedPackages.isEmpty
          ? 'Launcher layout restored.'
          : 'Launcher layout restored with missing apps skipped.',
      'unresolvedPackages': unresolvedPackages.toList(growable: false),
    };
  }

  static int _readInt(Map<String, dynamic> data, String key, int fallback) {
    final value = data[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  static String _readString(
      Map<String, dynamic> data, String key, String fallback) {
    final value = data[key];
    return value is String ? value : fallback;
  }

  static CategorySort _readCategorySort(
    Map<String, dynamic> data,
    String key,
    CategorySort fallback,
  ) {
    final value = data[key]?.toString();
    return CategorySort.values.firstWhere(
      (candidate) => candidate.name == value,
      orElse: () => fallback,
    );
  }

  static CategoryType _readCategoryType(
    Map<String, dynamic> data,
    String key,
    CategoryType fallback,
  ) {
    final value = data[key]?.toString();
    return CategoryType.values.firstWhere(
      (candidate) => candidate.name == value,
      orElse: () => fallback,
    );
  }

  @override
  void dispose() {
    _liveSyncRetryTimer?.cancel();
    super.dispose();
  }
}
