import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zest/recipes/screens/recipe_edit.dart';
import 'package:zest/utils/form_validators.dart';

import '../../controller/edit_controller.dart';

class InstructionGroups extends ConsumerWidget {
  const InstructionGroups({super.key, this.recipeId, this.draftId});

  final String? recipeId;
  final int? draftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // debugPrint("Building all instruction groups...");
    final instructionGroupsState = ref.watch(
        recipeEditControllerProvider(recipeId, draftId: draftId)
            .select((s) => s.value!.instructionGroups));
    final controller = ref.read(
        recipeEditControllerProvider(recipeId, draftId: draftId).notifier);

    // Initialise a scroll controller.
    final ScrollController _scrollController = ScrollController();

    return Column(children: [
      ReorderableListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        buildDefaultDragHandles: false, // disable due to desktop/web
        padding: const EdgeInsets.symmetric(horizontal: 10),
        // proxyDecorator: proxyDecorator,
        children: [
          ...instructionGroupsState!.asMap().entries.map((e) {
            return Row(
              key: Key(e.key.toString()),
              children: <Widget>[
                Expanded(
                  child: NamedInstructionGroup(
                    key: Key(e.key.toString()),
                    recipeId: recipeId,
                    draftId: draftId,
                    groupId: e.key,
                  ),
                ),
                if (instructionGroupsState.length > 1)
                  ReorderableDragStartListener(
                    index: e.key,
                    child: const Icon(Icons.drag_handle_rounded),
                  ),
              ],
            );
          })
        ],
        onReorder: (oldIndex, newIndex) {
          controller.moveInstructionGroup(oldIndex, newIndex);
        },
      ),
      TextButton(
        onPressed: () => controller.addInstructionGroup(),
        child: const Text('Add Instruction Group'),
      ),
    ]);
  }
}

class NamedInstructionGroup extends ConsumerStatefulWidget {
  const NamedInstructionGroup({
    super.key,
    required this.groupId,
    required this.recipeId,
    required this.draftId,
  });

  final int groupId;
  final String? recipeId;
  final int? draftId;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _NamedInstructionGroupState();
}

class _NamedInstructionGroupState extends ConsumerState<NamedInstructionGroup> {
  var nameCtrl = TextEditingController();
  var instructionFocusNode = FocusNode(); // one per instruction field
  var instructionEditController = TextEditingController();

  late final RecipeEditController recipeEditctrl;

  @override
  void initState() {
    super.initState();
    recipeEditctrl = ref.read(
        recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
            .notifier);
  }

  @override
  void dispose() {
    instructionEditController.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // debugPrint('rebuild instruction group...');
    final groups = ref.watch(
        recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
            .select((s) => s.value!.instructionGroups));

    // TODO: Not quite sure why this logic is necessary if group is deleted.
    // This should be further investigated.
    if (widget.groupId >= groups!.length) {
      return Container();
    }

    final group = groups[widget.groupId];
    nameCtrl = updateTextController(nameCtrl, group.name);

    // < new version, were a single texteditcontroller is used >
    final joinedInstructions = group.instructions.join("\n\n");
    instructionEditController =
        updateTextController(instructionEditController, joinedInstructions);

    return Padding(
      padding: const EdgeInsets.only(
        left: 0,
        top: 5,
        right: 0,
        bottom: 5,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                  controller: nameCtrl,
                  maxLines: null,
                  validator: emptyValidator,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixText: "  ",
                    hintText: "Title of Instruction Group",
                    border: UnderlineInputBorder(),
                    // isDense: true,
                  ),
                  onChanged: (newValue) {
                    recipeEditctrl.updateInstructionGroupName(
                        widget.groupId, newValue);
                  }),
            ),
            IconButton(
                onPressed: (() =>
                    recipeEditctrl.deleteInstructionGroup(widget.groupId)),
                icon: Icon(Icons.delete_forever))
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 20,
            top: 5,
            right: 0,
            bottom: 5,
          ),
          child: TextFormField(
            controller: instructionEditController,
            focusNode: instructionFocusNode,
            validator: emptyValidator,
            onChanged: (newValue) =>
                recipeEditctrl.updateInstructionV2(widget.groupId, newValue),
            onSaved: (newValue) => recipeEditctrl.updateInstructionV2(
                widget.groupId, newValue ?? ""),
            maxLines: null,
            decoration: InputDecoration(
              // prefixText: "${e.key + 1}. ",
              // // suffixIcon:
              // //     : null,
              hintText: "Insert some instructional text...",
              border: const UnderlineInputBorder(),
              isDense: true, // Added this
              contentPadding: const EdgeInsets.all(4), // Added this
            ),
          ),
        ),
      ]),
    );
  }
}
