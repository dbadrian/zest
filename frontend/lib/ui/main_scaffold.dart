import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:updat/updat.dart';
import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:path/path.dart' as p;

import 'package:zest/api/api_service.dart';
import 'package:zest/main.dart';
import 'package:zest/recipes/controller/search_controller.dart';
import 'package:zest/recipes/screens/recipe_draft_search.dart';
import 'package:zest/recipes/screens/recipe_edit.dart';
import 'package:zest/settings/settings_screen.dart';
import 'package:zest/ui/login_screen.dart';
import 'package:zest/ui/widgets/generics.dart';
import 'package:zest/utils/update.dart';

import '../authentication/auth_service.dart';
import '../recipes/screens/recipe_search.dart';

/// Builds the "shell" for the app by building a Scaffold with a
/// BottomNavigationBar, where [child] is placed in the body of the Scaffold.
class MainScaffold extends ConsumerWidget {
  /// Constructs an [MainScaffold].
  const MainScaffold({
    required this.child,
    super.key,
  });

  /// The widget to display in the body of the Scaffold.
  /// In this sample, it is a Navigator.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.read(authenticationServiceProvider.notifier
        .select((value) => value.isAuthenticated));
    final user = ref.watch(authenticationServiceProvider.notifier
        .select((value) => value.whoIsUser));
    return Scaffold(
      key: const Key('mainScaffold'),
      body: child,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        // title: const Text("Zest"),
        centerTitle: true,
        actions: [
          if (isAuthenticated)
            IconButton(
              icon: const Icon(
                  key: Key("appbar_addrecipe_icon"), Icons.add_card_rounded),
              onPressed: () {
                context.goNamed(RecipeEditPage.routeNameCreate);
              },
            ),
          if (isAuthenticated)
            IconButton(
              icon: const Icon(key: Key("appbar_search_icon"), Icons.search),
              onPressed: () {
                ref.read(recipeSearchFilterSettingsProvider.notifier).reset();
                context.goNamed(RecipeSearchPage.routeName);
              },
            ),
        ],
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              key: const Key('drawerButton'),
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            );
          },
        ),
      ),

      drawer: Drawer(
          key: const Key('drawer'),
          // Add a ListView to the drawer. This ensures the user can scroll
          // through the options in the drawer if there isn't enough vertical
          // space to fit everything.
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  // Important: Remove any padding from the ListView.
                  padding: EdgeInsets.zero,
                  children: [
                    if (isAuthenticated)
                      UserAccountsDrawerHeader(
                        accountName: Text(user?.firstName ?? ""),
                        accountEmail: Text(user?.email ?? ""),
                        // onDetailsPressed: () => print("asdasds"),
                      ),
                    if (!isAuthenticated)
                      DrawerHeader(
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary),
                        child: Text(
                          'Please login to continue.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    ////////////////////////////////////////////////////////////////
                    //// Main Body
                    ////////////////////////////////////////////////////////////////
                    if (isAuthenticated) ...[
                      ListTile(
                        leading: const Icon(Icons.search),
                        title: const Text('Search'),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(recipeSearchFilterSettingsProvider.notifier)
                              .reset();
                          context.goNamed(RecipeSearchPage.routeName);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.favorite),
                        title: const Text('Favorites'),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(recipeSearchFilterSettingsProvider.notifier)
                              .reset();
                          ref
                              .read(recipeSearchFilterSettingsProvider.notifier)
                              .updateFavoritesOnly(true);
                          context.goNamed(RecipeSearchPage.routeName);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.add_card_rounded),
                        title: const Text('Add Recipe'),
                        onTap: () {
                          Navigator.pop(context);
                          context.goNamed(RecipeEditPage.routeNameCreate);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.drive_file_rename_outline),
                        title: const Text('Drafts'),
                        onTap: () {
                          Navigator.pop(context);
                          context.goNamed(RecipeDraftPage.routeName);
                        },
                      ),
                      const Divider(),
                      // TODO: Add Profile
                      // const ListTile(
                      //   leading: Icon(Icons.person),
                      //   title: Text('Profile'),
                      //   // onTap: () {
                      //   //   Navigator.pop(context);
                      //   //   context.pushNamed(SettingsPage.routeName);
                      //   // },
                      //   onTap: null,
                      // ),
                    ],
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Settings'),
                      onTap: () {
                        Navigator.pop(context);
                        context.pushNamed(SettingsPage.routeName);
                      },
                    ),
                    const ElementsVerticalSpace(),
                    const ElementsVerticalSpace(),
                    if (isAuthenticated)
                      ListTile(
                        key: const Key('logout'),
                        leading: const Icon(Icons.logout),
                        title: const Text(
                          'Logout',
                          style: TextStyle(
                              // color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(authenticationServiceProvider.notifier)
                              .logout()
                              .whenComplete(() => GoRouter.of(context)
                                  .go(LoginPage.routeLocation));
                        },
                      ),
                    if (Platform.isWindows || Platform.isLinux)
                      UpdatWidget(
                        currentVersion: packageInfo
                            .version, // TODO: set to current version ${packageInfo.version}
                        getLatestVersion: () async {
                          final ret = await ref
                              .read(githubServiceProvider)
                              .getLatestVersion();
                          return ret;
                        },
                        openOnDownload: false,
                        getDownloadFileLocation: (latestVersion) async {
                          Directory downloadDirectory =
                              await getDownloadDirectory();
                          final file = File(p.join(downloadDirectory.path,
                              "zest-$latestVersion.$platformUpdateExt"));
                          debugPrint("Update file: $file");
                          return file;
                        },
                        getBinaryUrl: (latestVersion) async {
                          final assets = await ref
                              .read(githubServiceProvider)
                              .getLatestAssetList();
                          int? assetId;
                          if (assets != null) {
                            final assetCandidate = assets.firstWhere((e) {
                              return e["name"] as String ==
                                  platformUpdateName(latestVersion);
                            }, orElse: () => {});
                            assetId = assetCandidate["id"] as int?;
                          }
                          debugPrint(
                              "Downlaod URL: https://api.github.com/repos/dbadrian/zest/releases/assets/$assetId");
                          return "https://api.github.com/repos/dbadrian/zest/releases/assets/$assetId";
                        },
                        // Lastly, enter your app name so we know what to call your files.
                        appName: "Zest",
                      ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Licenses'),
                onTap: () async {
                  Navigator.pop(context);

                  if (context.mounted) {
                    showLicensePage(
                        context: context,
                        applicationName: packageInfo.appName,
                        applicationVersion:
                            "${packageInfo.version} (${packageInfo.buildNumber})", // TODO: FIX
                        applicationLegalese: "Copyright David B. Adrian 2024");
                  }
                },
              ),
            ],
          )),
      // bottomNavigationBar: BottomNavigationBar(
      //   items: const <BottomNavigationBarItem>[
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.home),
      //       label: 'A Screen',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.business),
      //       label: 'B Screen',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.notification_important_rounded),
      //       label: 'C Screen',
      //     ),
      //   ],
      //   currentIndex: _calculateSelectedIndex(context),
      //   onTap: (int idx) => _onItemTapped(idx, context),
      // ),
    );
  }

//   static int _calculateSelectedIndex(BuildContext context) {
//     final String location = GoRouterState.of(context).location;
//     if (location.startsWith('/a')) {
//       return 0;
//     }
//     if (location.startsWith('/b')) {
//       return 1;
//     }
//     if (location.startsWith('/c')) {
//       return 2;
//     }
//     return 0;
//   }

//   void _onItemTapped(int index, BuildContext context) {
//     switch (index) {
//       case 0:
//         GoRouter.of(context).go('/a');
//         break;
//       case 1:
//         GoRouter.of(context).go('/b');
//         break;
//       case 2:
//         GoRouter.of(context).go('/c');
//         break;
//     }
//   }
// }

// /// The first screen in the bottom navigation bar.
// class ScreenA extends StatelessWidget {
//   /// Constructs a [ScreenA] widget.
//   const ScreenA({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(),
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: <Widget>[
//             const Text('Screen A'),
//             TextButton(
//               onPressed: () {
//                 GoRouter.of(context).go('/a/details');
//               },
//               child: const Text('View A details'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
}
