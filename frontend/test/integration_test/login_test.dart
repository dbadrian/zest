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
import 'package:zest/config/constants.dart';
import 'package:zest/settings/settings_provider.dart';
import 'package:zest/main.dart';
import 'package:integration_test/integration_test.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
// get rid of debugPrints
  if (isProduction) {
// analyser does not like empty function body
// debugPrint = (String message, {int wrapWidth}) {};
// so i changed it to this:
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  WidgetsFlutterBinding.ensureInitialized();

  // set important variables
  SharedPreferences.setMockInitialValues({
    apiUrlKey: "http://localhost:1337/api/v1",
  });

  final sharedPrefs = await SharedPreferences.getInstance();

  if (Platform.isWindows || Platform.isLinux) {
// Initialize FFI
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
// Set the path to the database. Note: Using the `join` function from the
// `path` package is best practice to ensure the path is correctly
// constructed for each platform.
    join(appDocumentsDir.path, 'sqlite.db'),

    onCreate: (db, version) {
// Run the CREATE TABLE statement on the database.
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
// Set the version. This executes the onCreate function and provides a
// path to perform database upgrades and downgrades.
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

  group('end-to-end test', () {
    testWidgets('Check if main scaffold is rendered', (tester) async {
      await tester.pumpWidget(ProviderScope(overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        sqliteDbProvider.overrideWithValue(database),
      ], child: const ZestApp()));

      expect(find.byKey(const Key('MainScaffold')), findsOneWidget);
    });

    testWidgets('Test login functionality via real API', (tester) async {
      await tester.pumpWidget(ProviderScope(overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        sqliteDbProvider.overrideWithValue(database),
      ], child: const ZestApp()));
      final usernameKey = const Key('username');
      final passwordKey = const Key('password');
      expect(find.byKey(usernameKey), findsOneWidget);
      expect(find.byKey(passwordKey), findsOneWidget);
      final loginButton = find.byKey(const Key('login'));
      expect(loginButton, findsOneWidget);

//test without having entered correct user data to loging
      await tester.enterText(find.byKey(usernameKey), 'user');
      await tester.enterText(find.byKey(passwordKey), 'password');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
      expect(find.byKey(usernameKey), findsOneWidget);
      expect(find.byKey(passwordKey), findsOneWidget);
      final loginError = const Key('loginError_incorrect_credentials');
      expect(find.byKey(loginError), findsOneWidget);

//test with having entered user data to loging
      await tester.enterText(find.byKey(usernameKey), 'user');
      await tester.enterText(find.byKey(passwordKey), 'password');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
      expect(find.byKey(loginError), findsOneWidget);
      expect(find.byKey(const Key('appbar_search_icon')), findsNothing);

      await tester.enterText(find.byKey(usernameKey), 'admin');
      await tester.enterText(find.byKey(passwordKey), 'admin');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
      expect(find.byKey(loginError), findsNothing);

      expect(find.byKey(const Key('appbar_search_icon')), findsOneWidget);
    });

    testWidgets('Test cached username for login', (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        "authentication_service_user":
            '{"pk":"...","username":"admin","email":"..","first_name":"...","last_name":"..."}'
      });

      await tester.pumpWidget(ProviderScope(overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        sqliteDbProvider.overrideWithValue(database),
      ], child: const ZestApp()));

      final usernameKey = const Key('username');
      final passwordKey = const Key('password');
      expect(find.byKey(usernameKey), findsOneWidget);
      expect(find.byKey(passwordKey), findsOneWidget);
      final loginButton = find.byKey(const Key('login'));
      expect(loginButton, findsOneWidget);

      // final fieldWidget = find.byKey(usernameKey).evaluate().first.widget;
      // final fieldTextValue = (fieldWidget as TextFormField).controller!.text;
      // print("YTOO >$fieldTextValue<");

      await tester.pumpAndSettle();
      final TextFormField formfield =
          tester.widget<TextFormField>(find.byKey(usernameKey));

      expect(formfield.controller!.text, "admin");

      await tester.enterText(find.byKey(passwordKey), 'admin');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appbar_search_icon')), findsOneWidget);
    });
  });
}
