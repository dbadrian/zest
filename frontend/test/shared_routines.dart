import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:updat/utils/global_options.dart';
import 'package:integration_test/integration_test.dart';

import 'package:zest/config/constants.dart';
import 'package:zest/settings/settings_provider.dart';
import 'package:zest/main.dart';

Future<(SharedPreferences, Database)> prepareAppForIntegrationTest() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // WidgetsFlutterBinding.ensureInitialized();

  // We test against a local server
  SharedPreferences.setMockInitialValues({
    apiUrlKey: "http://localhost:8000/api/v1",
  });

  final sharedPrefs = await SharedPreferences.getInstance();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
  }

  databaseFactory = databaseFactoryFfi;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
    return '.';
  });

  final appDocumentsDir = await getApplicationDocumentsDirectory();

  final database = await openDatabase(
    join(appDocumentsDir.path, 'sqlite.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE $RECIPE_DRAFT_DB_KEY(id INTEGER PRIMARY KEY, updatedLast INT, state TEXT)',
      );
    },
    onUpgrade: (Database db, int oldVersion, int newVersion) {
      if (oldVersion < newVersion && newVersion == 3) {
        db.execute(
            "ALTER TABLE $RECIPE_DRAFT_DB_KEY ADD COLUMN updatedLast INT;");
      }
    },
    version: 3,
  );

  PackageInfo.setMockInitialValues(
      appName: "abc",
      packageName: "com.example.example",
      version: "1.0",
      buildNumber: "2",
      buildSignature: "buildSignature");
  packageInfo = await PackageInfo.fromPlatform();

// Configure headers
// TODO: Remove for public version
  UpdatGlobalOptions.downloadReleaseHeaders = {
    "Accept": "application/octet-stream",
  };

  FlutterSecureStorage.setMockInitialValues({});

  return (sharedPrefs, database);
}

Future<void> startAppDefault(
  WidgetTester tester, {
  required SharedPreferences sharedPrefs,
  required Database database,
}) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    sqliteDbProvider.overrideWithValue(database),
  ], child: const ZestApp()));
}

/// A testing utility which creates a [ProviderContainer] and automatically
/// disposes it at the end of the test.
ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  // Create a ProviderContainer, and optionally allow specifying parameters.
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );

  // When the test ends, dispose the container.
  addTearDown(container.dispose);

  return container;
}

Future<void> performLogin(tester) async {
  final usernameKey = const Key('username');
  final passwordKey = const Key('password');
  final loginKey = const Key('login');
  final loginButton = find.byKey(loginKey);

  await tester.enterText(find.byKey(passwordKey), 'changethis'); // why the fuck
  await tester.enterText(find.byKey(usernameKey), 'admin@test.com');
  await tester.enterText(find.byKey(passwordKey), 'changethis');
  await tester.tap(loginButton);
  await tester.pumpAndSettle();
}
