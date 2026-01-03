// import 'package:flutter/material.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:zest/recipes/screens/recipe_details.dart';
// import 'package:zest/recipes/screens/recipe_edit.dart';
// import 'package:zest/utils/form_validators.dart';

// import '../../controller/edit_controller.dart';

// class InstructionGroups extends ConsumerStatefulWidget {
//   const InstructionGroups({super.key, this.recipeId, this.draftId});
//   @override
//   ConsumerState<InstructionGroups> createState() => _InstructionGroupsState();
//   final String? recipeId;
//   final int? draftId;
// }

// // We subclass ConsumerState instead of State
// class _InstructionGroupsState extends ConsumerState<InstructionGroups> {
//   bool _previewInstructions = false;

//   @override
//   Widget build(BuildContext context) {
//     // debugPrint("Building all instruction groups...");
//     final instructionGroupsState = ref.watch(
//         recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
//             .select((s) => s.value!.instructionGroups));
//     final controller = ref.read(
//         recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
//             .notifier);

//     return Column(children: [
//       _previewInstructions
//           ? Padding(
//               padding: const EdgeInsets.only(left: 15, top: 10, right: 10),
//               child: Column(
//                 children: [
//                   // Kinda a duplicate implementation, but okay for now maybe?
//                   ...instructionGroupsState!.asMap().entries.map((eGrp) {
//                     return Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           eGrp.value.name,
//                           style: Theme.of(context)
//                               .textTheme
//                               .titleLarge!
//                               .copyWith(
//                                 color: Theme.of(context).colorScheme.primary,
//                               ),
//                         ),
//                         ...eGrp.value.instructions.asMap().entries.map((e) {
//                           return Padding(
//                             padding: const EdgeInsets.only(left: 10, bottom: 8),
//                             child: buildInstructionLineWidget(
//                                 context, e.key, e.value),
//                           );
//                         })
//                       ],
//                     );
//                   })
//                 ],
//               ),
//             )
//           : ReorderableListView(
//               physics: const NeverScrollableScrollPhysics(),
//               shrinkWrap: true,
//               buildDefaultDragHandles: false, // disable due to desktop/web
//               padding: const EdgeInsets.symmetric(horizontal: 10),
//               // proxyDecorator: proxyDecorator,
//               children: [
//                 ...instructionGroupsState!.asMap().entries.map((e) {
//                   return Row(
//                     key: Key(e.key.toString()),
//                     children: <Widget>[
//                       Expanded(
//                         child: NamedInstructionGroup(
//                           key: Key(e.key.toString()),
//                           recipeId: widget.recipeId,
//                           draftId: widget.draftId,
//                           groupId: e.key,
//                         ),
//                       ),
//                       Column(
//                         children: [
//                           IconButton(
//                               onPressed: (() =>
//                                   controller.deleteInstructionGroup(e.key)),
//                               icon: Icon(Icons.delete_forever)),
//                           if (instructionGroupsState.length > 1)
//                             ReorderableDragStartListener(
//                               index: e.key,
//                               child: const Icon(Icons.drag_handle_rounded),
//                             ),
//                         ],
//                       )
//                     ],
//                   );
//                 })
//               ],
//               onReorder: (oldIndex, newIndex) {
//                 controller.moveInstructionGroup(oldIndex, newIndex);
//               },
//             ),
//       Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           if (!_previewInstructions)
//             TextButton(
//               onPressed: () => controller.addInstructionGroup(),
//               child: const Text('Add Instruction Group'),
//             ),
//           TextButton(
//             onPressed: () {
//               setState(() {
//                 _previewInstructions = !_previewInstructions;
//               });
//             },
//             child: Text(
//                 _previewInstructions ? "Edit Instructions" : 'Show Preview'),
//           ),
//         ],
//       )
//     ]);
//   }
// }

// class NamedInstructionGroup extends ConsumerStatefulWidget {
//   const NamedInstructionGroup({
//     super.key,
//     required this.groupId,
//     required this.recipeId,
//     required this.draftId,
//   });

//   final int groupId;
//   final String? recipeId;
//   final int? draftId;

//   @override
//   ConsumerState<ConsumerStatefulWidget> createState() =>
//       _NamedInstructionGroupState();
// }

// class _NamedInstructionGroupState extends ConsumerState<NamedInstructionGroup> {
//   var nameCtrl = TextEditingController();
//   var instructionFocusNode = FocusNode(); // one per instruction field
//   var instructionEditController = TextEditingController();

//   late final RecipeEditController recipeEditctrl;

//   @override
//   void initState() {
//     super.initState();
//     recipeEditctrl = ref.read(
//         recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
//             .notifier);
//   }

//   @override
//   void dispose() {
//     instructionEditController.dispose();
//     nameCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // debugPrint('rebuild instruction group...');
//     final groups = ref.watch(
//         recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
//             .select((s) => s.value!.instructionGroups));

//     // TODO: Not quite sure why this logic is necessary if group is deleted.
//     // This should be further investigated.
//     if (widget.groupId >= groups!.length) {
//       return Container();
//     }

//     final group = groups[widget.groupId];
//     nameCtrl = updateTextController(nameCtrl, group.name);

//     // < new version, were a single texteditcontroller is used >
//     final joinedInstructions = group.instructions.join("\n\n");
//     instructionEditController =
//         updateTextController(instructionEditController, joinedInstructions);

//     return Padding(
//         padding: const EdgeInsets.only(
//           left: 0,
//           top: 5,
//           right: 0,
//           bottom: 5,
//         ),
//         child: DecoratedBox(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             border: Border.all(
//               width: 1,
//             ),
//             borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(3),
//                 topRight: Radius.circular(3),
//                 bottomLeft: Radius.circular(3),
//                 bottomRight: Radius.circular(3)),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withValues(alpha: 0.5),
//                 spreadRadius: 5,
//                 blurRadius: 7,
//                 offset: const Offset(0, 1), // changes position of shadow
//               ),
//             ],
//           ),
//           child: Column(mainAxisSize: MainAxisSize.min, children: [
//             TextFormField(
//                 controller: nameCtrl,
//                 maxLines: null,
//                 validator: emptyValidator,
//                 decoration: const InputDecoration(
//                   isDense: false,
//                   prefixText: "  ",
//                   hintText: "Title of Instruction Group",
//                   border: UnderlineInputBorder(),
//                   // isDense: true,
//                 ),
//                 onChanged: (newValue) {
//                   recipeEditctrl.updateInstructionGroupName(
//                       widget.groupId, newValue);
//                 }),
//             Padding(
//               padding: const EdgeInsets.only(
//                 left: 20,
//                 top: 5,
//                 right: 0,
//                 bottom: 5,
//               ),
//               child: TextFormField(
//                 controller: instructionEditController,
//                 focusNode: instructionFocusNode,
//                 validator: emptyValidator,
//                 onChanged: (newValue) => recipeEditctrl.updateInstructionV2(
//                     widget.groupId, newValue),
//                 onSaved: (newValue) => recipeEditctrl.updateInstructionV2(
//                     widget.groupId, newValue ?? ""),
//                 maxLines: null,
//                 decoration: InputDecoration(
//                   hintText: "Insert some instructional text...",
//                   border: const UnderlineInputBorder(),
//                   isDense: false, // Added this
//                   contentPadding: const EdgeInsets.all(4), // Added this
//                 ),
//               ),
//             ),
//           ]),
//         ));
//   }
// }
