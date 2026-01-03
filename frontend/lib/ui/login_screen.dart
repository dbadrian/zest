import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  var showPassword = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    userCtrl.text =
        ref.read(authenticationServiceProvider).value?.user?.username ??
            'admin@test.com';

    showPassword = false;
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

    if (!state.isLoading) {
      userCtrl.text =
          ref.watch(authenticationServiceProvider).value?.user?.username ??
              'admin@test.com';
    }

    if (state.hasError) {
      passwordCtrl.clear();
    }
    passwordCtrl.text = "changethis";

    return Stack(
      children: [
        buildLoadingOverlay(context, state.isLoading || state.value == null),
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
                    enabled: !state.isLoading,
                    // validator: controller.emptyValidator,
                  ),
                ),
                const ElementsVerticalSpace(),
                Stack(
                  children: [
                    // Expanded(
                    //   child:
                    TextFormField(
                      key: const Key('password'),
                      decoration: const InputDecoration(
                        labelText: "Password",
                        // border: OutlineInputBorder(),
                      ),
                      controller: passwordCtrl,
                      obscureText: !showPassword,
                      enabled: !state.isLoading,
                      // maxLength: 32,

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
                      // ),
                    ),
                    Positioned(
                        // top: MediaQuery.of(context).size.height * 0.45,
                        top: 10,
                        right: 0, // the position from the right
                        child: IconButton(
                            onPressed: () {
                              setState(() {
                                showPassword = !showPassword;
                              });
                            },
                            icon: Icon(!showPassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded))),
                  ],
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
      ],
    );
  }
}
