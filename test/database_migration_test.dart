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

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations.dart';
import 'package:flauncher/database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;
import 'generated_migrations/schema_v5.dart' as v5;
import 'generated_migrations/schema_v6.dart' as v6;
import 'generated_migrations/schema_v7.dart' as v7;
import 'test_sqlite_setup.dart';

void main() {
  late SchemaVerifier verifier;
  final migrationSkip = !sqliteAvailable
      ? 'sqlite3.dll is not available for Drift migration tests on this machine.'
      : false;

  setUpAll(() {
    configureSqliteForTests();
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('upgrade from v1 to v7', () async {
    final schema = await verifier.schemaAt(1);

    final oldDb = v1.DatabaseAtV1(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v1.AppsCompanion.insert(
            packageName: 'me.efesser.flauncher',
            name: 'FLauncher',
            className: '.MainActivity',
            version: '0.0.1',
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v1.CategoriesCompanion.insert(name: 'Applications', order: 0),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v1.AppsCategoriesCompanion.insert(
            categoryId: categoryId,
            appPackageName: 'me.efesser.flauncher',
            order: 0,
          ),
        );
    await oldDb.close();

    await _migrateAndExpectV7(schema, verifier);
  }, skip: migrationSkip);

  test('upgrade from v2 to v7', () async {
    final schema = await verifier.schemaAt(2);

    final oldDb = v2.DatabaseAtV2(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v2.AppsCompanion.insert(
            packageName: 'me.efesser.flauncher',
            name: 'FLauncher',
            version: '0.0.1',
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v2.CategoriesCompanion.insert(name: 'Applications', order: 0),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v2.AppsCategoriesCompanion.insert(
            categoryId: categoryId,
            appPackageName: 'me.efesser.flauncher',
            order: 0,
          ),
        );
    await oldDb.close();

    await _migrateAndExpectV7(schema, verifier);
  }, skip: migrationSkip);

  test('upgrade from v3 to v7', () async {
    final schema = await verifier.schemaAt(3);

    final oldDb = v3.DatabaseAtV3(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v3.AppsCompanion.insert(
            packageName: 'me.efesser.flauncher',
            name: 'FLauncher',
            version: '0.0.1',
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v3.CategoriesCompanion.insert(name: 'Applications', order: 0),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v3.AppsCategoriesCompanion.insert(
            categoryId: categoryId,
            appPackageName: 'me.efesser.flauncher',
            order: 0,
          ),
        );
    await oldDb.close();

    await _migrateAndExpectV7(schema, verifier);
  }, skip: migrationSkip);

  test('upgrade from v4 to v7', () async {
    final schema = await verifier.schemaAt(4);

    final oldDb = v4.DatabaseAtV4(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v4.AppsCompanion.insert(
            packageName: 'me.efesser.flauncher',
            name: 'FLauncher',
            version: '0.0.1',
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v4.CategoriesCompanion.insert(
            name: 'Applications',
            type: const Value(1),
            order: 0,
          ),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v4.AppsCategoriesCompanion.insert(
            categoryId: categoryId,
            appPackageName: 'me.efesser.flauncher',
            order: 0,
          ),
        );
    await oldDb.close();

    await _migrateAndExpectV7(schema, verifier);
  }, skip: migrationSkip);

  test('upgrade from v5 to v7', () async {
    final schema = await verifier.schemaAt(5);

    final oldDb = v5.DatabaseAtV5(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v5.AppsCompanion.insert(
            packageName: 'me.efesser.flauncher',
            name: 'FLauncher',
            version: '0.0.1',
            sideloaded: const Value(true),
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v5.CategoriesCompanion.insert(
            name: 'Applications',
            type: const Value(1),
            order: 0,
          ),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v5.AppsCategoriesCompanion.insert(
            categoryId: categoryId,
            appPackageName: 'me.efesser.flauncher',
            order: 0,
          ),
        );
    await oldDb.close();

    await _migrateAndExpectV7(schema, verifier);
  }, skip: migrationSkip);

  test('upgrade from v6 to v7', () async {
    final schema = await verifier.schemaAt(6);

    final oldDb = v6.DatabaseAtV6(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v6.AppsCompanion.insert(
            packageName: 'me.efesser.flauncher',
            name: 'FLauncher',
            version: '0.0.1',
            sideloaded: const Value(true),
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v6.CategoriesCompanion.insert(
            name: 'Applications',
            type: const Value(1),
            order: 0,
          ),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v6.AppsCategoriesCompanion.insert(
            categoryId: categoryId,
            appPackageName: 'me.efesser.flauncher',
            order: 0,
          ),
        );
    await oldDb.close();

    await _migrateAndExpectV7(schema, verifier);
  }, skip: migrationSkip);
}

Future<void> _migrateAndExpectV7(
  dynamic schema,
  SchemaVerifier verifier,
) async {
  final db = FLauncherDatabase(schema.newConnection());
  await verifier.migrateAndValidate(db, 7);
  await db.close();

  final migratedDb = v7.DatabaseAtV7(schema.newConnection().executor);
  await _expectMigratedV7State(migratedDb);
  await migratedDb.close();
}

Future<void> _expectMigratedV7State(v7.DatabaseAtV7 migratedDb) async {
  final v7.AppsData app = await migratedDb.select(migratedDb.apps).getSingle();
  final v7.CategoriesData category =
      await migratedDb.select(migratedDb.categories).getSingle();
  final v7.AppsCategoriesData appsCategory =
      await migratedDb.select(migratedDb.appsCategories).getSingle();
  final spacers = await migratedDb.select(migratedDb.launcherSpacers).get();

  expect(app.packageName, 'me.efesser.flauncher');
  expect(app.name, 'FLauncher');
  expect(app.version, '0.0.1');
  expect(app.hidden, false);

  expect(category.id, 1);
  expect(category.name, 'Applications');
  expect(category.order, 0);
  expect(category.sort, 0);
  expect(category.type, 1);
  expect(category.columnsCount, 6);
  expect(category.rowHeight, 110);

  expect(appsCategory.appPackageName, 'me.efesser.flauncher');
  expect(appsCategory.categoryId, 1);
  expect(appsCategory.order, 0);
  expect(spacers, isEmpty);
}
