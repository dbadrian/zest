import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shared_routines.dart';

void main() async {
  var (sharedPrefs, database) = await prepareAppForIntegrationTest();

  group('end-to-end test', () {
    testWidgets('Check if main scaffold is rendered', (tester) async {
      await startAppDefault(tester,
          sharedPrefs: sharedPrefs, database: database);
      expect(find.byKey(const Key('MainScaffold')), findsOneWidget);
    });

    testWidgets('Test login functionality via real API', (tester) async {
      await startAppDefault(tester,
          sharedPrefs: sharedPrefs, database: database);
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

      await startAppDefault(tester,
          sharedPrefs: sharedPrefs, database: database);
      final usernameKey = const Key('username');
      final passwordKey = const Key('password');
      expect(find.byKey(usernameKey), findsOneWidget);
      expect(find.byKey(passwordKey), findsOneWidget);
      final loginButton = find.byKey(const Key('login'));
      expect(loginButton, findsOneWidget);

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
