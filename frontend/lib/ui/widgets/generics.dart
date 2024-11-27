import 'package:flutter/material.dart';

import '../../routing/app_router.dart';

class ElementsVerticalSpace extends StatelessWidget {
  const ElementsVerticalSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 15,
    );
  }
}

Widget buildLoadingOverlay(BuildContext context, bool isLoading) {
  return isLoading
      ? Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.grey.withOpacity(0.2),
          child: const Center(child: CircularProgressIndicator()),
        )
      : Container();
}

void openNotImplementedDialog({void Function()? onPressed}) {
  showDialog<void>(
    context: shellNavigatorKey.currentState!.overlay!.context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Aborted!'),
        content: const Text(
            "Sorry, this functionality is currently not implemented."),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            child: const Text("Okay... :("),
            onPressed: () {
              if (onPressed != null) onPressed();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
