import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqlite3/sqlite3.dart';

bool _configured = false;

void configureSqliteForTests() {
  if (_configured) {
    return;
  }
  _configured = true;

  if (!Platform.isWindows) {
    return;
  }

  final candidates = <String>[
    r'C:\Windows\System32\winsqlite3.dll',
    path.join(Directory.current.path, 'test', 'bin', 'sqlite3.dll'),
    path.join(Directory.current.path, 'sqlite3.dll'),
  ];

  final dllPath = candidates.firstWhere(
    (candidate) => File(candidate).existsSync(),
    orElse: () => '',
  );

  if (dllPath.isEmpty) {
    return;
  }

  sqlite_open.open.overrideFor(
    sqlite_open.OperatingSystem.windows,
    () => DynamicLibrary.open(dllPath),
  );
}

bool get sqliteAvailable {
  configureSqliteForTests();

  try {
    final database = sqlite3.openInMemory();
    database.dispose();
    return true;
  } catch (_) {
    return false;
  }
}
