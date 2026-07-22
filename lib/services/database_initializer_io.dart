/// Initializes sqflite_common_ffi on desktop platforms.
library;

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> initializeDatabase() async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
