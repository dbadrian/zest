import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  @override
  Widget build(BuildContext context) {
    final user = ref.read(authenticationServiceProvider).value?.user;
    final userCtrl = useTextEditingController(text: user?.username ?? '');
    final passwordCtrl = useTextEditingController(text: '');
    final state = ref.watch(authenticationServiceProvider);
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
