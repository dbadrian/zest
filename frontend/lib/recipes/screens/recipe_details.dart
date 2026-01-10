import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:number_inc_dec/number_inc_dec.dart';
import 'package:zest/recipes/controller/search_controller.dart';
import 'package:zest/recipes/screens/recipe_search.dart';

import '../../routing/app_router.dart';
import '../../ui/widgets/generics.dart';
import '../controller/details_controller.dart';
import '../models/models.dart';

class RecipeDetailsPage extends ConsumerWidget {
  static String get routeName => 'recipe';

  const RecipeDetailsPage({super.key, required this.recipeId});
  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.read(recipeDetailsControllerProvider(recipeId));
    // ignore: no_leading_underscores_for_local_identifiers
    final _recipeId =
        ref.watch(recipeDetailsControllerProvider(recipeId).select(
      (value) {
        if (value.hasError || value.isLoading) {
          return value;
        } else {
          return AsyncValue.data(value.value?.id);
        }
      },
    ));
    // map all its states to widgets and return the result
    if (_recipeId.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recipeId.hasError) {
      return Text(
        _recipeId.error.toString(),
      );
    }
    if (state.value == null) {
      // TODO : handle this better
      return Center(
        child: Row(
          children: [
            ElevatedButton(
              onPressed: () =>
                  shellNavigatorKey.currentState!.overlay!.context.pop(),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () => ref
                  .read(recipeDetailsControllerProvider(recipeId).notifier)
                  .loadRecipe(),
              child: const Text("Reload"),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth > 650) {
          return RecipeDetailsWideWidget(recipeId: recipeId);
        } else {
          return RecipeDetailsNarrowWidget(recipeId: recipeId);
        }
      },
    );
  }
}

class RecipeDetailsWideWidget extends ConsumerWidget {
  const RecipeDetailsWideWidget({super.key, required this.recipeId});

  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        TitleWidget(key: Key("RecipeTitleWidget"), recipeId: recipeId),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                // color: Colors.blue,
                padding: const EdgeInsets.all(10),
                child: ListView(
                  // shrinkWrap: true,
                  scrollDirection: Axis.vertical,
                  children: [
                    const SizedBox(height: 10),
                    RecipeMetaInfoColumn(
                      recipeId: recipeId,
                    ),
                    // const SizedBox(height: 10),
                    const Divider(),
                    IngredientsColumn(
                      recipeId: recipeId,
                    ),
                  ],
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: InstructionColumn(
                  recipeId: recipeId,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class RecipeDetailsNarrowWidget extends ConsumerWidget {
  const RecipeDetailsNarrowWidget({super.key, required this.recipeId});

  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TitleWidget(recipeId: recipeId),
          const TabBar(
            labelColor: Colors.black,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                // icon: Icon(Icons.directions_car),
                text: "General",
              ),
              Tab(
                // icon: Icon(Icons.directions_car),
                text: "Ingredients",
              ),
              Tab(
                // icon: Icon(Icons.directions_transit),
                text: "Instructions",
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  // Use PageStorageKey to "remember" scroll position when switching tabs
                  key: const PageStorageKey<String>('meta_info'),
                  children: [
                    const SizedBox(height: 10),
                    RecipeMetaInfoColumn(
                      recipeId: recipeId,
                    ),
                    const SizedBox(height: 10),
                  ],
                  // ),
                ),
                ListView(
                  // Use PageStorageKey to "remember" scroll position when switching tabs
                  key: const PageStorageKey<String>('ingredients_groups'),
                  children: [
                    const SizedBox(height: 10),
                    IngredientsColumn(
                      recipeId: recipeId,
                    ),
                    const SizedBox(height: 20),
                  ],
                  // ),
                ),
                InstructionColumn(
                  recipeId: recipeId,
                ),
                // ListView(
                //   // Use PageStorageKey to "remember" scroll position when switching tabs
                //   key: const PageStorageKey<String>('instructions_groups'),
                //   shrinkWrap: false,
                //   // physics: const ClampingScrollPhysics(),
                //   children: buildInstructionColumn(
                //       controller.recipe.value.instructionGroups),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TagWidget extends StatelessWidget {
  final String text;

  const TagWidget({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      // shape: OutlinedBorder(side: BorderSide(color: Colors.grey)),
      label: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class RecipeMetaInfoColumn extends ConsumerWidget {
  const RecipeMetaInfoColumn({super.key, required this.recipeId});
  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeDetailsControllerProvider(recipeId)).value;

    return Column(
      children: [
        if (recipe!.latestRevision.categories.isNotEmpty) ...[
          Wrap(
            direction: Axis.horizontal,
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: kIsWeb ? 10 : 0,
            children: <Widget>[
                  const ElementsVerticalSpace(),
                ] +
                recipe.latestRevision.categories
                    .map((e) => Chip(
                        // TODO: TagWidget
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        label: Text(
                          e.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                        )))
                    .toList(),
          ),
          const Divider(),
        ],
        if (recipe.latestRevision.ownerComment != null &&
            recipe.latestRevision.ownerComment != "") ...[
          Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
              child: Text("${recipe.latestRevision.ownerComment}")),
          const Divider(),
        ],

        if (recipe.latestRevision.difficulty != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Difficulty: "),
              ...List.generate(
                  recipe.latestRevision.difficulty!,
                  (i) => Icon(
                        Icons.food_bank,
                        color: Theme.of(context).colorScheme.primary,
                      )),
              ...List.generate(
                  5 - recipe.latestRevision.difficulty!,
                  (i) => Icon(
                        Icons.food_bank_outlined,
                        color: Theme.of(context).colorScheme.secondary,
                      )),
            ],
          ),
          const Divider(),
        ],
        if (recipe.latestRevision.prepTime != null ||
            recipe.latestRevision.cookTime != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 0, right: 20),
                child: FaIcon(FontAwesomeIcons.clock,
                    color: Theme.of(context).colorScheme.primary),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      if (recipe.latestRevision.prepTime != null) ...[
                        const Text("Preparation Time: "),
                        Text(recipe.latestRevision.prepTime.toString()),
                      ]
                    ],
                  ),
                  Row(
                    children: [
                      if (recipe.latestRevision.cookTime != null) ...[
                        const Text("      Cooking Time: "),
                        Text(recipe.latestRevision.cookTime.toString()),
                      ]
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],

        if ((recipe.latestRevision.sourceName != null &&
                recipe.latestRevision.sourceName != "") ||
            recipe.latestRevision.sourcePage != null ||
            recipe.latestRevision.sourceUrl != null &&
                recipe.latestRevision.sourceUrl != "") ...[
          if (recipe.latestRevision.sourceName != null &&
              recipe.latestRevision.sourceName != "")
            Text("By: ${recipe.latestRevision.sourceName}"),
          if (recipe.latestRevision.sourcePage != null)
            Text("Page: ${recipe.latestRevision.sourcePage}"),
          if (recipe.latestRevision.sourceUrl != null &&
              recipe.latestRevision.sourceUrl != "")
            TextButton(
                onPressed: () async {
                  final Uri? url =
                      Uri.tryParse(recipe.latestRevision.sourceUrl!);
                  if (url != null && !await launchUrl(url)) {
                    throw Exception('Could not launch $url');
                  }
                },
                child: Text("${recipe.latestRevision.sourceUrl}")),
        ]

        // const Divider(),
        // // Text("Date Update: ${recipe.latestRevision.dateCreated.}"),
        // Text("Date Update: ${DateFormat.yMMMd().format(recipe.dateCreated)}"),

        // Text("Is latest version: ${recipe.isUpToDate}"),
        // Text("Is a translated recipe: ${recipe.isTranslation}"),

        // const Divider(),
        // Row(children: [
        //   (recipe.isFavorite!)
        //       ? const Text("Remove from favorites: ")
        //       : const Text("Add to favorites: "),
        //   (recipe.isFavorite!)
        //       ? IconButton(
        //           onPressed: ref
        //               .read(recipeDetailsControllerProvider(recipeId).notifier)
        //               .deleteFromFavorites,
        //           icon: const Icon(Icons.favorite))
        //       : IconButton(
        //           onPressed: ref
        //               .read(recipeDetailsControllerProvider(recipeId).notifier)
        //               .addToFavorites,
        //           icon: const Icon(Icons.favorite_outline)),
        // ]),
      ],
    );
  }
}

class IngredientsColumn extends HookConsumerWidget {
  const IngredientsColumn({super.key, required this.recipeId});
  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final SettingsState settings = ref.watch(settingsProvider.);
    // final label =
    //     ref.watch(settingsProvider.select((settings) => settings.));
    final notifier =
        ref.read(recipeDetailsControllerProvider(recipeId).notifier);
    final recipe = ref.watch(recipeDetailsControllerProvider(recipeId)).value!;

    final servingsCtrl = useTextEditingController();
    servingsCtrl.text = recipe.latestRevision.servings.toString();

    void onServingsChanges(value) async {
      final oldServingsCount = recipe.latestRevision.servings;
      final bool success =
          await notifier.loadRecipe(servings: value.toString());
      if (!success) {
        // // reset counter to account for the unsuccesful load
        servingsCtrl.text = oldServingsCount.toString();
      }
    }

    // Future<bool> reload() async {
    //   final bool success =
    //       await notifier.loadRecipe(servings: value.toString());
    // }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ElementsVerticalSpace(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (recipe.latestRevision.servings != null) ...[
              SizedBox(
                width: 90.0,
                height: 30.0,
                child: NumberInputWithIncrementDecrement(
                  controller: servingsCtrl,
                  initialValue: recipe.latestRevision.servings!,
                  min: 1,
                  max: 99,
                  onIncrement: onServingsChanges,
                  onDecrement: onServingsChanges,
                  onChanged: onServingsChanges,
                  // incIconSize: 20,
                  // decIconSize: 20,
                  incIconDecoration: const BoxDecoration(),
                  decIconDecoration: const BoxDecoration(),
                  buttonArrangement: ButtonArrangement.incRightDecLeft,
                  numberFieldDecoration: const InputDecoration(
                    contentPadding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    border: OutlineInputBorder(
                        // borderRadius:
                        //     BorderRadius.circular(8.0),
                        ),
                  ),
                  widgetContainerDecoration: const BoxDecoration(
                      // border: Border.all(
                      //     // color: Colors.pink,
                      //     ),
                      ),
                ),
              ),
              const SizedBox(
                width: 5,
              ),
              const SizedBox(
                width: 5,
              ),
              const Text(" servings",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(
                width: 25,
              ),
            ]
            // if (recipe.hasMetricConversion())
            //   TextButton(
            //     style: TextButton.styleFrom(
            //       textStyle: Theme.of(context).textTheme.labelLarge,
            //     ),
            //     onPressed: () async {
            //       notifier.toMetric = !notifier.toMetric;
            //       notifier.loadRecipe(servings: servingsCtrl.text);
            //     },
            //     child: Row(
            //         crossAxisAlignment: CrossAxisAlignment.center,
            //         children: [
            //           IconTheme(
            //             data: IconThemeData(
            //               color: Theme.of(context).colorScheme.primary,
            //               size: 12,
            //             ),
            //             child: const FaIcon(FontAwesomeIcons.rightLeft),
            //           ),
            //           Text(
            //             notifier.toMetric ? " To original units" : " To Metric",
            //           ),
            //         ]),
            //   ),
            // IconButton(
            //     onPressed: () async {
            //       notifier.translateRecipe();
            //     },
            //     icon: FaIcon(FontAwesomeIcons.octopusDeploy)),

            // icon: Icon(Icons.translate)),
          ],
        ),
        IngredientGroupsWidget(
          groups: recipe.latestRevision.ingredientGroups,
          recipeId: recipeId,
        )
      ],
    );
  }
}

// class IngredientWidget extends ConsumerWidget {
//   final Ingredient ingredient;

//   const IngredientWidget(
//       {super.key, required this.ingredient, required this.recipeId});

//   final String recipeId;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final amount = ingredient.getAmount();
//     final unit = ingredient.getUnitAbbreviation(
//         matchLanguage: ref.read(settingsProvider).language);
//     final food = ingredient.food;
//     final details = ingredient.details;

//     // return Row(
//     // crossAxisAlignment: CrossAxisAlignment.start,
//     // return Wrap(
//     //   children: [
//     //     Text("$amount "),
//     //     Tooltip(
//     //       message:
//     //           "${ingredient.unit.name.value()}, ${ingredient.unit.namePlural?.value() ?? "-"} [ ${ingredient.unit.unitSystem ?? "No Unit System"} ]",
//     //       child: Text("$unit "),
//     //     ),
//     //     TranslatableField(
//     //       field: food.name,
//     //       onConfirm: (String value) async {
//     //         final translatedName = TranslatedField(values: [
//     //           TranslatedValue(
//     //               value: value, lang: ref.read(settingsProvider).language)
//     //         ]);
//     //         final translatedFood = food.copyWith(name: translatedName);
//     //         final json = translatedFood.toJson(); // toJsonExplicit();
//     //         final foodJson = jsonEncode(json);
//     //         // TODO: WE dont handle if the food translation already exists...
//     //         final food_ = await ref
//     //             .read(apiServiceProvider)
//     //             .updateFood(translatedFood.id, foodJson);
//     //         if (food_ != null) {
//     //           final notifier =
//     //               ref.read(recipeDetailsControllerProvider(recipeId).notifier);
//     //           notifier.loadRecipe();
//     //         }
//     //       },
//     //     ),
//     //     if (details != null)
//     //       Padding(
//     //         padding: const EdgeInsets.only(left: 20),
//     //         child: Text(
//     //           "... $details",
//     //           style: const TextStyle(fontStyle: FontStyle.italic),
//     //         ),
//     //       ),
//     //   ],
//     // );

//     return TableRow(
//       children: <Widget>[
//         Container(
//           height: 32,
//           color: Colors.green,
//         ),
//         TableCell(
//           verticalAlignment: TableCellVerticalAlignment.top,
//           child: Container(
//             height: 32,
//             width: 32,
//             color: Colors.red,
//           ),
//         ),
//         Container(
//           height: 64,
//           color: Colors.blue,
//         ),
//       ],
//     );
//   }
// }

TableRow buildIngredientRow(WidgetRef ref, Ingredient ingredient, int recipeId,
    bool isMarked, Function() markCallback) {
  final amount =
      "${ingredient.amountMin} ${ingredient.amountMax != null ? " - ${ingredient.amountMax}" : ""}";

  final unit = ingredient.unit.name;
  final food = ingredient.food;
  final details = ingredient.comment;

  final metricOrSystemless = (ingredient.unit.unitSystem == "Metric") ||
      (ingredient.unit.unitSystem.isEmpty) ||
      (ingredient.unit.unitSystem == " ");

  return TableRow(
    children: <Widget>[
      TableCell(
        child: TableRowInkWell(
          onTap: markCallback,
          // verticalAlignment: TableCellVerticalAlignment.top,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              "$amount ",
              style: TextStyle(
                  fontWeight: isMarked ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ),
      ),
      TableRowInkWell(
        onTap: markCallback,
        child: Tooltip(
          message: "${ingredient.unit.name} [ ${ingredient.unit.unitSystem} ]",
          child: Text(
            "$unit ${!metricOrSystemless ? "(${ingredient.unit.unitSystem})" : ""}",
            style: TextStyle(
                fontWeight: isMarked ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
      TableRowInkWell(
        onTap: markCallback,
        child: Wrap(
          children: [
            Text(food),
            details != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(
                      "... $details",
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight:
                              isMarked ? FontWeight.bold : FontWeight.normal),
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    ],
  );
}

// class IngredientGroupWidget extends ConsumerWidget {
//   final IngredientGroup group;

//   const IngredientGroupWidget(
//       {super.key, required this.group, required this.recipeId});

//   final String recipeId;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return
//     Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           margin: const EdgeInsets.only(bottom: 5),
//           child: Text(
//             group.name,
//             style: Theme.of(context).textTheme.titleLarge,
//           ),
//         ),
//         Table(
//           columnWidths: const {
//             0: IntrinsicColumnWidth(),
//             1: IntrinsicColumnWidth(),
//             // 1: FixedColumnWidth(20),
//             2: FlexColumnWidth(1),
//           },
//           children: group.ingredients
//               .map(
//                   (ingredient) => buildIngredientRow(ref, ingredient, recipeId))
//               .toList(),
//         ),
//       ],
//     );
//   }
// }

class IngredientGroupWidget extends ConsumerStatefulWidget {
  const IngredientGroupWidget(
      {super.key, required this.recipeId, required this.group});
  final int recipeId;
  final IngredientGroup group;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _IngredientGroupWidgetState();
}

class _IngredientGroupWidgetState extends ConsumerState<IngredientGroupWidget> {
  // A list of bools, one for each ingredient in the group, initialized to false
  late List<bool> isMarked;

  @override
  void initState() {
    super.initState();
    isMarked = List.filled(widget.group.ingredients.length, false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 5),
          child: Text(
            widget.group.name ?? "", // TODO: if null, remove widget?
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: FlexColumnWidth(1),
          },
          children: widget.group.ingredients
              .asMap()
              .map((i, ingredient) => MapEntry(
                  i,
                  buildIngredientRow(
                      ref,
                      ingredient,
                      widget.recipeId,
                      isMarked[i],
                      () => setState(() {
                            isMarked[i] = !isMarked[i];
                          }))))
              .values
              .toList(),
        ),
      ],
    );
  }
}

class IngredientGroupsWidget extends StatelessWidget {
  final List<IngredientGroup> groups;

  const IngredientGroupsWidget(
      {super.key, required this.groups, required this.recipeId});
  final int recipeId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups
            .map((e) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: IngredientGroupWidget(
                  group: e,
                  recipeId: recipeId,
                )))
            .toList(),
      ),
    );
  }
}

Widget buildInstructionLineWidget(
    BuildContext ctx, int step, String instruction,
    {bool isMarked = false}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "${step.toString().padLeft(2, "  ")} | ",
        style: Theme.of(ctx).textTheme.titleMedium!.copyWith(
              color: Theme.of(ctx).colorScheme.secondary,
              fontWeight: isMarked ? FontWeight.bold : FontWeight.normal,
            ),
      ),
      Expanded(
        child: Text(
          instruction,
          style: TextStyle(
            fontWeight: isMarked ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      )
    ],
  );
}

class InstructionWidget extends StatelessWidget {
  const InstructionWidget(
      {super.key,
      required this.step,
      required this.instruction,
      required this.isMarked,
      required this.markCallback});

  final String instruction;
  final int step;
  final bool isMarked;
  final Function() markCallback;

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: markCallback,
        child: buildInstructionLineWidget(context, step, instruction,
            isMarked: isMarked));
  }
}

class InstructionGroupWidget extends ConsumerStatefulWidget {
  const InstructionGroupWidget({super.key, required this.group});
  final InstructionGroup group;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _InstructionGroupWidgetState();
}

class _InstructionGroupWidgetState
    extends ConsumerState<InstructionGroupWidget> {
  late List<bool> isMarked;

  @override
  void initState() {
    super.initState();
    isMarked = List.filled(widget.group.instructions.length, false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.group.name ?? "", // TODO: if null remove widget
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          ...widget.group.instructions
              .split("\n\n")
              .asMap()
              .entries
              .map((entry) {
            return Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 8),
                child: InstructionWidget(
                    step: entry.key + 1,
                    instruction: entry.value,
                    isMarked: isMarked[entry.key],
                    markCallback: () {
                      setState(() {
                        isMarked[entry.key] = !isMarked[entry.key];
                      });
                    }));
          })
        ],
      ),
    );
  }
}

// class InstructionGroupWidget extends StatelessWidget {
//   final InstructionGroup group;

//   const InstructionGroupWidget({super.key, required this.group});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(left: 5, right: 10),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             group.name,
//             style: Theme.of(context).textTheme.titleLarge!.copyWith(
//                   color: Theme.of(context).colorScheme.primary,
//                 ),
//           ),
//           ...group.instructions.asMap().entries.map((entry) {
//             return Padding(
//                 padding: const EdgeInsets.only(left: 10, bottom: 8),
//                 child: InstructionWidget(
//                     step: entry.key + 1, instruction: entry.value));
//           })
//         ],
//       ),
//     );
//   }
// }

class InstructionColumn extends ConsumerWidget {
  const InstructionColumn({super.key, required this.recipeId});
  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeDetailsControllerProvider(recipeId)).value!;

    return ListView(
      key: const PageStorageKey<String>('instructions_groups'),
      // shrinkWrap: true,
      scrollDirection: Axis.vertical,
      children: recipe.latestRevision.instructionGroups
          .map<Padding>(
            (group) => Padding(
              padding: const EdgeInsets.only(
                top: 10,
              ),
              child: InstructionGroupWidget(group: group),
            ),
          )
          .toList(),
    );
  }
}

class TitleWidget extends ConsumerWidget {
  const TitleWidget({super.key, required this.recipeId});

  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeDetailsControllerProvider(recipeId)).value;

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Flexible(
        child: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: TextButton(
            child: Text(
                recipe!.latestRevision.title ??
                    "", // TODO: if null remove widget
                style: const TextStyle(fontSize: 20)),
            onPressed: () async {
              await ref
                  .read(recipeDetailsControllerProvider(recipeId).notifier)
                  .reloadRecipe();
            },
          ),
        ),
      ),
      // Text(recipe!.title, style: const TextStyle(fontSize: 20)))),
      (recipe.isFavorited)
          ? IconButton(
              onPressed: ref
                  .read(recipeDetailsControllerProvider(recipeId).notifier)
                  .deleteFromFavorites,
              icon: Icon(
                Icons.favorite,
                color: Theme.of(context).colorScheme.primary,
              ))
          : IconButton(
              onPressed: ref
                  .read(recipeDetailsControllerProvider(recipeId).notifier)
                  .addToFavorites,
              icon: const Icon(Icons.favorite_outline)),
      // if (ref
      //     .read(recipeDetailsControllerProvider(recipeId).notifier)
      //     .isEditable)
      //   IconButton(
      //       onPressed: () {
      //         context.goNamed(RecipeEditPage.routeNameEdit,
      //             pathParameters: {'id': recipeId});
      //       },
      //       icon: Icon(
      //         Icons.edit,
      //         color: Theme.of(context).colorScheme.primary,
      //       )),
      if (ref
          .read(recipeDetailsControllerProvider(recipeId).notifier)
          .isDeleteable())
        IconButton(
            onPressed: () async {
              final isDeleted = await ref
                  .read(recipeDetailsControllerProvider(recipeId).notifier)
                  .deleteRecipe();
              if (isDeleted && context.mounted) {
                ref.invalidate(recipeSearchControllerProvider);
                context.goNamed(RecipeSearchPage.routeName);
              }
            },
            icon: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.primary,
            ))
    ]);
  }
}
