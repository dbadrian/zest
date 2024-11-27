import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../routing/app_router.dart';
import '../ui/widgets/generics.dart';
import 'auth_service.dart';

final authenticationDialogErrorStateProvider =
    StateProvider<bool>((ref) => false);

class ReauthenticationDialog extends HookConsumerWidget {
  const ReauthenticationDialog({super.key, this.onConfirm});

  final void Function()? onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Read out user and stored password from database
    final user = ref.watch(authenticationServiceProvider).value?.user;
    final userCtrl = useTextEditingController(text: user?.username ?? '');
    final passwordCtrl = useTextEditingController(text: '');
    final showErrorState = useState(false);

    return AlertDialog(
      title: const Text(
        "Authentication Timeout",
        style: TextStyle(
            fontSize: 20,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w600),
      ),
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Hey there! Sorry to interrupt.\n"
                  "\nYour authentication just had a scheduled timeout. "
                  "You know....security and stuff! "
                  "Let's just login again, and we all pretend this never happened!\n"),
              const SizedBox(
                height: 10,
              ),
              SizedBox(
                height: 150,
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                        textInputAction: TextInputAction.next,
                        // validator: controller.emptyValidator,
                      ),
                    ),
                  ],
                ),
              ),
              if (showErrorState.value)
                Text(
                  "Login failed: ${ref.read(authenticationServiceProvider).error}",
                  style: const TextStyle(
                    color: Colors.deepOrangeAccent, // TODO: Fix color
                    fontSize: 12, //TODO: dont use fixed size
                    fontWeight: FontWeight.w300,
                    fontFamily: "Montserrat",
                  ),
                ),
            ],
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          child: const Text("Login"),
          onPressed: () {
            final ret = ref
                .read(authenticationServiceProvider.notifier)
                .login(userCtrl.text, passwordCtrl.text);
            ret.then((value) {
              if (value) {
                showErrorState.value = false;
                onConfirm?.call();
                log("Trying to pop context");
                // Navigator.of(context).pop();
                Navigator.of(context).pop();
              } else {
                showErrorState.value = true;
              }
            });
          },
        ),
      ],
    );
  }
}

void openReauthenticationDialog({void Function()? onConfirm}) {
  showDialog<void>(
    barrierDismissible: false,
    context: shellNavigatorKey.currentState!.overlay!.context,
    builder: (BuildContext context) {
      return ReauthenticationDialog(onConfirm: onConfirm);
    },
  );
}
