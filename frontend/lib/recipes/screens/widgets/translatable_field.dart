import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zest/settings/settings_provider.dart';
import 'package:zest/utils/form_validators.dart';

import '../../../config/constants.dart';
import '../../../routing/app_router.dart';
import '../../models/translated_field.dart';

// Logic is:
//  - cLC <- getActiveLanguage
//  - rLC <- getReturnedLanguage for field
// if cLC != rLC -> fallbackLanguage -> requestedLanguage doesnt have a translation
//      -> render as to be translatable
// else non translateable

// onTap : -> open translation dialog (with all languages available, or just current!??)
// change state via dialog!?

class TranslatableField extends StatefulHookConsumerWidget {
  const TranslatableField(
      {super.key,
      required this.field,
      required this.onConfirm,
      this.textStyle});

  final TranslatedField field;
  final void Function(String) onConfirm;
  final TextStyle? textStyle;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _TranslatableFieldState();
}

class _TranslatableFieldState extends ConsumerState<TranslatableField> {
  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();

    if (canBeTranslated()) {
      return _buildTranslatable(textController);
    } else {
      return _buildDefault();
    }
  }

  Widget _buildDefault() {
    return Text(widget.field.value(), style: widget.textStyle);
  }

  Widget _buildTranslatable(textController) {
    return InkWell(
      child: Row(
        children: [
          // Text(widget.field.value()),
          _buildDefault(),
          const Icon(Icons.edit_location),
        ],
      ),
      onLongPress: () {
        final formKey_ = GlobalKey<FormState>();

        showDialog<void>(
          barrierDismissible: false,
          context: shellNavigatorKey.currentState!.overlay!.context,
          builder: (BuildContext context) {
            // late StateSetter _setState;
            return AlertDialog(
              title: const Text(
                "Translate this ingredient",
                style: TextStyle(
                    fontSize: 20,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w600),
              ),
              content: _buildTranslationDialog(formKey_, textController),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text("Submit Translation"),
                  onPressed: () {
                    if (formKey_.currentState!.validate()) {
                      // TODO: check for success here...
                      widget.onConfirm(textController.text);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );

        // Get.defaultDialog(
        //   content: _buildTranslationDialog(context, _formKey, _textController),
        //   title: "Add Translation",
        //   textCancel: "Cancel",
        //   textConfirm: "Translate",
        //   onConfirm: () async {
        //     if (_formKey.currentState!.validate()) {
        //       widget.onConfirm(_textController.text);
        //       Get.back();
        //     }
        //   },
        // );
      },
    );
  }

  bool canBeTranslated() {
    final settings = ref.read(settingsProvider);
    return settings.current.language != widget.field.activeLanguage();
  }

  Widget _buildTranslationDialog(
      GlobalKey<FormState> formKey, TextEditingController controller) {
    return Form(
      key: formKey,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: AVAILABLE_LANGUAGES[
                    ref.read(settingsProvider).current.language],
                // suffixText: "optional",
                // border: const OutlineInputBorder(),
              ),
              validator: emptyValidator,
            ),
          ),
        ],
      ),
    );
  }
}

// class TranslatableField extends StatefulWidget {
//   const TranslatableField(
//       {Key? key, required this.field, required this.onConfirm})
//       : super(key: key);

//   final TranslatedField field;
//   final void Function(String) onConfirm;

//   @override
//   State<TranslatableField> createState() => _TranslatableFieldState();
// }

// class _TranslatableFieldState extends State<TranslatableField> {
//   @override
//   Widget build(BuildContext context) {
//     if (canBeTranslated()) {
//       return _buildTranslatable();
//     } else {
//       return _buildDefault();
//     }
//   }

//   Widget _buildDefault() {
//     return Text(widget.field.value());
//   }

//   Widget _buildTranslatable() {
//     return InkWell(
//       child: Row(
//         children: [
//           Text(widget.field.value()),
//           const Icon(Icons.edit_location),
//         ],
//       ),
//       onLongPress: () {
//         final _textController = TextEditingController();
//         final _formKey = GlobalKey<FormState>();
//         // Get.defaultDialog(
//         //   content: _buildTranslationDialog(context, _formKey, _textController),
//         //   title: "Add Translation",
//         //   textCancel: "Cancel",
//         //   textConfirm: "Translate",
//         //   onConfirm: () async {
//         //     if (_formKey.currentState!.validate()) {
//         //       widget.onConfirm(_textController.text);
//         //       Get.back();
//         //     }
//         //   },
//         // );
//       },
//     );
//   }

//   bool canBeTranslated() {
//     final activeLang = Settings.to.activeLanguage;
//     final returnedLang = widget.field.activeLanguage();
//     return activeLang != returnedLang;
//   }

//   Widget _buildTranslationDialog(BuildContext context,
//       GlobalKey<FormState> formKey, TextEditingController controller) {
//     return Form(
//       key: formKey,
//       child: Row(
//         children: [
//           Expanded(
//             child: TextFormField(
//               controller: controller,
//               decoration: InputDecoration(
//                 labelText: AVAILABLE_LANGUAGES[Settings.to.activeLanguage],
//                 // suffixText: "optional",
//                 border: const OutlineInputBorder(),
//               ),
//               validator: emptyValidator,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
