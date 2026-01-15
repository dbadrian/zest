import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:updat/utils/global_options.dart';

import 'package:zest/recipes/screens/recipe_search.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'authentication/auth_service.dart';
import 'routing/app_router.dart';
import 'settings/settings_provider.dart';
import 'theme/theme_definitions.dart';

final sharedPreferencesProvider =
    Provider<SharedPreferences>((_) => throw UnimplementedError());

final sqliteDbProvider = Provider<Database>((_) => throw UnimplementedError());

// Is this a release build
const bool isProduction = bool.fromEnvironment('dart.vm.product');

late final PackageInfo packageInfo;

Future<void> main() async {
  // get rid of debugPrints
  if (isProduction) {
    // analyser does not like empty function body
    // debugPrint = (String message, {int wrapWidth}) {};
    // so i changed it to this:
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefs = await SharedPreferences.getInstance();

  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
  }

  databaseFactory = databaseFactoryFfi;

  // final appDocumentsDir = await getApplicationDocumentsDirectory();

  // final database = await openDatabase(
  //   // Set the path to the database. Note: Using the `join` function from the
  //   // `path` package is best practice to ensure the path is correctly
  //   // constructed for each platform.
  //   join(appDocumentsDir.path, 'sqlite.db'),

  //   onCreate: (db, version) {
  //     // Run the CREATE TABLE statement on the database.
  //     return db.execute(
  //       'CREATE TABLE $RECIPE_DRAFT_DB_KEY(id INTEGER PRIMARY KEY, updatedLast INT, state TEXT)',
  //     );
  //   },

  //   onUpgrade: (Database db, int oldVersion, int newVersion) {
  //     if (oldVersion < newVersion && newVersion == 3) {
  //       db.execute(
  //           "ALTER TABLE $RECIPE_DRAFT_DB_KEY ADD COLUMN updatedLast INT;");
  //     }
  //   },
  //   // Set the version. This executes the onCreate function and provides a
  //   // path to perform database upgrades and downgrades.
  //   version: 3,
  // );

  packageInfo = await PackageInfo.fromPlatform();

  // Configure headers
  // TODO: LOW RELEASE Remove for public version
  UpdatGlobalOptions.downloadReleaseHeaders = {
    "Accept": "application/octet-stream",
  };

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      // sqliteDbProvider.overrideWithValue(database),
    ],
    child: const ZestApp(),
  ));
}

class ZestApp extends ConsumerStatefulWidget {
  const ZestApp({super.key});

  @override
  ConsumerState<ZestApp> createState() => _ZestAppState();
}

class _ZestAppState extends ConsumerState<ZestApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize persistent cache
    // await ref.read(persistentCacheProvider).init();

    // // Pre-cache static data in background
    // ref.read(preCacheStaticDataProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(getRouterProvider);

    final Color themeBaseColor = ref.watch(
        settingsProvider.select((settings) => settings.dirty.themeBaseColor));

    final lightTheme_ = lightTheme.copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: themeBaseColor));
    final darkTheme_ = darkTheme.copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: themeBaseColor));

    final useDarkTheme = ref.watch(settingsProvider.select((settings) {
      return settings.dirty.useDarkTheme;
    }));

    return MaterialApp.router(
      // routeInformationParser: router.routeInformationParser,
      // routerDelegate: router.routerDelegate,
      // routeInformationProvider: router.routeInformationProvider,
      routerConfig: router,
      title: 'Zest',
      theme: lightTheme_,
      darkTheme: darkTheme_,
      themeMode: useDarkTheme ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
    );
  }
}

// class ZestApp extends ConsumerWidget {
//   const ZestApp({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {

//     // Initialize persistent cache
//     await ref.read(persistentCacheProvider).init();

//     final router = ref.watch(getRouterProvider);

//     final Color themeBaseColor = ref.watch(
//         settingsProvider.select((settings) => settings.dirty.themeBaseColor));

//     final lightTheme_ = lightTheme.copyWith(
//         colorScheme: ColorScheme.fromSeed(seedColor: themeBaseColor));
//     final darkTheme_ = darkTheme.copyWith(
//         colorScheme: ColorScheme.fromSeed(seedColor: themeBaseColor));

//     final useDarkTheme = ref.watch(settingsProvider.select((settings) {
//       return settings.dirty.useDarkTheme;
//     }));

//     return MaterialApp.router(
//       // routeInformationParser: router.routeInformationParser,
//       // routerDelegate: router.routerDelegate,
//       // routeInformationProvider: router.routeInformationProvider,
//       routerConfig: router,
//       title: 'Zest',
//       theme: lightTheme_,
//       darkTheme: darkTheme_,
//       themeMode: useDarkTheme ? ThemeMode.dark : ThemeMode.light,
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  static String get routeName => 'home';
  static String get routeLocation => '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.watch(authenticationServiceProvider.notifier);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
              "Hello ${ref.watch(authenticationServiceProvider).value?.user.username}"),
          if (authNotifier.isAuthenticated)
            Wrap(
              // mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    GoRouter.of(context).go(RecipeSearchPage.routeLocation);
                  },
                  child: const Text("Recipe Search"),
                ),
                ElevatedButton(
                  onPressed: () {
                    // context.goNamed(
                    //   RecipeEditPage.routeNameCreate,
                    // );
                  },
                  child: const Text("Create New Recipe"),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(authenticationServiceProvider.notifier)
                        .refreshToken();
                  },
                  child: const Text("Refresh Access Token"),
                ),
              ],
            )
        ],
      ),
    );
  }
}
