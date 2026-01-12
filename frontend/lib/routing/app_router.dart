import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/authentication/auth_service.dart';
import 'package:zest/camera/screens.dart';
import 'package:zest/recipes/screens/recipe_edit.dart';
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
  final localShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    // debugLogDiagnostics: true,
    initialLocation: SplashScreen.routeLocation,
    routes: [
      ShellRoute(
        navigatorKey: localShellNavigatorKey,
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return MainScaffold(key: UniqueKey(), child: child);
        },
        routes: [
          GoRoute(
            path: SplashScreen.routeLocation,
            name: SplashScreen.routeName,
            pageBuilder: (context, state) => MaterialPage(
              key: ValueKey(SplashScreen.routeLocation),
              child: const SplashScreen(),
            ),
          ),
          GoRoute(
            path: HomePage.routeLocation,
            name: HomePage.routeName,
            pageBuilder: (context, state) => MaterialPage(
              key: ValueKey(HomePage.routeLocation),
              child: const HomePage(),
            ),
          ),
          GoRoute(
            path: LoginPage.routeLocation,
            name: LoginPage.routeName,
            pageBuilder: (context, state) => MaterialPage(
              key: ValueKey(LoginPage.routeLocation),
              child: const LoginPage(),
            ),
          ),
          GoRoute(
            path: SettingsPage.routeLocation,
            name: SettingsPage.routeName,
            pageBuilder: (context, state) => MaterialPage(
              key: ValueKey(SettingsPage.routeLocation),
              child: const SettingsPage(),
            ),
          ),
          GoRoute(
            path: TakePictureScreen.routeLocation,
            name: TakePictureScreen.routeName,
            pageBuilder: (context, state) => MaterialPage(
              key: ValueKey(TakePictureScreen.routeLocation),
              child: const TakePictureScreen(),
            ),
          ),
          GoRoute(
            path: RecipeSearchPage.routeLocation,
            name: RecipeSearchPage.routeName,
            pageBuilder: (context, state) => MaterialPage(
              key: ValueKey(RecipeSearchPage.routeLocation),
              child: const RecipeSearchPage(),
            ),
            routes: [
              GoRoute(
                name: RecipeEditScreen.routeNameCreate,
                path: 'create',
                pageBuilder: (context, state) {
                  return MaterialPage(
                    key: ValueKey(RecipeEditScreen.routeNameCreate),
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
                    key: ValueKey("${RecipeDetailsPage.routeName}_$recipeId"),
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
                        key: ValueKey(
                            "${RecipeEditScreen.routeNameEdit}_${recipeId}_${state.extra}"),
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
      final authState = ref.read(authenticationServiceProvider);

      debugPrint("[Router] Currently on page ${state.uri.toString()}");

      // If our async state is loading, don't perform redirects, yet
      if (authState.isLoading) return null;

      final isAuthenticated = authState.hasValue && authState.value != null;
      final loggingIn = state.uri.toString() == LoginPage.routeLocation;

      debugPrint(
          "[Router] isAuthenticate=$isAuthenticated loggingIn=$loggingIn");

      // Only redirect if user is logging in AND not already on target page
      if (isAuthenticated &&
          loggingIn &&
          state.uri.toString() != RecipeSearchPage.routeLocation) {
        debugPrint("[Router] Redirecting Login -> RecipeSearchPage");

        return RecipeSearchPage.routeLocation;
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(children: [Text("ERROR!!! ${state.error}")]),
      ),
    ),
  );
}
