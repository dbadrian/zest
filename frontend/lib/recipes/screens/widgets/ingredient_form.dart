import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:substring_highlight/substring_highlight.dart';
import 'package:zest/recipes/controller/edit_controller.dart';
import 'package:zest/recipes/screens/recipe_edit.dart';
import 'package:zest/settings/settings_provider.dart';
import 'package:zest/ui/widgets/debounced_autocomplete.dart';
import 'package:zest/ui/widgets/generics.dart';

import '../../../api/api_service.dart';
import '../../../config/constants.dart';
import '../../../routing/app_router.dart';
import '../../../utils/form_validators.dart';
import '../../models/models.dart';

// ignore: constant_identifier_names
const String FOOD_DOES_NOT_EXIST_TOKEN = "<FOOD_DOES_NOT_EXIST_TOKEN>";
// ignore: constant_identifier_names
const String END_OF_LIST_TOKEN = "<END_OF_LIST_TOKEN>";

typedef OnIngredientUpdate = void Function({
  String? amount,
  String? amountMax,
  String? details,
  String? food,
  String? unit,
  Unit? selectedUnit,
  Food? selectedFood,
});

class IngredientForm extends StatelessWidget {
  const IngredientForm({
    super.key,
    required this.controllers,
    required this.onUpdate,
    this.onDelete,
    this.focusNodeMinAmount,
    this.language,
  });
  final IngredientTextControllers controllers;
  // final ScrollController scrollController;
  final OnIngredientUpdate onUpdate;
  final void Function()? onDelete;
  final FocusNode? focusNodeMinAmount;
  final String? language;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth > 600) {
          return _buildWide();
        } else {
          return _buildNarrow();
        }
      },
    );
  }

  Widget _buildNarrow() {
    // TODO: FIXME: We should re-introduce a version that allows better editing
    // capatbilities on smartphones or small tablets
    return _buildWide();
  }

  Widget _buildWide() {
    return Column(
      // crossAxisAlignment: CrossAxisAlignment.stretch,
      crossAxisAlignment: CrossAxisAlignment.start,
      // mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          direction: Axis.horizontal,
          alignment: WrapAlignment.start,
          children: [
            SizedBox(
              width: 200,
              child: AmountSelectionField(
                amountController: controllers.amount,
                amountMaxController: controllers.amountMax,
                onUpdate: onUpdate,
                focusNodeMinAmount: focusNodeMinAmount,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 150, maxWidth: 180),
              child: UnitSelectionField(
                unitController: controllers.unit,
                selectedUnit: controllers.selectedUnit,
                onUpdate: onUpdate,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 350),
              child: FoodSelectionField(
                foodController: controllers.food,
                selectedFood: controllers.selectedFood,
                onUpdate: onUpdate,
                language: language,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 1000),
              child: TextFormField(
                controller: controllers.details,
                decoration: const InputDecoration(
                    labelText: 'Details',
                    hintText: "optional",
                    floatingLabelBehavior: FloatingLabelBehavior.always
                    // border: OutlineInputBorder(),
                    ),
                maxLines: null,
                onChanged: (value) => onUpdate(details: value),
              ),
            )
          ],
        ),
      ],
    );
  }
}

/// Simple form widget that only allows digits as input
class DecimalNumberFormField extends StatelessWidget {
  const DecimalNumberFormField({
    super.key,
    this.controller,
    this.decoration,
    this.validator,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
  });

  final TextEditingController? controller;
  final InputDecoration? decoration;
  final FormFieldValidator<String>? validator;
  final Function(String)? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      focusNode: focusNode,
      controller: controller,
      decoration: decoration,
      validator: validator,
      autovalidateMode: autovalidateMode,
      // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
      ],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      // inputFormatters: [
      //   FilteringTextInputFormatter.deny(RegExp('[\\,\\-|\\ ]'))
      // ],
    );
  }
}

class AmountSelectionField extends StatelessWidget {
  const AmountSelectionField({
    super.key,
    required this.amountController,
    required this.amountMaxController,
    required this.onUpdate,
    this.focusNodeMinAmount,
  });

  final TextEditingController? amountController;
  final TextEditingController? amountMaxController;
  final OnIngredientUpdate onUpdate;
  final FocusNode? focusNodeMinAmount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: DecimalNumberFormField(
          focusNode: focusNodeMinAmount,
          controller: amountController,
          validator: ((value) {
            return chainValidators(value, [
              emptyValidator,
              // fractionalValidator,
              ((p0) => maxValueValidator(p0, maxValue: 32767)),
            ]);
          }),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            // label: RequiredTextField(
            //   text: "Min. Amount",
            // ),
            labelText: "Min. Amount *",
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: (p0) => onUpdate(amount: p0),
        )),
        const SizedBox(
          width: 5,
        ),
        const Text(" - "),
        const SizedBox(
          width: 5,
        ),
        Expanded(
          child: DecimalNumberFormField(
            controller: amountMaxController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: ((value) {
              if (value == null || value.isEmpty) return null;
              return chainValidators(value, [
                // fractionalValidator,
                ((p0) => minValueValidator(p0,
                    minValue: double.tryParse(amountController!.text) ?? 0)),
                ((p0) => maxValueValidator(p0, maxValue: 32767)),
              ]);
            }),
            // ((value) {
            //   // this field can be empty!
            //   if (value == null || value.isEmpty) return null;

            //   final fractional = fractionalValidator(value);
            //   if (fractional != null) return fractional;

            //   final minValue = double.tryParse(amountController!.text);
            //   if (minValue != null) {
            //     final minValueState = minValueValidator(value,
            //         minValue: minValue,
            //         customError: "Should be larger than $minValue");
            //     if (minValueState != null) return minValueState;
            //   }
            //   return null;
            // }),
            decoration: const InputDecoration(
              label: Text(
                "Max. Amount",
              ),
              hintText: "optional",
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            onChanged: (p0) => onUpdate(amountMax: p0),
          ),
        ),
      ],
    );
  }
}

class RequiredTextField extends StatelessWidget {
  const RequiredTextField(
      {super.key, required this.text, this.style, this.children});

  final String text;
  final TextStyle? style;
  final List<InlineSpan>? children;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: style,
        children: [
          ...?children,
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}

class UnitSelectionField extends ConsumerStatefulWidget {
  const UnitSelectionField({
    super.key,
    required this.unitController,
    required this.selectedUnit,
    required this.onUpdate,
  });

  final TextEditingController unitController;
  final OnIngredientUpdate onUpdate;
  final Unit? selectedUnit;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _UnitSelectionFieldState();
}

class _UnitSelectionFieldState extends ConsumerState<UnitSelectionField> {
  Unit? selectedUnit_;
  String currentQuery_ = "";
  final node = FocusNode(debugLabel: "UnitSelectionTextField");

  @override
  void initState() {
    super.initState();
    selectedUnit_ = widget.selectedUnit;
  }

  @override
  Widget build(BuildContext context) {
    selectedUnit_ = widget.selectedUnit;
    return SafeArea(
      child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
        return AsyncAutocomplete<Unit>(
          node: node,
          validator: (p0) {
            return (selectedUnit_ == null ? "Select a unit" : null) ??
                emptyValidator(p0);
          },
          textController: widget.unitController,
          decorationField: InputDecoration(
            contentPadding:
                Theme.of(context).inputDecorationTheme.contentPadding,
            isDense: Theme.of(context).inputDecorationTheme.isDense,
            prefixIcon: const Icon(Icons.search),
            prefixIconConstraints:
                const BoxConstraints(maxHeight: 48, minWidth: 30),
            labelText: 'Select Unit *',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            enabledBorder: (selectedUnit_ == null)
                ? const OutlineInputBorder(
                    // stlye border red if the field is not valid
                    borderSide: BorderSide(color: Colors.red),
                  )
                : null,
            focusedBorder: (selectedUnit_ == null)
                ? const OutlineInputBorder(
                    // stlye border red if the field is not valid
                    borderSide: BorderSide(color: Colors.red),
                  )
                : null,
          ),
          initialValue: TextEditingValue(text: widget.unitController.text),
          displayStringForOption: (p0) => p0.name.value(),
          onChanged: (p0) {
            debugPrint("[onChanged] Selected unit: ${p0} // $selectedUnit_");
            widget.onUpdate(unit: p0, selectedUnit: selectedUnit_);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 50,
                  height: 230,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final unit = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(unit);
                        },
                        child: Builder(builder: (BuildContext context) {
                          final bool highlight =
                              AutocompleteHighlightedOption.of(context) ==
                                  index;
                          if (highlight) {
                            SchedulerBinding.instance.addPostFrameCallback(
                                (Duration timeStamp) {
                              // TODO: Currently broken on Flutter  3.20 > and higher
                              // fix apparently merged but not upstream...fucking yuck

                              // Scrollable.ensureVisible(context, alignment: 0.4);
                            }, debugLabel: 'AutocompleteOptions.ensureVisible');
                          }

                          return ListTile(
                            tileColor: highlight
                                ? Theme.of(context).focusColor.withOpacity(0.1)
                                : null,
                            title: SubstringHighlight(
                              text:
                                  "${unit.name.value()} ${(unit.unitSystem != null ? "(${unit.unitSystem})" : "")}",
                              term: currentQuery_,
                              textStyleHighlight: const TextStyle(
                                // highlight style
                                color: Colors
                                    .red, // FIXME: use highlight color of theme?
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            dense: true,
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          search: (String pattern) async {
            // if (pattern.isEmpty) return [];
            currentQuery_ = pattern;

            if (selectedUnit_ != null &&
                pattern.toLowerCase() !=
                    selectedUnit_?.name.value().toLowerCase()) {
              selectedUnit_ = null;
              //important: we need to supply the unit string as well
              widget.onUpdate(selectedUnit: null, unit: pattern);
            }

            //TODO: [MAJOR] Handle timeouts etc as in food
            try {
              final units = await ref
                  .read(apiServiceProvider)
                  .getUnits(search: pattern, pageSize: 100);
              return units;
            } catch (err) {
              handleDefaultAsyncError(err, onConfirmTimeout: () {
                // TODO: Is there another way to ensure the field doesnt go
                // into a loop of re-requesting the data and causing the same
                // exception again and again
                FocusScope.of(context).previousFocus();
                // widget.suggestionBoxController.close();
              });
              return [];
            }
          },
          onSelected: (Unit? suggestion) async {
            final unit = suggestion!;
            widget.onUpdate(unit: unit.name.value(), selectedUnit: unit);
            // setState(() => );
            selectedUnit_ = unit;
            node.requestFocus();
          },
        );
      }),
    );
  }
}

class FoodSelectionField extends ConsumerStatefulWidget {
  const FoodSelectionField({
    super.key,
    required this.foodController,
    required this.selectedFood,
    required this.onUpdate,
    this.language,
  });

  final TextEditingController foodController;
  final Food? selectedFood;
  final OnIngredientUpdate onUpdate;
  final String? language;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _FoodSelectionFieldState();
}

class _FoodSelectionFieldState extends ConsumerState<FoodSelectionField> {
  Food? selectedFood_;
  String? currentQuery_;
  GlobalKey key = GlobalKey(); // declare a global key
  final node = FocusNode(debugLabel: "FoodSelectionTextField");

  @override
  void initState() {
    super.initState();
    selectedFood_ = widget.selectedFood;
  }

  @override
  Widget build(BuildContext context) {
    selectedFood_ = widget.selectedFood;
    return SafeArea(
      child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
        return AsyncAutocomplete<Food>(
          node: node,
          textController: widget.foodController,
          validator: (p0) {
            return (selectedFood_ == null ? "Select a food" : null) ??
                emptyValidator(p0);
          },
          decorationField: InputDecoration(
            contentPadding:
                Theme.of(context).inputDecorationTheme.contentPadding,
            isDense: Theme.of(context).inputDecorationTheme.isDense,
            prefixIcon: const Icon(Icons.search),
            // prefixIconConstraints:
            //     const BoxConstraints(maxHeight: 30, minWidth: 30),
            labelText: 'Select Food *',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            enabledBorder: (selectedFood_ == null)
                ? const OutlineInputBorder(
                    // stlye border red if the field is not valid
                    borderSide: BorderSide(color: Colors.red),
                  )
                : null,
            focusedBorder: (selectedFood_ == null)
                ? const OutlineInputBorder(
                    // stlye border red if the field is not valid
                    borderSide: BorderSide(color: Colors.red),
                  )
                : null,
          ),
          initialValue: TextEditingValue(text: widget.foodController.text),
          displayStringForOption: (p0) => p0.name.value(),
          onChanged: (p0) {
            debugPrint("[onChanged] Selected food: ${p0} // $selectedFood_");
            widget.onUpdate(food: p0, selectedFood: selectedFood_);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 50,
                  height: 230,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Builder(builder: (BuildContext context) {
                          final bool highlight =
                              AutocompleteHighlightedOption.of(context) ==
                                  index;
                          if (highlight) {
                            SchedulerBinding.instance.addPostFrameCallback(
                                (Duration timeStamp) {
                              // TODO: Currently broken on Flutter  3.20 > and higher
                              // fix apparently merged but not upstream...fucking yuck
                              // Scrollable.ensureVisible(context, alignment: 1.8);
                            }, debugLabel: 'AutocompleteOptions.ensureVisible');
                          }

                          // In case the result list is maxing out the page size,
                          // we expect to find this token
                          if (option.id == END_OF_LIST_TOKEN) {
                            return const ListTile(
                              title: Text("Type to see more results..."),
                            );
                          }

                          // If the search string doesnt match any item in the result list
                          // we create this time
                          if (option.id == FOOD_DOES_NOT_EXIST_TOKEN) {
                            return FoodCreationTile(
                              initialValue: currentQuery_!,
                              highlight: highlight,
                              foodController: widget.foodController,
                              // suggestionBoxController:
                              //     widget.suggestionBoxController,
                              onSuccess: (Food? food) {
                                if (food != null) {
                                  setState(() => selectedFood_ = food);
                                  widget.onUpdate(
                                      food: food.name.value(),
                                      selectedFood: food);
                                }
                                SchedulerBinding.instance.addPostFrameCallback(
                                    (Duration timeStamp) {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                },
                                    debugLabel:
                                        'AutocompleteOptions.collapseThatShit');
                              },
                            );
                          }

                          // by default we create a tile with the value :)
                          // String subtitle = "";
                          String subtitle = "";
                          if (option.description != null) {
                            // subtitle.add(ption.description!.value()));
                            subtitle += option.description!.value();
                          }
                          if (option.synonyms.isNotEmpty) {
                            if (subtitle.isNotEmpty) {
                              subtitle += "\n";
                            }
                            subtitle += option.synonyms
                                .map((e) => e.name)
                                .toList()
                                .join(", ");
                          }

                          return ListTile(
                            tileColor: highlight
                                ? Theme.of(context).focusColor.withOpacity(0.1)
                                : null,
                            isThreeLine: option.description != null &&
                                option.synonyms.isNotEmpty,
                            title: SubstringHighlight(
                              text: option.name.value(),
                              term: currentQuery_,
                              textStyleHighlight: const TextStyle(
                                // highlight style
                                color: Colors
                                    .red, // FIXME: use highlight color of theme?
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: SubstringHighlight(
                              text: subtitle,
                              term: currentQuery_,
                              textStyleHighlight: const TextStyle(
                                // highlight style
                                color: Colors
                                    .red, // FIXME: use highlight color of theme?
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // RichText(
                            //   text: TextSpan(children: subtitle),
                            // ),
                            dense: true,
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          search: (String pattern) async {
            debugPrint("Searching for food with pattern: $pattern");
            currentQuery_ = pattern;
            if (selectedFood_ != null &&
                pattern.toLowerCase() !=
                    selectedFood_?.name.value().toLowerCase()) {
              debugPrint(
                  "Selected food was: ${selectedFood_?.name}, changing to null");

              selectedFood_ = null;
              // important: we need to supply the food string as well
              // or else the food item wont be updated
              widget.onUpdate(selectedFood: null, food: pattern);
            }
            final foods = await ref.read(apiServiceProvider).getFoods(
                search: pattern,
                pageSize: INGREDIENT_SEARCH_PAGE_SIZE,
                language: widget.language);

            final foodSynonyms = await ref
                .read(apiServiceProvider)
                .getFoodSynonyms(
                    search: pattern, pageSize: INGREDIENT_SEARCH_PAGE_SIZE);

            // 1. foodsBySynonyms: get all foods referenced the synonyms but not in foods yet
            // 2. merge foods + foodsBySynonyms
            // 3. annotate food-synonyms by synonyms and potentially update the score
            final bestFoods = <String, Food>{for (final f in foods) f.id: f};

            final missingFoods = foodSynonyms
                .where((element) => !bestFoods.containsKey(element.food))
                .map((e) => e.food)
                .toList();

            // get the new result list
            final foodsBySynonym = await ref.read(apiServiceProvider).getFoods(
                pageSize: INGREDIENT_SEARCH_PAGE_SIZE, pks: missingFoods);

            // merge
            for (final f in foodsBySynonym) {
              bestFoods[f.id] = f;
            }

            // annotate
            for (final synonym in foodSynonyms) {
              // print(synonym);
              // print(bestFoods[synonym.food]);
              bestFoods.update(
                synonym.food,
                (v) => v.copyWith(
                    similarity: min(synonym.similarity!, v.similarity!),
                    synonyms: [...v.synonyms, synonym]),
              );
            }

            // make a list and sort again by similarity...
            final foodsSorted = bestFoods.entries.map((e) => e.value).toList();
            foodsSorted
                .sort(((a, b) => a.similarity!.compareTo(b.similarity!)));

            // Add a dummy token to mark the end of the list
            return [
              if (pattern.isNotEmpty)
                // TODO: Check if token actually has no "perfect" match
                if (!foodsSorted
                    .map(
                      (e) => e.name.value(),
                    )
                    .map(
                      (e) => e.toLowerCase(),
                    )
                    .any(
                      (e) => e == pattern.toLowerCase(),
                    ))
                  Food(
                      id: FOOD_DOES_NOT_EXIST_TOKEN,
                      name: TranslatedField(values: [])),
              ...foodsSorted,
              if (bestFoods.length == INGREDIENT_SEARCH_PAGE_SIZE)
                Food(id: END_OF_LIST_TOKEN, name: TranslatedField(values: [])),
            ];
          },
          onSelected: (Food? suggestion) async {
            final food = suggestion!;
            widget.onUpdate(food: food.name.value(), selectedFood: food);
            debugPrint("[onSelected] food: ${suggestion}");
            selectedFood_ = food;
            node.requestFocus();
          },
        );
      }),
    );
  }

  foodCreationDialog(
      {required String initialLanguage,
      required initialValue,
      required Future<Food?> Function() onSubmit}) {}
}

class FoodCreationTile extends ConsumerWidget {
  const FoodCreationTile({
    super.key,
    required this.foodController,
    // required this.suggestionBoxController,
    required this.onSuccess,
    required this.highlight,
    required this.initialValue,
  });

  final TextEditingController foodController;
  // final SuggestionsBoxController suggestionBoxController;
  final void Function(Food?) onSuccess;
  final bool highlight;
  final String initialValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // foodController.text = initialValue;
    return ListTile(
      dense: true,
      tileColor:
          highlight ? Theme.of(context).focusColor.withOpacity(0.1) : null,
      title: Text("Add food '${foodController.text}'"),
      onTap: () async {
        final currentLanguage =
            ref.watch(settingsProvider.select((s) => s.current.language));
        foodCreationDialog(
                initialLanguage: currentLanguage,
                initialValue: foodController.text,
                // TODO: Submit to backend!
                onSubmit: ref
                    .watch(FoodCreationControllerProvider(
                            initialLanguage: currentLanguage,
                            initialValue: foodController.text)
                        .notifier)
                    .submit)
            .then((food) {
          onSuccess(food);
        });
        // suggestionBoxController.close();
      },
    );
  }

  Future<Food?> foodCreationDialog(
      {required String initialLanguage,
      String initialValue = "",
      required Future<Food?> Function() onSubmit}) {
    return showDialog<Food?>(
      context: shellNavigatorKey.currentState!.overlay!.context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Food Creation'),
          content: FoodCreationFields(
              initialLanguage: initialLanguage, initialValue: initialValue),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text("Submit"),
              onPressed: () async {
                final food = onSubmit();
                food.then((value) {
                  // TODO Use stateful builder as in reauthentication dialog to
                  // correctly handle errors (e.g. timeout)
                  if (value != null) {
                    Navigator.of(context).pop(value);
                  }
                });
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceEvenly,
        );
      },
    );
  }
}

class FoodCreationFields extends ConsumerStatefulWidget {
  const FoodCreationFields({
    super.key,
    required this.initialLanguage,
    this.initialValue = "",
  });
  final String initialLanguage;
  final String initialValue;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _FoodCreationFieldsState();
}

class _FoodCreationFieldsState extends ConsumerState<FoodCreationFields> {
  // The various supported languages for which the user can insert text
  late final Map<String, TextEditingController> langFields;
  // Nutritional Values
  final kcalController = TextEditingController();
  final totalFatController = TextEditingController();
  final saturatedFatController = TextEditingController();
  final polyunsaturatedFatController = TextEditingController();
  final monounsaturatedFatController = TextEditingController();
  final cholestoralController = TextEditingController();
  final sodiumController = TextEditingController();
  final totalCarbohydratesController = TextEditingController();
  final carbohydrateDietaryFiberController = TextEditingController();
  final carbohydrateSugarController = TextEditingController();
  final proteinController = TextEditingController();
  final lactoseController = TextEditingController();
  final fructoseController = TextEditingController();
  final glucoseController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(FoodCreationControllerProvider(
        initialLanguage: widget.initialLanguage,
        initialValue: widget.initialValue));

    final notifier = ref.read(FoodCreationControllerProvider(
            initialLanguage: widget.initialLanguage,
            initialValue: widget.initialValue)
        .notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in state.langFields.entries) ...[
          TextFormField(
            // controller: e.value,
            initialValue: e.value,
            decoration: InputDecoration(
              labelText: AVAILABLE_LANGUAGES[e.key]!,
              // prefix: Padding(
              //   padding: const EdgeInsets.only(right: 10.0),
              //   child: Text(AVAILABLE_LANGUAGES[e.key]!),
              // ),
            ),
            onChanged: ((value) =>
                notifier.updateLangFields(MapEntry(e.key, value))),
          ),
          const ElementsVerticalSpace()
        ]
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    langFields = {
      widget.initialLanguage: TextEditingController(text: widget.initialValue),
    };
    final otherLangs = AVAILABLE_LANGUAGES.map((key, value) => MapEntry(
          key,
          TextEditingController(),
        ));
    otherLangs.remove(widget.initialLanguage);
    // now the initial lang is at the top
    langFields.addAll(otherLangs);
  }

  @override
  void dispose() {
    super.dispose();

    for (final entry in langFields.values) {
      entry.dispose();
    }

    kcalController.dispose();
    totalFatController.dispose();
    saturatedFatController.dispose();
    polyunsaturatedFatController.dispose();
    monounsaturatedFatController.dispose();
    cholestoralController.dispose();
    sodiumController.dispose();
    totalCarbohydratesController.dispose();
    carbohydrateDietaryFiberController.dispose();
    carbohydrateSugarController.dispose();
    proteinController.dispose();
    lactoseController.dispose();
    fructoseController.dispose();
    glucoseController.dispose();
  }
}

class IngredientGroups extends ConsumerWidget {
  const IngredientGroups({super.key, this.recipeId, this.draftId});

  final String? recipeId;
  final int? draftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientGroups = ref.watch(
        recipeEditControllerProvider(recipeId, draftId: draftId)
            .select((r) => r.value!.ingredientGroups));
    final controller = ref.read(
        recipeEditControllerProvider(recipeId, draftId: draftId).notifier);

    return Column(children: [
      ReorderableListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        buildDefaultDragHandles: false, // disable due to desktop/web
        padding: const EdgeInsets.symmetric(horizontal: 10),
        // proxyDecorator: proxyDecorator,
        children: [
          ...ingredientGroups.asMap().entries.map((e) {
            return Row(
              key: Key(e.key.toString()),
              children: <Widget>[
                Expanded(
                    child: NamedIngredientGroup(
                  key: Key(e.key.toString()),
                  groupId: e.key,
                  recipeId: recipeId,
                  draftId: draftId,
                )),
                if (ingredientGroups.length > 1)
                  ReorderableDragStartListener(
                    index: e.key,
                    child: const Icon(Icons.drag_handle_rounded),
                  ),
              ],
            );
          })
        ],
        onReorder: (oldIndex, newIndex) {
          controller.moveIngredientGroup(oldIndex, newIndex);
        },
      ),
      TextButton(
        onPressed: () => controller.addIngredientGroup(),
        child: const Text('Add Ingredient Group'),
      ),
    ]);
  }
}

class IngredientTextControllers {
  IngredientTextControllers({
    String? amount,
    String? amountMax,
    String? food,
    String? unit,
    String? details,
    this.selectedUnit,
    this.selectedFood,
  })  : amount = TextEditingController(text: amount ?? ""),
        amountMax = TextEditingController(text: amountMax ?? ""),
        food = TextEditingController(text: food ?? ""),
        unit = TextEditingController(text: unit ?? ""),
        details = TextEditingController(text: details ?? "");

  TextEditingController amount;
  TextEditingController amountMax;
  TextEditingController food;
  TextEditingController unit;
  TextEditingController details;
  Unit? selectedUnit;
  Food? selectedFood;

  void dispose() {
    // amount.dispose();
    // amountMax.dispose();
    // food.dispose();
    // unit.dispose();
    // details.dispose();
  }
}

class NamedIngredientGroup extends ConsumerStatefulWidget {
  const NamedIngredientGroup({
    super.key,
    required this.recipeId,
    required this.draftId,
    required this.groupId,
  });

  final int groupId;
  final String? recipeId;
  final int? draftId;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _NamedIngredientGroupState();
}

class _NamedIngredientGroupState extends ConsumerState<NamedIngredientGroup> {
  var name = TextEditingController();
  final List<IngredientTextControllers> ctrls = [];
  final List<FocusNode> focusNodes = [];

  late final RecipeEditController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = ref.read(
        recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
            .notifier);
  }

  @override
  void dispose() {
    flushIngredientControllers();
    name.dispose();
    super.dispose();
  }

  void flushIngredientControllers() {
    ctrls.map((e) => e.dispose());
    ctrls.clear();
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
    final groups = ref.watch(
        recipeEditControllerProvider(widget.recipeId, draftId: widget.draftId)
            .select((value) => value.value!.ingredientGroups));

    if (widget.groupId >= groups.length) {
      return Container();
    }

    final group = groups[widget.groupId];
    // name = TextEditingController(text: group.name);/*  */
    name = updateTextController(name, group.name);

    // update the ingredients itself

    // if (ctrls.length > 0) {
    //   final detailsSelection =
    //       calculateTextSelection(ctrls[0].details, "asdsadsadsa");
    //   print(detailsSelection);
    // }

    final ctrlsBack = [...ctrls];
    flushIngredientControllers();
    group.ingredients.asMap().entries.forEach((e) {
      final ing = e.value;

      var amountSelection = TextSelection.fromPosition(TextPosition(
          offset: min(
              ctrlsBack.elementAtOrNull(e.key)?.amount.selection.baseOffset ??
                  0,
              ing.amountMin.length)));
      var amountMaxSelection = TextSelection.fromPosition(TextPosition(
          offset: min(
              ctrlsBack
                      .elementAtOrNull(e.key)
                      ?.amountMax
                      .selection
                      .baseOffset ??
                  0,
              ing.amountMax.length)));
      var unitSelection = TextSelection.fromPosition(TextPosition(
          offset: min(
              ctrlsBack.elementAtOrNull(e.key)?.unit.selection.baseOffset ?? 0,
              ing.unit.length)));
      var foodSelection = TextSelection.fromPosition(TextPosition(
          offset: min(
              ctrlsBack.elementAtOrNull(e.key)?.food.selection.baseOffset ?? 0,
              ing.food.length)));
      var detailsSelection = TextSelection.fromPosition(TextPosition(
          offset: min(
              ctrlsBack.elementAtOrNull(e.key)?.details.selection.baseOffset ??
                  0,
              ing.details.length)));

      // print(ing.food);
      // print(ctrlsBack.elementAtOrNull(e.key)?.food.text ?? "");
      // print(ing.selectedFood);
      ctrls.add(
        IngredientTextControllers(
            amount: ing.amountMin,
            amountMax: ing.amountMax,
            food: ing.food,
            // selectedFood: (ing.food ==
            //         (ctrlsBack.elementAtOrNull(e.key)?.food.text ?? ""))
            //     ? ing.selectedFood
            //     : null,
            selectedFood: ing.selectedFood,
            unit: ing.unit,
            selectedUnit: ing.selectedUnit,
            // selectedUnit: (ing.unit ==
            //         (ctrlsBack.elementAtOrNull(e.key)?.unit.text ?? ""))
            //     ? ing.selectedUnit
            //     : null,
            details: ing.details),
      );

      ctrls[e.key].amount.selection = amountSelection;
      ctrls[e.key].amountMax.selection = amountMaxSelection;
      ctrls[e.key].food.selection = foodSelection;
      ctrls[e.key].unit.selection = unitSelection;
      ctrls[e.key].details.selection = detailsSelection;

      // ctrls[e.key].food.addListener(() {
      //   final ing = ref.read(recipeEditControllerProvider(widget.recipeId,
      //           draftId: widget.draftId)
      //       .select((s) =>
      //           s.value!.ingredientGroups[widget.groupId].ingredients[e.key]));
      //   final update = ing.copyWith(food: ctrls[e.key].food.text);
      //   ctrl.updateIngredient(widget.groupId, e.key, update);
      // });

      if (focusNodes.length <= e.key) {
        focusNodes.add(FocusNode());
      }
    });

    // if (ctrls.length > group.ingredients.length) {
    //   ctrls.removeRange(group.ingredients.length, ctrls.length);
    // }

    return
        // add keyboard shortcut using CallbackShortcut to add ingredient to current group
        CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
          ctrl.addIngredient(widget.groupId);
          // length is still old as not rebuild eyt
          if (focusNodes.length == group.ingredients.length) {
            focusNodes.add(FocusNode());
          }
          focusNodes[group.ingredients.length].requestFocus();
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
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8)),
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
                  controller: name,
                  validator: emptyValidator,
                  maxLines: null,
                  decoration: const InputDecoration(
                    prefixText: "   ",
                    hintText: "Title of Ingredient Group",
                    border: UnderlineInputBorder(),
                  ),
                  onChanged: (newValue) {
                    ctrl.updateIngredientGroupName(widget.groupId, newValue);
                  }),
              ReorderableListView(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                buildDefaultDragHandles: false, // disable due to desktop/web
                padding: const EdgeInsets.only(left: 10, right: 5),
                // proxyDecorator: proxyDecorator,
                children: <Widget>[
                  ...ctrls.asMap().entries.map((e) {
                    // // ctrls.add(TextEditingController(text: e.value));
                    // final ing = e.value;
                    // ctrls.add(
                    //   IngredientTextControllers(
                    //       amount: ing.amountMin,
                    //       amountMax: ing.amountMax,
                    //       food: ing.food,
                    //       selectedFood: ing.selectedFood,
                    //       unit: ing.unit,
                    //       selectedUnit: ing.selectedUnit,
                    //       details: ing.details),
                    // );
                    // if (focusNodes.length <= e.key) {
                    //   focusNodes.add(FocusNode());
                    // }
                    return Column(
                      key: Key(e.key.toString()),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 10,
                        ),
                        ListTile(
                          title: IngredientForm(
                            focusNodeMinAmount: focusNodes[e.key],
                            controllers: ctrls[e.key],
                            language: ref.watch(recipeEditControllerProvider(
                                    widget.recipeId,
                                    draftId: widget.draftId)
                                .select((value) => value.value!.lang)),
                            // onDelete: (group.ingredients.length > 1)
                            //     ? () =>
                            //         ctrl.deleteIngredient(widget.groupId, e.key)
                            //     : null,
                            onUpdate: ({
                              amount,
                              amountMax,
                              details,
                              food,
                              unit,
                              selectedFood,
                              selectedUnit,
                            }) {
                              final args = {
                                if (amount != null) #amountMin: amount,
                                if (amountMax != null) #amountMax: amountMax,
                                if (details != null) #details: details,
                                if (food != null) #food: food,
                                if (food != null) #selectedFood: selectedFood,
                                if (unit != null) #unit: unit,
                                if (unit != null) #selectedUnit: selectedUnit,
                              };
                              final ing = ref.read(recipeEditControllerProvider(
                                      widget.recipeId,
                                      draftId: widget.draftId)
                                  .select((s) => s
                                      .value!
                                      .ingredientGroups[widget.groupId]
                                      .ingredients[e.key]));
                              final update =
                                  Function.apply(ing.copyWith.call, null, args);
                              ctrl.updateIngredient(
                                  widget.groupId, e.key, update);
                            },
                          ),
                          trailing: (group.ingredients.length > 1)
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    buildDeleteIconSuffix(
                                      () => ctrl.deleteIngredient(
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
                        const Divider(),
                      ],
                    );
                  }),
                ],
                onReorder: (int oldIndex, int newIndex) {
                  ctrl.moveIngredient(widget.groupId, oldIndex, newIndex);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                      onPressed: (() {
                        ctrl.addIngredient(widget.groupId);
                        // length is still old as not rebuild eyt
                        if (focusNodes.length == group.ingredients.length) {
                          focusNodes.add(FocusNode());
                        }
                        focusNodes[group.ingredients.length].requestFocus();
                      }),
                      child: const Text("Add Ingredient")),
                  TextButton(
                      onPressed: (() =>
                          ctrl.deleteIngredientGroup(widget.groupId)),
                      child: const Text("Delete Group")),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
