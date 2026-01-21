import 'package:flutter/material.dart';

class DividerText extends StatelessWidget {
  const DividerText({
    super.key,
    required this.text,
    this.textStyle,
  });

  final String text;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const SizedBox(
        width: 50,
        child: Divider(),
      ),
      Padding(
        padding: const EdgeInsets.only(
          left: 10,
          right: 10,
        ),
        child: Text(
          text,
          style: textStyle,
        ),
      ),
      const Expanded(child: Divider())
    ]);
  }
}
