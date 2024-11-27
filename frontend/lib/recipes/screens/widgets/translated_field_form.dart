// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:zest/app/config/constants.dart';

// class TranslatedFieldFormBinding extends Bindings {
//   @override
//   void dependencies() {
//     Get.lazyPut<TranslatedFieldFormController>(
//       () => TranslatedFieldFormController(),
//     );
//   }
// }

// class TranslatedFieldFormController extends GetxController {
//   // final _availableLanguages = {...AVAILABLE_LANGUAGES};
//   // final _fields = <TextEditingController>[].obs;
//   final _fields = AVAILABLE_LANGUAGES.map((key, value) => MapEntry(
//         key,
//         TextEditingController(),
//       ));

//   @override
//   void onClose() {
//     _fields.forEach((key, value) {
//       value.dispose();
//     });
//   }
// }

// class TranslatedFieldFormView extends GetView<TranslatedFieldFormController> {
//   const TranslatedFieldFormView({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Column(
//         children: [
//           const Padding(
//             padding: EdgeInsets.only(bottom: 10),
//             child: Text("Name"),
//           ),
//           for (var entry in AVAILABLE_LANGUAGES.entries)
//             Row(
//               children: [
//                 Text(entry.value),
//                 TextFormField(
//                   controller: controller._fields[entry.key],
//                   decoration: const InputDecoration(
//                     labelText: 'Value',
//                     border: OutlineInputBorder(),
//                   ),
//                   // validator: emptyValidator,
//                   maxLines: null,
//                 ),
//               ],
//             )
//         ],
//       ),
//     );
//   }
// }
