import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/core/network/api_exception.dart';
import 'package:zest/core/providers/http_client_provider.dart';
import 'package:zest/main.dart';

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
    super.initState();
    userCtrl.text =
        ref.read(authenticationServiceProvider).value?.user.username ??
            ref.read(authenticationServiceProvider.notifier).lastUser ??
            "";

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

    if (state.isLoading) {
      // TODO: Low overlay with loading st
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    userCtrl.text = state.valueOrNull?.user.username ?? userCtrl.text;

    String errorMsg = "";
    if (state.hasError) {
      // passwordCtrl.clear();
      if ((state.error as ApiException).isNetworkError) {
        errorMsg = "Network Error";
      } else if ((state.error as ApiException).isTimeout) {
        errorMsg = "Connection Timeout";
      } else if ((state.error as ApiException).isUnauthorized) {
        errorMsg = "Incorrect username or password";
      } else {
        errorMsg = "Unknown Error";
      }
    }

    return Stack(
      children: [
        buildLoadingOverlay(context, state.isLoading),
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
                // const ElementsVerticalSpace(),
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
                    "Login failed: $errorMsg",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14, //TODO: LOW dont use fixed size
                      fontWeight: FontWeight.w300,
                      fontFamily: "Montserrat",
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final resetResponse = await ref
                          .read(apiClientProvider(withAuthentication: false))
                          .post<Map<String, dynamic>>(
                              "/auth/password-reset/request", (e) => e,
                              body: {'username': userCtrl.text, 'email': null});

                      resetResponse.when(success: (data, statusCode, headers) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text("Reset Link Sent"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      "If the given email exists, a reset link has been sent. Open your email app to check your inbox.",
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text("Dismiss"),
                                  ),
                                ],
                              );
                            });
                      }, failure: (error) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text("Reset Link Sent"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      "Unknown failure occured while requesting the reset. Check internet connection?",
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text("Dismiss"),
                                  ),
                                ],
                              );
                            });
                      });
                    },
                    child: Text("Reset Password"),
                  ),
                ),
                const ElementsVerticalSpace(),
                Wrap(
                  // mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                    // SizedBox(width: 10),
                    // ElevatedButton(
                    //   key: const Key('continue_offline'),
                    //   onPressed: () async {
                    //     GoRouter.of(context).go(RecipeSearchPage.routeLocation);
                    //   },
                    //   child: const Text('Continue Offline'),
                    // ),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
