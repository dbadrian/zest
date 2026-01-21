import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http_interceptor/http_interceptor.dart';

class InvalidJSONDataException implements Exception {
  final String? message;
  InvalidJSONDataException({this.message});
}

Map<String, dynamic> jsonDecodeResponseData(Response data) {
  final contentType = data.headers["content-type"];
  if (contentType != null && contentType == "application/json") {
    return jsonDecode(utf8.decode(data.bodyBytes));
  }
  throw InvalidJSONDataException(
      message: "Response appears not to be JSON data (according to header)");
}

void openServerNotAvailableDialog(BuildContext context,
    {void Function()? onPressed, String? title, String? content}) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title ?? 'Server unreachable!'),
        content: Text(content ??
            "Sorry, server can't be reached at the moment.\n\n"
                "Please try again in a moment."),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            child: const Text("Okay... I'll wait a moment!"),
            onPressed: () {
              if (onPressed != null) {
                onPressed();
              }

              if (context.mounted) {
                GoRouter.of(context).pop();
              }
            },
          ),
        ],
      );
    },
  );
}
