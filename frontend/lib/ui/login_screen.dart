import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/authentication/auth_state.dart';
import 'package:zest/authentication/user.dart';

import 'package:zest/recipes/screens/recipe_search.dart';
import 'package:zest/ui/widgets/generics.dart';

import '../authentication/auth_service.dart';

class LoginPage extends StatefulHookConsumerWidget {
  const LoginPage({super.key});
  static String get routeName => 'login';
  static String get routeLocation => '/$routeName';

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends ConsumerState<LoginPage> {
  final userCtrl = TextEditingController(text: '');
  final passwordCtrl = TextEditingController(text: '');

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    userCtrl.text =
        ref.read(authenticationServiceProvider).value?.user?.username ?? '';
  }

  @override
  void dispose() {
    userCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authenticationServiceProvider);
    userCtrl.text =
        ref.watch(authenticationServiceProvider).value?.user?.username ?? '';
    print(">>> ${state.value}");
    return switch (state) {
      AsyncData(:final value) => _buildForm(state),
      // AsyncLoading => const Center(child: CircularProgressIndicator()),
      AsyncError(:final error) => Text('Error: $error'),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _buildForm(AsyncValue<AuthState?> state) {
    if (state.value == null) {
      // apparently, the state is null during the first build
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Center(
          child: SizedBox(
            height: 280,
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Login",
                  style: TextStyle(
                      fontSize: 40,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w600),
                ),
                const ElementsVerticalSpace(),
                Expanded(
                  child: TextFormField(
                    key: const Key('username'),
                    controller: userCtrl,
                    decoration: const InputDecoration(
                      labelText: "Username",
                    ),
                    textInputAction: TextInputAction.next,
                    // validator: controller.emptyValidator,
                  ),
                ),
                const ElementsVerticalSpace(),
                Expanded(
                  child: TextFormField(
                    key: const Key('password'),
                    decoration: const InputDecoration(
                      labelText: "Password",
                      // border: OutlineInputBorder(),
                    ),
                    controller: passwordCtrl,
                    obscureText: true,
                    // textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) async {
                      final loggedIn = await ref
                          .read(authenticationServiceProvider.notifier)
                          .login(userCtrl.text, passwordCtrl.text);

                      if (loggedIn) {
                        if (context.mounted) {
                          GoRouter.of(context)
                              .go(RecipeSearchPage.routeLocation);
                        }
                      }
                      ;
                    },
                    // validator: controller.emptyValidator,
                  ),
                ),
                if (state.hasError)
                  Text(
                    key: const Key('loginError_incorrect_credentials'),
                    "Login failed: ${ref.read(authenticationServiceProvider).error.toString()}",
                    style: const TextStyle(
                      color: Colors.deepOrangeAccent,
                      fontSize: 14, //TODO: dont use fixed size
                      fontWeight: FontWeight.w300,
                      fontFamily: "Montserrat",
                    ),
                  ),
                const ElementsVerticalSpace(),
                ElevatedButton(
                  key: const Key('login'),
                  onPressed: state.isLoading
                      ? null
                      // otherwise, get the notifier and sign in
                      : () async {
                          final loggedIn = await ref
                              .read(authenticationServiceProvider.notifier)
                              .login(userCtrl.text, passwordCtrl.text);

                          if (loggedIn) {
                            if (context.mounted) {
                              GoRouter.of(context)
                                  .go(RecipeSearchPage.routeLocation);
                            }
                          }
                        },
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
        buildLoadingOverlay(context, state.isLoading),
      ],
    );
  }
}
