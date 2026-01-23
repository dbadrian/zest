import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:number_inc_dec/number_inc_dec.dart';
import 'package:zest/api/api_service.dart';
import 'package:zest/authentication/reauthentication_dialog.dart';
import 'package:zest/core/network/api_exception.dart';
import 'package:zest/recipes/controller/providers.dart';
import 'package:zest/recipes/controller/search_controller.dart';
import 'package:zest/recipes/screens/recipe_edit.dart' hide Ingredient;
import 'package:zest/recipes/screens/recipe_search.dart';
import 'package:zest/utils/networking.dart';

import '../../routing/app_router.dart';
import '../../ui/widgets/generics.dart';
import '../controller/details_controller.dart';
import '../models/models.dart';

class RecipeDetailsPage extends ConsumerStatefulWidget {
  static String get routeName => 'recipe';

  final int recipeId;
  const RecipeDetailsPage({required this.recipeId, super.key});

  @override
  ConsumerState<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends ConsumerState<RecipeDetailsPage> {
  bool dialogOpen = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure to open a reauth dialog if somehow the login expired before loading
    // the state fully.
    ref.listen<AsyncValue<Recipe?>>(
      recipeDetailsControllerProvider(widget.recipeId),
      (previous, next) {
        if (next.hasError && next.error is ApiException && !dialogOpen) {
          final error = next.error as ApiException;

          if (error.isUnauthorized) {
            dialogOpen = true; // mark it so we don’t open again

            // Schedule dialog for **after build** to be extra safe
            WidgetsBinding.instance.addPostFrameCallback((_) {
              openReauthenticationDialog(
                context,
                onConfirm: () {
                  ref.invalidate(
                    recipeDetailsControllerProvider(widget.recipeId),
                  );
                },
              );
            });
          } else if (error.isOffline) {
            openServerNotAvailableDialog(context, onPressed: () {
              context.goNamed(RecipeSearchPage.routeName);
            },
                content:
                    "Server not reachable and recipe not yet in cache. Returning to the search.");
          }
        }
      },
    );

    final state = ref.watch(recipeDetailsControllerProvider(widget.recipeId));

    // map all its states to widgets and return the result
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.hasError) {
      return Container();
    }
    if (state.value == null) {
      // TODO : LOW handle this better
      return Center(
        child: Row(
          children: [
            ElevatedButton(
              onPressed: () =>
                  shellNavigatorKey.currentState!.overlay!.context.pop(),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await ref
                    .read(recipeDetailsControllerProvider(widget.recipeId)
                        .notifier)
                    .loadRecipe();

                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: Couldn't load recipe!")),
                  );
                }
              },
              child: const Text("Reload"),
            ),
          ],
        ),
      );
    }

    dialogOpen = false;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth > 650) {
          return RecipeDetailsWideWidget(recipeId: widget.recipeId);
        } else {
          return RecipeDetailsNarrowWidget(recipeId: widget.recipeId);
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
              Tab(text: "General"),
              Tab(text: "Ingredients"),
              Tab(text: "Instructions"),
            ],
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                // Get the controller safely from DefaultTabController
                final TabController tabController =
                    DefaultTabController.of(context)!;

                return TabBarView(
                  controller: tabController,
                  children: [
                    ListView(
                      key: const PageStorageKey<String>('meta_info'),
                      children: [
                        const SizedBox(height: 10),
                        RecipeMetaInfoColumn(recipeId: recipeId),
                        const SizedBox(height: 10),
                      ],
                    ),
                    ListView(
                      key: const PageStorageKey<String>('ingredients_groups'),
                      children: [
                        const SizedBox(height: 10),
                        IngredientsColumn(recipeId: recipeId),
                        const SizedBox(height: 20),
                      ],
                    ),
                    InstructionColumn(recipeId: recipeId),
                  ],
                );
              },
            ),
          ),
        ],
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
              Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(), // label column adapts to widest label
                  1: FixedColumnWidth(8), // small gap between colon and time
                  2: IntrinsicColumnWidth(), // time column fills remaining space
                },
                children: [
                  if (recipe.latestRevision.prepTime != null)
                    TableRow(children: [
                      const Text("Preparation Time"),
                      const Text(":"), // colon aligned in its own column
                      Text(
                        "${recipe.latestRevision.prepTime! ~/ 60} h ${recipe.latestRevision.prepTime! % 60} m",
                      ),
                    ]),
                  if (recipe.latestRevision.cookTime != null)
                    TableRow(children: [
                      const Text("Cooking Time"),
                      const Text(":"),
                      Text(
                        "${recipe.latestRevision.cookTime! ~/ 60} h ${recipe.latestRevision.cookTime! % 60} m",
                      ),
                    ]),
                  if (recipe.latestRevision.totalTime() != null)
                    TableRow(children: [
                      const Text("Total Time"),
                      const Text(":"),
                      Text(
                        "${recipe.latestRevision.totalTime()! ~/ 60} h ${recipe.latestRevision.totalTime()! % 60} m",
                      ),
                    ]),
                ],
              )
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
      ],
    );
  }
}

// ignore: must_be_immutable // TODO: LOW Should be a stateful widget
class IngredientsColumn extends HookConsumerWidget {
  IngredientsColumn({super.key, required this.recipeId});
  final int recipeId;
  bool toMetric = false;
  bool toSiUnits = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: LOW get default to metric setting

    final staticData = ref.watch(recipeStaticDataProvider);

    final notifier =
        ref.read(recipeDetailsControllerProvider(recipeId).notifier);
    final recipe = ref.watch(recipeDetailsControllerProvider(recipeId)).value!;

    final servingsCtrl = useTextEditingController();

    void onServingsChanges(value) async {
      final oldServingsCount = recipe.latestRevision.servings;
      final bool success = await notifier.loadRecipe(
          servings: value.toString(), toMetric: toMetric);
      if (!success) {
        // // reset counter to account for the unsuccesful load
        servingsCtrl.text = oldServingsCount.toString();
      }
    }

    return staticData.when(
      data: (data) {
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
                      decIcon: Icons.remove_circle_outline,
                      incIcon: Icons.add_circle_outline,
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
                ],
                // if (recipe.hasMetricConversion())
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  onPressed: () async {
                    toMetric = !toMetric;

                    final success = await ref
                        .read(
                            recipeDetailsControllerProvider(recipeId).notifier)
                        .loadRecipe(
                            servings: servingsCtrl.text, toMetric: toMetric);

                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                "Error: Couldn't perform to metric conversion!")),
                      );
                    }
                  },
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconTheme(
                          data: IconThemeData(
                            color: Theme.of(context).colorScheme.primary,
                            size: 12,
                          ),
                          child: const FaIcon(FontAwesomeIcons.rightLeft),
                        ),
                        Text(" Metric"),
                      ]),
                ),
                // TextButton(
                //   style: TextButton.styleFrom(
                //     textStyle: Theme.of(context).textTheme.labelLarge,
                //   ),
                //   onPressed: () async {
                //     toMetric = !toMetric;
                //     notifier.loadRecipe(
                //         servings: servingsCtrl.text, toMetric: toMetric);
                //   },
                //   child:
                //       Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                //     IconTheme(
                //       data: IconThemeData(
                //         color: Theme.of(context).colorScheme.primary,
                //         size: 12,
                //       ),
                //       child: const FaIcon(FontAwesomeIcons.rightLeft),
                //     ),
                //     Text(" SI"),
                //   ]),
                // ),
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
              currentLangData: data.currentLanguageData,
            )
          ],
        );
      },
      error: (error, stackTrace) {
        return Text(
            "An error loading resources occured, try refreshing the window.");
      },
      loading: () {
        return CircularProgressIndicator();
      },
    );
  }
}

TableRow buildIngredientRow(WidgetRef ref, Ingredient ingredient, int recipeId,
    bool isMarked, Function() markCallback) {
  String formatDouble(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  final amountMin = ingredient.amountMin != null
      ? formatDouble(ingredient.amountMin!).toString()
      : "";

  final amountMax = ingredient.amountMax != null
      ? formatDouble(ingredient.amountMax!).toString()
      : "";

  final amount = "$amountMin ${amountMax.isNotEmpty ? " - $amountMax" : ""}";

  final unit = ingredient.unit?.name;
  final food = ingredient.food;
  final details = ingredient.comment;

  final metricOrSystemless = (ingredient.unit == null) ||
      (ingredient.unit!.unitSystem == "Metric") ||
      (ingredient.unit!.unitSystem.isEmpty) ||
      (ingredient.unit!.unitSystem == " ");

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
      if (ingredient.unit != null)
        TableRowInkWell(
          onTap: markCallback,
          child: Tooltip(
            message:
                "${ingredient.unit!.name} [ ${ingredient.unit!.unitSystem} ]",
            child: Text(
              "$unit ${!metricOrSystemless ? "(${ingredient.unit!.unitSystem})" : ""}",
              style: TextStyle(
                  fontWeight: isMarked ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ),
      if (food != null)
        TableRowInkWell(
          onTap: markCallback,
          child: Wrap(
            children: [
              Text(
                food,
                style: TextStyle(
                    fontWeight: isMarked ? FontWeight.bold : FontWeight.normal),
              ),
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
      {super.key,
      required this.recipeId,
      required this.group,
      required this.currentLangData});
  final int recipeId;
  final IngredientGroup group;
  final Map<String, dynamic> currentLangData;

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
            widget.group.name ?? "", // TODO: LOW if null, remove widget?
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
              .map((i, ingr) {
                String? unitTranslationString = ingr.unit?.name;

                // translate, and also choose appropiate plural/singular term
                if (ingr.unit != null) {
                  final data = widget.currentLangData["units"][ingr.unit!.name]
                      as Map<String, dynamic>?;
                  if (data != null) {
                    if (ingr.amountMax != null || ingr.amountMin != 1) {
                      unitTranslationString = data["plural"];
                    } else {
                      unitTranslationString = data["singular"];
                    }
                  }
                }

                return MapEntry(
                    i,
                    buildIngredientRow(
                        ref,
                        ingr.copyWith(
                          unit:
                              ingr.unit?.copyWith(name: unitTranslationString!),
                        ),
                        widget.recipeId,
                        isMarked[i],
                        () => setState(() {
                              isMarked[i] = !isMarked[i];
                            })));
              })
              .values
              .toList(),
        ),
      ],
    );
  }
}

class IngredientGroupsWidget extends StatelessWidget {
  final List<IngredientGroup> groups;
  final Map<String, dynamic> currentLangData;

  const IngredientGroupsWidget(
      {super.key,
      required this.groups,
      required this.recipeId,
      required this.currentLangData});
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
                    currentLangData: currentLangData)))
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
    final instructions = widget.group.instructions.isNotEmpty
        ? widget.group.instructions.split("\n\n")
        : <String>[];

    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.group.name ?? "", // TODO: LOW if null remove widget
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          ...instructions.asMap().entries.map((entry) {
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

    return Wrap(alignment: WrapAlignment.center, children: [
      // TODO: handle small screens
      // Flexible(
      //   child:
      Padding(
        padding: const EdgeInsets.only(left: 20),
        child: TextButton(
          child: Text(
            recipe!.latestRevision.title ??
                "Untitled", // TODO: LOW if null remove widget
            style: Theme.of(context).textTheme.titleLarge,
          ),
          onPressed: () async {
            final success = await ref
                .read(recipeDetailsControllerProvider(recipeId).notifier)
                .loadRecipe();

            if (!success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: Couldn't load recipe!")),
              );
            }
          },
        ),
      ),
      // ),
      if (recipe.isDraft) ...[
        SizedBox(
          width: 5,
        ),
        Text("[DRAFT]", style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
      Tooltip(
        message: "Parse recipe from URL",
        child: IconButton(
          icon: Icon(Icons.translate),
          onPressed: () async {
            bool userIsWaiting = true;

            final result = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                final TextEditingController controller =
                    TextEditingController();

                return AlertDialog(
                  title: const Text(
                    'Recipe Translate [EXPERIMENTAL]',
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Will try and translate recipe to specified language.\nThis feature is experimental and may fail.",
                      ),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText:
                              'Type language code, e.g., "en", "cs", "de".',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, null);
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, controller.text);
                      },
                      child: const Text('Parse'),
                    ),
                  ],
                );
              },
            );

            if (result == null) {
              return;
            }

            final recipeFuture =
                ref.read(apiServiceProvider).translateRecipe(recipeId, result);

            if (!context.mounted) return;

            // Show progress dialog
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) {
                return PopScope(
                  canPop: true,
                  onPopInvokedWithResult: (_, __) {
                    userIsWaiting = false;
                  },
                  child: AlertDialog(
                    title: const Text("Uploading"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Processing URL...\nWait to be redirected automatically, or feel free to close and you will be notified once its done (if it succeeded).",
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          userIsWaiting = false;
                          Navigator.of(context).pop();
                        },
                        child: const Text("Dismiss"),
                      ),
                    ],
                  ),
                );
              },
            );
            try {
              final recipe = await recipeFuture;

              if (!context.mounted) return;

              if (userIsWaiting) {
                // Close dialog before navigation
                Navigator.of(context, rootNavigator: true).pop();

                context.goNamed(
                  RecipeEditScreen.routeNameEdit,
                  pathParameters: {'id': recipe.id.toString()},
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: TextButton(
                      onPressed: () {
                        context.goNamed(
                          RecipeEditScreen.routeNameEdit,
                          pathParameters: {
                            'id': recipe.id.toString(),
                          },
                        );
                      },
                      child: Text(
                        'Processing of "${recipe.latestRevision.title}" completed',
                      ),
                    ),
                  ),
                );
              }
            } catch (e) {
              if (!context.mounted) return;

              String errorReason;
              e as ApiException;
              if (e.isOffline) {
                errorReason =
                    "Network connection failed (backend unreachable).";
              } else if (e.isServerError) {
                errorReason = "Server couldn't process the file.";
              } else {
                errorReason = "Unknown error ($e)";
              }
              if (userIsWaiting) {
                Navigator.of(context, rootNavigator: true).pop();
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upload failed: $errorReason'),
                ),
              );
            }
          },
        ),
      ),
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
      if (ref
          .read(recipeDetailsControllerProvider(recipeId).notifier)
          .isEditable)
        IconButton(
            onPressed: () {
              context.goNamed(RecipeEditScreen.routeNameEdit,
                  pathParameters: {'id': recipeId.toString()});
            },
            icon: Icon(
              Icons.edit,
              color: Theme.of(context).colorScheme.primary,
            )),
      if (ref
          .read(recipeDetailsControllerProvider(recipeId).notifier)
          .isDeleteable())
        IconButton(
            onPressed: () async {
              final isDeleted = await ref
                  .read(recipeDetailsControllerProvider(recipeId).notifier)
                  .deleteRecipe();

              if (isDeleted && context.mounted) {
                ref.read(recipeSearchFilterSettingsProvider.notifier).reset();
                ref.invalidate(recipeSearchControllerProvider);
                context.goNamed(RecipeSearchPage.routeName);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: Couldn't delete recipe!")),
                );
              }
            },
            icon: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.primary,
            ))
    ]);
  }
}
