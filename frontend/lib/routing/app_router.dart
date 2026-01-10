import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/recipes/screens/edit_new.dart';
import 'package:zest/recipes/screens/recipe_details.dart';
import 'package:zest/recipes/screens/recipe_search.dart';

import '../main.dart';

import '../settings/settings_screen.dart';
import '../ui/login_screen.dart';
import '../ui/main_scaffold.dart';
import '../ui/splash_screen.dart';

part 'app_router.g.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

@riverpod
GoRouter getRouter(Ref ref) {
  // ref.watch(routerAuthNotifierProvider);
  // final authNotifier = ref.watch(authenticationServiceProvider.notifier);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: LoginPage.routeLocation,
    // refreshListenable: authNotifier,
    routes: [
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return MainScaffold(key: const Key("MainScaffold"), child: child);
        },
        routes: [
          GoRoute(
            path: SplashPage.routeLocation,
            name: SplashPage.routeName,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SplashPage(),
            ),
          ),
          GoRoute(
            path: HomePage.routeLocation,
            name: HomePage.routeName,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
            ),
          ),
          GoRoute(
            path: LoginPage.routeLocation,
            name: LoginPage.routeName,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const LoginPage(),
            ),
          ),
          GoRoute(
            path: SettingsPage.routeLocation,
            name: SettingsPage.routeName,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SettingsPage(),
            ),
          ),
          // // Recipe related routes
          // GoRoute(
          //   path: RecipeDraftPage.routeLocation,
          //   name: RecipeDraftPage.routeName,
          //   pageBuilder: (context, state) => NoTransitionPage(
          //     key: state.pageKey,
          //     child: const RecipeDraftPage(),
          //   ),
          //   routes: [
          //     GoRoute(
          //       name: RecipeEditPage.routeNameDraftEdit,
          //       path: ':draftId',
          //       pageBuilder: (context, state) {
          //         final draftId =
          //             int.tryParse(state.pathParameters['draftId'] ?? "");
          //         return MaterialPage(
          //           key: state.pageKey,
          //           child: RecipeEditPage(draftId: draftId),
          //         );
          //       },
          //     ),
          //   ],
          // ),
          GoRoute(
            path: RecipeSearchPage.routeLocation,
            name: RecipeSearchPage.routeName,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const RecipeSearchPage(),
            ),
            routes: [
              GoRoute(
                name: RecipeEditScreen.routeNameCreate,
                path: 'create',
                pageBuilder: (context, state) {
                  return MaterialPage(
                    key: state.pageKey,
                    child: RecipeEditScreen(recipeId: null),
                  );
                },
              ),
              GoRoute(
                name: RecipeDetailsPage.routeName,
                path: ':id',
                pageBuilder: (context, state) {
                  final int recipeId = int.parse(state.pathParameters['id']!);
                  return MaterialPage(
                    key: state.pageKey,
                    child: RecipeDetailsPage(recipeId: recipeId),
                  );
                },
                routes: [
                  GoRoute(
                    name: RecipeEditScreen.routeNameEdit,
                    path: 'edit',
                    pageBuilder: (context, state) {
                      final int recipeId =
                          int.parse(state.pathParameters['id']!);

                      return MaterialPage(
                        key: state.pageKey,
                        child: RecipeEditScreen(recipeId: recipeId),
                      );
                    },
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    ],
    redirect: (context, state) {
      // final loginWhitelist = {
      //   SplashPage.routeLocation,
      //   SettingsPage.routeLocation,
      // };
      // return null;
      // If our async state is loading, don't perform redirects, yet
      // if (authNotifier.isLoading) return null;
      //

      return null;

      // // Special case for loading splash
      // final isSplash = state.uri.toString() == SplashPage.routeLocation;
      // if (isSplash) {
      //   return isAuthed
      //       ? RecipeSearchPage.routeLocation
      //       : LoginPage.routeLocation;
      // }

      // // Opening login page but already logged in -> home page
      // final isLoggingIn = state.uri.toString() == LoginPage.routeLocation;
      // if (isLoggingIn) {
      //   return isAuthed ? RecipeSearchPage.routeLocation : null;
      // }

      // final isWhitelisted = loginWhitelist.contains(state.uri.toString());
      // if (isAuthed || isWhitelisted) return null;

      // // if (!isAuthed) return LoginPage.routeLocation;
      // // if not authed and not whitelisted -> login page
      // //
      // return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(children: [Text("ERROR!!! ${state.error}")]),
      ),
    ),
  );
}
