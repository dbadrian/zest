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
      Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: TextField(
          scrollController: _scrollController,
          autofocus: true,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          controller: TextEditingController(
              text: instructionGroupsState[0].instructions.join("\n\n")),
          autocorrect: true,
          onChanged: (s) => {},
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
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
  final List<FocusNode> focusNodes = []; // one per instruction field
  var nameCtrl = TextEditingController();
  final List<TextEditingController> textEditctrls = [];

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
    flushInstructionControllers();
    nameCtrl.dispose();
    super.dispose();
  }

  void flushInstructionControllers() {
    textEditctrls.map((e) => e.dispose());
    textEditctrls.clear();
  }

  Widget buildDeleteIconSuffix(onPressed) {
    return Focus(
      descendantsAreFocusable: false,
      canRequestFocus: false,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.delete),
      ),
    );
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
    // flushInstructionControllers();

    // < legacy version, we each instruction had its own text controller >
    // group.instructions.asMap().entries.forEach((e) {
    //   if (textEditctrls.length <= e.key) {
    //     textEditctrls.add(TextEditingController());
    //   }

    //   textEditctrls[e.key] =
    //       updateTextController(textEditctrls[e.key], e.value);

    //   textEditctrls.add(TextEditingController(text: e.value));
    //   if (focusNodes.length <= e.key) {
    //     focusNodes.add(FocusNode());
    //   }
    // });

    // < new version, were a single texteditcontroller is used >
    final joined_instructions = group.instructions.join("\n\n");
    if (textEditctrls.length <= 0) {
      textEditctrls.add(TextEditingController());
    }
    textEditctrls[0] =
        updateTextController(textEditctrls[0], joined_instructions);
    if (focusNodes.length <= 0) {
      focusNodes.add(FocusNode());
    }

    // delete entries which are too many
    if (textEditctrls.length > group.instructions.length) {
      textEditctrls.removeRange(
          group.instructions.length, textEditctrls.length);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
          recipeEditctrl.addInstruction(widget.groupId);
          // length is still old as not rebuild eyt
          if (focusNodes.length == group.instructions.length) {
            focusNodes.add(FocusNode());
          }
          focusNodes[group.instructions.length].requestFocus();
        },
      },
      child: Padding(
        padding: const EdgeInsets.only(
          left: 0,
          top: 5,
          right: 0,
          bottom: 5,
        ),
        child: DecoratedBox(
          // margin: EdgeInsets.only(left: 30, top: 100, right: 30, bottom: 50),
          // height: double.infinity,
          // width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              width: 1,
            ),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(5)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 1), // changes position of shadow
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
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
              ReorderableListView(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                buildDefaultDragHandles: false, // disable due to desktop/web
                padding: const EdgeInsets.only(left: 10, right: 5),
                // proxyDecorator: proxyDecorator,
                children: <Widget>[
                  ...textEditctrls.asMap().entries.map((e) {
                    return CallbackShortcuts(
                      key: Key(e.key.toString()),
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.arrowUp,
                            control: true, shift: true): () {
                          final maybeNewIdx = recipeEditctrl.moveInstructionUp(
                              widget.groupId, e.key);
                          focusNodes[maybeNewIdx].requestFocus();
                        },
                        const SingleActivator(LogicalKeyboardKey.arrowDown,
                            control: true, shift: true): () {
                          final maybeNewIdx = recipeEditctrl
                              .moveInstructionDown(widget.groupId, e.key);
                          focusNodes[maybeNewIdx].requestFocus();
                        },
                      },
                      child: ListTile(
                        dense: true,
                        visualDensity:
                            const VisualDensity(vertical: -4), // to compact
                        title: TextFormField(
                          controller: e.value,
                          focusNode: focusNodes[e.key],
                          validator: emptyValidator,
                          onChanged: (newValue) =>
                              recipeEditctrl.updateInstruction(
                                  widget.groupId, e.key, newValue),
                          onSaved: (newValue) =>
                              recipeEditctrl.updateInstruction(
                                  widget.groupId, e.key, newValue ?? ""),
                          maxLines: null,
                          decoration: InputDecoration(
                            prefixText: "${e.key + 1}. ",
                            // suffixIcon:
                            //     : null,
                            hintText: "Insert some instructional text...",
                            border: const UnderlineInputBorder(),
                            isDense: true, // Added this
                            contentPadding:
                                const EdgeInsets.all(4), // Added this
                          ),
                        ),
                        trailing: (group.instructions.length > 1)
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  buildDeleteIconSuffix(
                                    () => recipeEditctrl.deleteInstruction(
                                        widget.groupId, e.key),
                                  ),
                                  ReorderableDragStartListener(
                                    index: e.key,
                                    child: const Icon(
                                      Icons.drag_handle_rounded,
                                      // size: 12,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  }),
                ],
                onReorder: (int oldIndex, int newIndex) {
                  recipeEditctrl.moveInstruction(
                      widget.groupId, oldIndex, newIndex);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                      onPressed: (() {
                        recipeEditctrl.addInstruction(widget.groupId);
                        // length is still old as not rebuild eyt
                        if (focusNodes.length == group.instructions.length) {
                          focusNodes.add(FocusNode());
                        }
                        focusNodes[group.instructions.length].requestFocus();
                      }),
                      child: const Text("Add Instruction")),
                  TextButton(
                      onPressed: (() => recipeEditctrl
                          .deleteInstructionGroup(widget.groupId)),
                      child: const Text("Delete this Instruction Group")),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
