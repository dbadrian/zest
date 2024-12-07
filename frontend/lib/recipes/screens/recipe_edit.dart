import 'dart:convert';
import 'dart:math';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import 'package:form_builder_extra_fields/form_builder_extra_fields.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zest/config/constants.dart';

import 'package:zest/recipes/controller/edit_controller.dart';
import 'package:zest/recipes/models/models.dart';
import 'package:zest/recipes/screens/recipe_details.dart';
import 'package:zest/recipes/screens/widgets/ingredient_form.dart';
import 'package:zest/ui/widgets/divider_text.dart';
import 'package:zest/ui/widgets/generics.dart';
import 'package:zest/utils/form_validators.dart';
import 'package:zest/utils/loading_indicator.dart';

import '../../utils/utils.dart';
import '../controller/details_controller.dart';
import 'widgets/instruction_form.dart';

///
/// A utility function that helps this mess of a code I wrote
/// Essentially it disposes an existing textEditingController
/// and creates a new one to replace it.
/// This is was required of the dumb way I implemented things to avoid
/// constant refreshed while keeping the state outside, which is not recommened
/// but made sense/was necessary at somepoint
///
TextSelection calculateTextSelection(TextEditingController ctrl, String text) {
  return TextSelection.fromPosition(
      TextPosition(offset: min(ctrl.text.length, ctrl.selection.baseOffset)));
}

TextEditingController updateTextController(
    TextEditingController ctrl, String text) {
  var oldSelection = ctrl.selection;
  ctrl.dispose();
  var nctrl = TextEditingController();
  nctrl.text = text;
  nctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: min(nctrl.text.length, oldSelection.baseOffset)));
  return nctrl;
}

class RecipeEditPage extends ConsumerWidget {
  static String get routeNameEdit => 'recipe_edit';
  static String get routeNameDraftEdit => 'recipe_draft_edit';
  static String get routeNameCreate => 'recipe_create';

  const RecipeEditPage({super.key, this.recipeId, this.draftId});
  final String? recipeId;
  final int? draftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We filter based on recipe, as this will only ever change
    // when the the editor is first loaded or user pressed save
    // final recipeRemote = ref.watch(
    //     recipeEditControllerProvider(recipeId, draftId: draftId)
    //         .selectAsync((value) => value.recipe));
    final recipeRemote = ref.watch(
        recipeEditControllerProvider(recipeId, draftId: draftId)
            .selectAsync((value) => value.recipe));

    // return state.when(
    //   data: (value) {
    //     return LayoutBuilder(
    //       builder: (BuildContext context, BoxConstraints constraints) {
    //         if (constraints.maxWidth > 800) {
    //           return RecipeEditWideWidget(
    //             recipeId: recipeId,
    //             draftId: draftId,
    //           );
    //         } else {
    //           return RecipeEditNarrowWidget(
    //             recipeId: recipeId,
    //             draftId: draftId,
    //           );
    //         }
    //       },
    //     );
    //   },
    //   loading: () {
    //     return CircularProgressIndicator();
    //   },
    //   error: (e, s) {
    //     debugPrint("Error: $e");
    //     return Text("Error: $e");
    //   },
    // );

    // map all its states to widgets and return the result
    return FutureBuilder(
      future: recipeRemote,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          final state = ref
              .read(recipeEditControllerProvider(recipeId, draftId: draftId));
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth > 800) {
                return RecipeEditWideWidget(
                  recipeId: recipeId,
                  draftId: draftId,
                );
              } else {
                return RecipeEditNarrowWidget(
                  recipeId: recipeId,
                  draftId: draftId,
                );
              }
            },
          );
        } else {
          // return Text("Error: Couldn't build recipe editing widget $recipeId.");
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Preparing Recipe Editor... please wait a moment!"),
              ElementsVerticalSpace(),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
      },
    );
  }
}

class RecipeEditNarrowWidget extends StatelessWidget {
  const RecipeEditNarrowWidget({super.key, this.recipeId, this.draftId});

  final String? recipeId;
  final int? draftId;

  @override
  Widget build(BuildContext context) {
    return RecipeEditWideWidget(
      recipeId: recipeId,
      draftId: draftId,
    );
  }
}

class RecipeEditWideWidget extends HookConsumerWidget {
  RecipeEditWideWidget({super.key, this.recipeId, this.draftId});

  final String? recipeId;
  final int? draftId;
  final formKey = GlobalKey<FormState>();

  Future<bool> saveRecipe(ref, recipeEditStateFormKey, context) async {
    // Validate returns true if the form is valid, or false otherwise.
    final controller = ref.read(
        recipeEditControllerProvider(recipeId, draftId: draftId).notifier);
    controller.purgeEmptyOptionals();
    if (recipeEditStateFormKey.currentState!.validate()) {
      recipeEditStateFormKey.currentState!.save();
      LoadingIndicatorDialog().show(context, text: "Saving to cloud...");
      final controller = ref.read(
          recipeEditControllerProvider(recipeId, draftId: draftId).notifier);
      final success = await controller.updateRecipe();
      LoadingIndicatorDialog().dismiss();

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Updated saved :)'),
              duration: Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Some error occurred while saving the recipe to the cloud...')),
          );
        }
      }
      return success;
    }

    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeEditStateFormKey = formKey;
    final scrollController = useScrollController();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): () {
          // shift focus to next node
          FocusScope.of(context).nextFocus();
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): () {
          // shift focus to next node
          FocusScope.of(context).previousFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            () async {
          final success =
              await saveRecipe(ref, recipeEditStateFormKey, context);
          if (success) {
            final controller = ref.read(
                recipeEditControllerProvider(recipeId, draftId: draftId)
                    .notifier);
            controller.deleteRecipeDraft();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          ref
              .read(recipeEditControllerProvider(recipeId).notifier)
              .stepStateBack();
        },
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          ref
              .read(recipeEditControllerProvider(recipeId).notifier)
              .stepStateForward();
        }
      },
      child: SingleChildScrollView(
        controller: scrollController,
        child: Form(
          key: recipeEditStateFormKey,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                      onPressed: () {
                        ref
                            .read(
                                recipeEditControllerProvider(recipeId).notifier)
                            .stepStateBack();
                      },
                      icon: const Icon(Icons.arrow_back)),
                  IconButton(
                      onPressed: () {
                        ref
                            .read(
                                recipeEditControllerProvider(recipeId).notifier)
                            .stepStateForward();
                      },
                      icon: const Icon(Icons.arrow_forward)),
                  if (recipeId == null)
                    Expanded(
                      child: TextFormField(
                        onFieldSubmitted: (value) {
                          try {
                            final json = jsonDecode(
                                value); // Attempt to decode the JSON string
                            // debugPrint(json);
                            ref
                                .read(recipeEditControllerProvider(recipeId)
                                    .notifier)
                                .fillRecipeFromJSON(json);
                          } catch (e) {
                            debugPrint(
                                "Invalid JSON"); // If an exception is thrown, it's invalid JSON
                          }
                        },
                      ),
                    )
                  // TextButton(
                  //   child: Text("ADD FROM JSON"),
                  //   onPressed: () {},
                  // ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                child:
                    RecipeEditMetaFields(recipeId: recipeId, draftId: draftId),
              ),
              const SizedBox(height: 30),
              const DividerText(
                textStyle: TextStyle(fontWeight: FontWeight.w600),
                text: "Ingredients",
              ),
              IngredientGroups(recipeId: recipeId, draftId: draftId),
              const SizedBox(height: 30),
              const DividerText(
                textStyle: TextStyle(fontWeight: FontWeight.w600),
                text: "Instructions",
              ),
              InstructionGroups(recipeId: recipeId, draftId: draftId),
              // Text("------------------------------------------"),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      if (recipeId != null) {
                        // TODO: Can this be avoided somehow?
                        ref.invalidate(
                            RecipeDetailsControllerProvider(recipeId!));
                        context.goNamed(
                          RecipeDetailsPage.routeName,
                          pathParameters: {'id': recipeId.toString()},
                        );
                      } else {
                        context.pop();
                      }
                    },
                    child: const Text("Back"),
                  ),
                  const SizedBox(
                    width: 25,
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final controller = ref.read(recipeEditControllerProvider(
                              recipeId,
                              draftId: draftId)
                          .notifier);
                      final rec = ref.read(recipeEditControllerProvider(
                              recipeId,
                              draftId: draftId)
                          .select((s) => s.value!.recipe));
                      controller.rebuildStateFromRecipe(rec!);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.error),
                    ),
                    child: Text(
                      "Restore",
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                  const SizedBox(
                    width: 25,
                  ),
                  // PURGE
                  // OutlinedButton(
                  //   onPressed: () {
                  //     final controller = ref
                  //         .read(recipeEditControllerProvider(recipeId, draftId: draftId).notifier);
                  //     controller.purgeEmptyOptionals();
                  //   },
                  //   style: OutlinedButton.styleFrom(
                  //     side:
                  //         BorderSide(color: Theme.of(context).colorScheme.error),
                  //   ),
                  //   child: Text(
                  //     "PURGE DEV",
                  //     style:
                  //         TextStyle(color: Theme.of(context).colorScheme.error),
                  //   ),
                  // ),
                  // const SizedBox(
                  //   width: 25,
                  // ),
                  ElevatedButton(
                    onPressed: () async {
                      final controller = ref.read(recipeEditControllerProvider(
                              recipeId,
                              draftId: draftId)
                          .notifier);
                      controller.saveRecipeDraft();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Draft Saved !'),
                            duration: Duration(milliseconds: 500),
                          ),
                        );
                      }
                    },
                    child: const Text('Save as draft'),
                  ),
                  const SizedBox(
                    width: 25,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final success = await saveRecipe(
                          ref, recipeEditStateFormKey, context);
                      if (success) {
                        final controller = ref.read(
                            recipeEditControllerProvider(recipeId,
                                    draftId: draftId)
                                .notifier);
                        controller.deleteRecipeDraft();
                      }
                    },
                    child: const Text('Save'),
                  ),
                  const SizedBox(
                    width: 25,
                  ),
                  // if (ref
                  //     .read(recipeEditControllerProvider(recipeId, draftId: draftId)
                  //         .select((v) => v.value!.recipe!.recipeId))
                  //     .isNotEmpty)
                  ElevatedButton(
                    onPressed: () async {
                      // Validate returns true if the form is valid, or false otherwise.
                      if (recipeEditStateFormKey.currentState!.validate()) {
                        recipeEditStateFormKey.currentState!.save();

                        LoadingIndicatorDialog()
                            .show(context, text: "Saving to cloud...");

                        final controller = ref.read(
                            recipeEditControllerProvider(recipeId,
                                    draftId: draftId)
                                .notifier);
                        final success = await controller.updateRecipe();
                        if (success) {
                          controller.deleteRecipeDraft();
                        }

                        LoadingIndicatorDialog().dismiss();

                        final rId = ref.read(recipeEditControllerProvider(
                                recipeId,
                                draftId: draftId)
                            .select((v) => v.value!.recipe!.recipeId));

                        if (success) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saved to cloud :)'),
                                duration: Duration(milliseconds: 500),
                              ),
                            );
                            // TODO: Can this be avoided somehow?
                            ref.invalidate(
                                RecipeDetailsControllerProvider(rId));
                            context.goNamed(
                              RecipeDetailsPage.routeName,
                              pathParameters: {'id': rId.toString()},
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Unknown error occured communicating with backend!')),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Save & Close'),
                  ),
                  const SizedBox(
                    height: 30,
                  )
                ],
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeEditMetaFields extends ConsumerStatefulWidget {
  const RecipeEditMetaFields({super.key, this.recipeId, this.draftId});

  final String? recipeId;
  final int? draftId;

  @override
  RecipeEditMetaFieldsState createState() => RecipeEditMetaFieldsState();
}

class RecipeEditMetaFieldsState extends ConsumerState<RecipeEditMetaFields> {
  TextEditingController titleController = TextEditingController();
  TextEditingController subtitleController = TextEditingController();
  TextEditingController commentController = TextEditingController();
  TextEditingController servingsController = TextEditingController();
  TextEditingController prepTimeController = TextEditingController();
  TextEditingController cookTimeController = TextEditingController();
  TextEditingController sourceNameController = TextEditingController();
  TextEditingController sourcePageController = TextEditingController();
  TextEditingController sourceUrlController = TextEditingController();

  final controllers = Map<String, Pair<TextEditingController, Function>>;

  @override
  void initState() {
    super.initState();

    titleController = updateTextController(
        titleController,
        ref.read(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.title ?? "MEH")));

    subtitleController = updateTextController(
        subtitleController,
        ref.read(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.subtitle ?? "")));

    commentController = updateTextController(
        commentController,
        ref.read(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.ownerComment ?? "")));

    servingsController = updateTextController(
        servingsController,
        ref.read(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.servings ?? "")));

    prepTimeController = updateTextController(
        prepTimeController,
        ref.read(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.prepTime ?? "")));

    cookTimeController = updateTextController(
        cookTimeController,
        ref.read(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.cookTime ?? "")));

    sourceNameController = updateTextController(
        sourceNameController,
        ref.read(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.sourceName ?? "")));

    sourcePageController = updateTextController(
        sourcePageController,
        ref.read(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.sourcePage ?? "")));

    sourceUrlController = updateTextController(
        sourceUrlController,
        ref.read(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.sourceUrl ?? "")));
  }

  @override
  void dispose() {
    super.dispose();

    titleController.dispose();
    subtitleController.dispose();
    commentController.dispose();
    servingsController.dispose();
    prepTimeController.dispose();
    cookTimeController.dispose();
    sourceNameController.dispose();
    sourcePageController.dispose();
    sourceUrlController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(
        recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
            .notifier);

    titleController = updateTextController(
        titleController,
        ref.watch(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.title ?? "")));

    subtitleController = updateTextController(
        subtitleController,
        ref.watch(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.subtitle ?? "")));

    commentController = updateTextController(
        commentController,
        ref.watch(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.ownerComment ?? "")));

    servingsController = updateTextController(
        servingsController,
        ref.watch(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.servings ?? "")));

    prepTimeController = updateTextController(
        prepTimeController,
        ref.watch(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.prepTime ?? "")));

    cookTimeController = updateTextController(
        cookTimeController,
        ref.watch(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.cookTime ?? "")));

    sourceNameController = updateTextController(
        sourceNameController,
        ref.watch(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.sourceName ?? "")));

    sourcePageController = updateTextController(
        sourcePageController,
        ref.watch(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.sourcePage ?? "")));

    sourceUrlController = updateTextController(
        sourceUrlController,
        ref.watch(recipeEditControllerProvider(widget.recipeId)
            .select((s) => s.value?.sourceUrl ?? "")));

    return Column(
      children: [
        const DividerText(
            textStyle: TextStyle(fontWeight: FontWeight.w600),
            text: "General Details"),
        ListTile(
          leading: const Icon(Icons.security_rounded),
          title: const Text("Recipe Visibility (private)"),
          trailing: Checkbox(
            value: ref.watch(recipeEditControllerProvider(widget.recipeId,
                    draftId: widget.draftId)
                .select((s) => s.value!.private)),
            onChanged: (s) => controller.updatePrivate(s!),
          ),
        ),
        // const SizedBox(height: 30),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                // initialValue: ref.watch(
                //     recipeEditControllerProvider(recipeId, draftId: draftId)
                //         .select((s) => s.value!.title)),
                controller: titleController,
                /* */
                validator: emptyValidator,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                onChanged: (s) => controller.updateTitle(s),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                // maxLength: 255,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(255),
                ],
                maxLines: null,
              ),
            ),
            if (widget.recipeId == null)
              SizedBox(
                width: 20,
              ),
            if (widget.recipeId == null)
              DropdownButton<String>(
                  value: ref.watch(recipeEditControllerProvider(widget.recipeId,
                          draftId: widget.draftId)
                      .select((s) => s.value!.lang)),
                  icon: const Icon(Icons.arrow_downward),
                  iconSize: 24,
                  elevation: 16,
                  // style: const TextStyle(color: Colors.deepPurple),
                  // underline: Container(
                  //   height: 2,
                  //   color: Theme.of(ref).colorScheme.primary,
                  // ),
                  onChanged: (String? newValue) {
                    ref
                        .read(recipeEditControllerProvider(widget.recipeId,
                                draftId: widget.draftId)
                            .notifier)
                        .updateLanguage(newValue!);
                  },
                  items: [
                    for (final entry in AVAILABLE_LANGUAGES.entries)
                      DropdownMenuItem<String>(
                        value: entry.key,
                        child: Row(
                          children: [
                            CountryFlag.fromLanguageCode(
                              entry.key,
                              height: 30,
                              width: 40,
                              shape: const RoundedRectangle(6),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(entry.value)
                          ],
                        ),
                      ),
                  ]),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: subtitleController,
          decoration: const InputDecoration(
            labelText: 'Subtitle',
            hintText: "optional",
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (s) => controller.updateSubtitle(s),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          inputFormatters: [
            LengthLimitingTextInputFormatter(255),
          ],
          maxLines: null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: commentController,
          decoration: const InputDecoration(
            labelText: 'Comment',
            hintText: "optional",
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (s) => controller.updateOwnerComment(s),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          // maxLength: 255,
          inputFormatters: [
            LengthLimitingTextInputFormatter(255),
          ],
          maxLines: null,
        ),
        const SizedBox(height: 12),
        FormBuilderRatingBar(
          name: "difficulty",
          initialValue: ref.watch(recipeEditControllerProvider(widget.recipeId,
                  draftId: widget.draftId)
              .select((s) => s.value?.difficulty.toDouble() ?? 0)),
          maxRating: 3,
          minRating: 0,
          itemSize: 30,
          itemCount: 3,
          decoration: const InputDecoration(
            labelText: "How difficult is the recipe? (Technique/Skills)",
            border: InputBorder.none,
          ),
          itemPadding: const EdgeInsets.all(5),
          ratingWidget: RatingWidget(
            full: Icon(
              Icons.food_bank,
              color: Theme.of(context).colorScheme.primary,
            ),
            half: const Icon(Icons.food_bank_outlined),
            empty: const Icon(Icons.food_bank_outlined),
          ),
          onChanged: (d) => controller.updateDifficulty(d!.toInt()),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          unratedColor: Theme.of(context).colorScheme.error,
          glowColor: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: servingsController,
          validator: ((value) => chainValidators(value, [
                emptyValidator,
                ((value) => minValueValidator(value, minValue: 1)),
                ((value) => maxValueValidator(value, maxValue: 99)),
              ])),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Servings *'),
          onChanged: (s) => controller.updateServings(s),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          // max value
        ),
        const SizedBox(height: 30),
        const DividerText(
            textStyle: TextStyle(fontWeight: FontWeight.w600),
            text: "Categories"),
        FormBuilderFilterChip(
          validator: emptyListValidator,
          name: "categories",
          showCheckmark: false,
          initialValue: ref
              .watch(recipeEditControllerProvider(widget.recipeId,
                      draftId: widget.draftId)
                  .select((s) => s.value!.categories))
              .map<int>((RecipeCategory e) => e.id)
              .toList(),
          spacing: 10,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          decoration: const InputDecoration(
            // contentPadding: EdgeInsets.only(bottom: -5, top: 19),
            // labelText: "What categories does this recipe belong to?",
            isDense: false,
            // enabledBorder: InputBorder.none,
            border: OutlineInputBorder(borderSide: BorderSide.none),
            // contentPadding: const EdgeInsets.fromLTRB(0, 0, 12, 24),
          ),

          selectedColor: Theme.of(context).colorScheme.secondaryContainer,
          options: ref
              .watch(recipeEditControllerProvider(widget.recipeId,
                      draftId: widget.draftId)
                  .select((s) => s.value!.validRecipeCategoryChoices))
              .entries
              .map(
                (e) => FormBuilderChipOption<int>(
                  value: e.key,
                  child: Text(
                    e.value.name!.value(),
                  ),
                ),
              )
              .toList(),
          // validator: emptyListValidator,
          onChanged: (c) => controller.updateCategories(c),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        // TODO FIXME: Removed the tag widget for the time being
        // as typing fast has caused some issues. maybe with the async
        // and it needs a debounce instead.
        // const SizedBox(height: 12),
        // ChipsInput(
        //   initialValue: ref.watch(recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
        //       .select((s) => s.value!.tags)),
        //   chipBuilder: (BuildContext context, state, Tag item) {
        //     return InputChip(
        //       key: ObjectKey(item),
        //       label: Text(item.text
        //           .substring(0, item.text.length.clamp(0, MAX_TAG_LENGTH))),
        //       onDeleted: () {
        //         // deletion in state will be caused by the onchanged callback
        //         state.deleteChip(item);
        //       },
        //       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        //     );
        //   },
        //   suggestionBuilder: (context, state, Tag item) {
        //     return ListTile(
        //         key: ObjectKey(item),
        //         title: item.id.isNotEmpty && item.text != " "
        //             ? Text(item.text)
        //             : Text("Create tag '${item.text}'?"),
        //         onTap: () async {
        //           if (item.id.isEmpty) {
        //             // Selected Tag is a new one -> make post request
        //             // TODO: what if tag is created while user makes a request!?
        //             final newTag = await ref.read(apiServiceProvider).createTag(
        //                 jsonEncode(item
        //                     .copyWith(
        //                         text: item.text.substring(0,
        //                             item.text.length.clamp(0, MAX_TAG_LENGTH)))
        //                     .toJson()));
        //             state.selectSuggestion(newTag);
        //           } else {
        //             state.selectSuggestion(item);
        //           }
        //         });
        //   },
        //   findSuggestions: (String query) async {
        //     // final run = controller.debounceTagQuery(() {});
        //     // if (run) return <Tag>[Tag(id: "", text: query)];

        //     if (query.isNotEmpty) {
        //       final ret = await ref
        //           .read(apiServiceProvider)
        //           .getTags(search: query, pageSize: 20);
        //       final contained = ret.where((element) => element.text == query);
        //       if (contained.isEmpty) {
        //         return [Tag(id: "", text: query), ...ret];
        //       }
        //       return ret;
        //     } else {
        //       return <Tag>[Tag(id: "", text: query)];
        //     }
        //   },
        //   onChanged: (List<Tag> tags) {
        //     ref
        //         .read(recipeEditControllerProvider(recipeId, draftId: draftId).notifier)
        //         .updateTags(tags);
        //   },
        //   decoration: const InputDecoration(
        //     labelText: 'Tags',
        //   ),
        // ),
        const SizedBox(height: 20),

        /**
         * Time Information
         */
        const DividerText(
            textStyle: TextStyle(fontWeight: FontWeight.w600), text: "Time"),
        const SizedBox(height: 12),
        TextFormField(
          controller: prepTimeController,
          validator: ((value) => chainValidators(value, [
                emptyValidator,
                ((value) => minValueValidator(value, minValue: 0)),
                ((value) => maxValueValidator(value, maxValue: 32767)),
              ])),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Preparation time *',
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (s) => controller.updatePrepTime(s),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          // max value
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: cookTimeController,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: ((value) => chainValidators(value, [
                emptyValidator,
                ((value) => minValueValidator(value, minValue: 0)),
                ((value) => maxValueValidator(value, maxValue: 32767)),
              ])),
          decoration: const InputDecoration(
            labelText: 'Cook time *',
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (s) => controller.updateCookTime(s),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 30),
        const DividerText(
            textStyle: TextStyle(fontWeight: FontWeight.w600),
            text: "Recipe Source"),
        const SizedBox(height: 12),
        TextFormField(
          controller: sourceNameController,
          decoration: const InputDecoration(
            labelText: 'Source Name',
            hintText: "optional",
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (s) => controller.updateSourceName(s),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: sourcePageController,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: ((value) => chainValidators(value, [
                ((value) => minValueValidator(value, minValue: 0)),
                ((value) => maxValueValidator(value, maxValue: 32767)),
              ])),
          decoration: const InputDecoration(
            labelText: 'Source Page',
            hintText: "optional",
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (s) => controller.updateSourcePage(s),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: sourceUrlController,
          validator: urlValidator,
          decoration: const InputDecoration(
            labelText: 'Source Url',
            hintText: "optional",
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (s) => controller.updateSourceUrl(s),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          inputFormatters: [
            LengthLimitingTextInputFormatter(255),
          ],
        ),
      ],
    );
  }
}
