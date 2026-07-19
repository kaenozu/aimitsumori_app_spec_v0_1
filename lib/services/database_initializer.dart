/// Initializes the SQLite implementation for the current platform.
library;

import 'database_initializer_stub.dart'
    if (dart.library.io) 'database_initializer_io.dart'
    as platform;

Future<void> initializeDatabase() => platform.initializeDatabase();
