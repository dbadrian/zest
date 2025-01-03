import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zest/api/api_service.dart';
import 'package:zest/api/api_status_provider.dart';
import 'package:zest/main.dart';
import 'package:zest/recipes/controller/draft_controller.dart';
import 'package:zest/recipes/screens/recipe_search.dart';
import 'package:zest/settings/settings_provider.dart';
import 'package:zest/utils/utils.dart';

import '../../authentication/auth_service.dart';
import '../../authentication/reauthentication_dialog.dart';
import '../../config/constants.dart';
import '../../routing/app_router.dart';
import '../../utils/networking.dart';
import '../models/models.dart';
import '../screens/recipe_details.dart';

part 'edit_controller.freezed.dart';
part 'edit_controller.g.dart';

void handleDefaultAsyncError(Object err,
    {Function()? onConfirmReauth, Function()? onConfirmTimeout}) {
  if (err is AuthException) {
    openReauthenticationDialog(onConfirm: onConfirmReauth);
  } else if (err is ServerNotReachableException) {
    openServerNotAvailableDialog(onPressed: onConfirmTimeout);
  } else {
    log("Unknown error occurred in edit_controller");
  }
}

void routingCallback(String? recipeId) {
  if (recipeId != null) {
    shellNavigatorKey.currentState!.overlay!.context.goNamed(
      RecipeDetailsPage.routeName,
      pathParameters: {'id': recipeId},
    );
  } else {
    shellNavigatorKey.currentState!.overlay!.context
        .goNamed(HomePage.routeName);
  }
}

@freezed
class IngredientState with _$IngredientState {
  @JsonSerializable(explicitToJson: true)
  const factory IngredientState({
    @Default("") String amountMin,
    @Default("") String amountMax,
    @Default("") String details,
    @Default("") String unit,
    @Default("") String food,
    @Default(null) Unit? selectedUnit,
    @Default(null) Food? selectedFood,
  }) = _IngredientState;

  factory IngredientState.fromJson(Map<String, dynamic> json) =>
      _$IngredientStateFromJson(json);
}

@freezed
class IngredientGroupState with _$IngredientGroupState {
  const IngredientGroupState._();
  @JsonSerializable(explicitToJson: true)
  const factory IngredientGroupState({
    @Default("") String name,
    @Default([]) List<IngredientState> ingredients,
  }) = _IngredientGroupState;

  IngredientGroupState updateIngredient(int index, IngredientState ingredient) {
    final newIngredients = [...ingredients];
    newIngredients.insert(index, ingredient);
    newIngredients.removeAt(index + 1);
    return IngredientGroupState(name: name, ingredients: newIngredients);
  }

  // ignore: prefer_const_constructors
  IngredientGroupState add(
      {IngredientState ingredient = const IngredientState()}) {
    return IngredientGroupState(
        name: name, ingredients: [...ingredients, ingredient]);
  }

  IngredientGroupState delete(int index) {
    ingredients.removeAt(index);
    return IngredientGroupState(name: name, ingredients: ingredients);
  }

  IngredientGroupState move(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newIngredients = [...ingredients];
    final item = newIngredients.removeAt(oldIndex);
    newIngredients.insert(newIndex, item);
    return IngredientGroupState(name: name, ingredients: newIngredients);
  }

  factory IngredientGroupState.fromJson(Map<String, dynamic> json) =>
      _$IngredientGroupStateFromJson(json);

  @override
  String toString() {
    return "$name: [${ingredients.join(', ')}]";
  }
}

@unfreezed
class InstructionGroupState with _$InstructionGroupState {
  InstructionGroupState._();

  @JsonSerializable(explicitToJson: true)
  factory InstructionGroupState({
    required String name,
    required List<String> instructions,
  }) = _InstructionGroupState;

  InstructionGroupState add({String instruction = ""}) {
    return InstructionGroupState(
        name: name, instructions: [...instructions, instruction]);
  }

  InstructionGroupState delete(int index) {
    instructions.removeAt(index);
    return InstructionGroupState(name: name, instructions: instructions);
  }

  InstructionGroupState move(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newInstructions = [...instructions];
    final item = newInstructions.removeAt(oldIndex);
    newInstructions.insert(newIndex, item);
    return InstructionGroupState(name: name, instructions: newInstructions);
  }

  factory InstructionGroupState.fromJson(Map<String, dynamic> json) =>
      _$InstructionGroupStateFromJson(json);
}

@unfreezed
class RecipeEditState with _$RecipeEditState {
  const RecipeEditState._();
  @JsonSerializable(explicitToJson: true)
  factory RecipeEditState({
    // @Default(GlobalKey<FormState>) GlobalKey<FormState> formKey,
    @Default(null) int? pk,
    @Default(null) String? lang,
    @Default("") String title,
    @Default("") String subtitle,
    @Default(false) bool private,
    @Default("") String ownerComment,
    @Default([]) List<Tag> tags,
    @Default([]) List<RecipeCategory> categories,
    @Default(0) int difficulty,
    @Default("") String servings,
    @Default("") String prepTime,
    @Default("") String cookTime,
    @Default("") String sourceName,
    @Default("") String sourcePage,
    @Default("") String sourceUrl,
    // @Default([InstructionGroupState(name: "", instructions: [])])
    List<InstructionGroupState>? instructionGroups,
    @Default([IngredientGroupState()])
    List<IngredientGroupState> ingredientGroups,
    Recipe? recipe,
    @Default({}) Map<int, RecipeCategory> validRecipeCategoryChoices,
    @Default(false) bool triggered,
    @Default(false) bool hasUnpersistedChanges,
  }) = _RecipeEditState;

  factory RecipeEditState.fromJson(Map<String, dynamic> json) =>
      _$RecipeEditStateFromJson(json);

  Map<String, dynamic> toDBMap() {
    return {
      if (pk != null) "id": pk!,
      "updatedLast": DateTime.timestamp().millisecondsSinceEpoch,
      "state": jsonEncode(toJson()),
    };
  }

  factory RecipeEditState.fromDBMap(Map<String, dynamic> m) {
    final json = jsonDecode(m["state"]!);
    return RecipeEditState.fromJson(json);
  }
}

@riverpod
class RecipeEditController extends _$RecipeEditController {
  final tagDebouncer_ = Debouncer(milliseconds: 500);

  final hasChanges = false;

  bool debounceTagQuery(VoidCallback action) {
    return tagDebouncer_.run(action);
  }

  @override
  FutureOr<RecipeEditState> build(String? recipeId, {int? draftId}) async {
    // TODO: The download of recipe categories could happen once during bootup
    // of the app and then stored in a "knowledge provider"
    state = const AsyncValue.loading();

    final categories = await AsyncValue.guard(() =>
        ref.read(apiServiceProvider).getRecipeCategories(pageSize: 10000));
    if (categories.hasError) {
      if (categories.error is AuthException) {
        openReauthenticationDialog(
            // TODO: onconfirm
            );
      } else if (categories.error is ServerNotReachableException) {
        openServerNotAvailableDialog(onPressed: () {
          ref.read(apiStatusProvider.notifier).updateStatus(false);
          shellNavigatorKey.currentState!.overlay!.context
              .goNamed(RecipeSearchPage.routeName);
        });
      }
    }
    // express the list as a map
    final validCategories = {for (final e in categories.value!) e.id: e};

    if (!categories.hasError && recipeId != null) {
      // set state to loading only for the initial page build
      // afterwards we want silent updates?
      state = const AsyncValue.loading();
      final language = ref.watch(settingsProvider.select((v) => v.language));
      final recipeValue = await AsyncValue.guard(() =>
          ref.read(apiServiceProvider).getRecipe(recipeId, language: language));
      if (recipeValue.hasError) {
        if (recipeValue.error is AuthException) {
          openReauthenticationDialog(
              // TODO: onconfirm
              );
        } else if (recipeValue.error is ServerNotReachableException) {
          openServerNotAvailableDialog();
        }
        // return nothing but we will return the empty state below
        log("some other unahdled error occured...");
      }
      if (recipeValue.hasValue) {
        final s = rebuildStateFromRecipeImpl(recipeValue.value!).copyWith(
          validRecipeCategoryChoices: validCategories,
        );
        pushState(s);
        ref.watch(recipeEditorHistoryControllerProvider.notifier).reset();
        state = AsyncValue.data(s);
        return s;
      }
    } else if (draftId != null) {
      // load draft
      final draftState = ref
          .read(recipeDraftSearchControllerProvider.notifier)
          .getById(draftId);
      if (draftState != null) {
        final s =
            draftState.copyWith(validRecipeCategoryChoices: validCategories);
        pushState(s);
        state = AsyncValue.data(s);
        ref.watch(recipeEditorHistoryControllerProvider.notifier).reset();
        return s;
      }
    }

    // initialize debounce timers
    ref.onDispose(() async {
      tagDebouncer_.dispose();
    });

    // either no recipeId or some error above...we jsut drop down to below...
    log("Building recipe empty for editor");
    final s = rebuildStateFromRecipeImpl(Recipe(
      recipeId: "",
      dateCreated: DateTime.now(),
      owner: "",
      language: ref.read(settingsProvider).language,
      title: "",
      private: false,
      ownerComment: "",
      tags: [],
      categories: [],
      servings: 1,
      ingredientGroups: [IngredientGroup(name: "", ingredients: [])],
      instructionGroups: [
        InstructionGroup(name: "", instructions: [Instruction(text: "")])
      ],
    )).copyWith(
      validRecipeCategoryChoices: validCategories,
    );

    pushState(s);
    ref.watch(recipeEditorHistoryControllerProvider.notifier).reset();
    state = AsyncValue.data(s);
    return s;

    // return RecipeEditState(
    //   formKey: GlobalKey<FormState>(),
    //   validRecipeCategoryChoices: validCategories,
    //   // instructionGroups: [
    //   //   const InstructionGroupState(instructions: ["asdsas"])
    //   // ],
    //   // ingredientGroups: [const IngredientGroupState()],
    //   recipe: Recipe(
    //     recipeId: "",
    //     dateCreated: DateTime.now(),
    //     owner: "",
    //     language: ref.read(settingsProvider).language,
    //     title: "",
    //     private: true,
    //     ownerComment: "",
    //     tags: [],
    //     categories: [],
    //     servings: 1,
    //     ingredientGroups: [],
    //     instructionGroups: [
    //       InstructionGroup(name: "1", instructions: [Instruction(text: "2")])
    //     ],
    //   ),
    // );
  }

  RecipeEditState rebuildStateFromRecipeImpl(Recipe recipe) {
    log("Building recipe for editor: $recipe");

    final instructionsGroups = [
      for (final instrGroup in recipe.instructionGroups)
        InstructionGroupState(
            name: instrGroup.name,
            instructions: instrGroup.instructions.map((e) => e.text).toList()),
    ];
    final ingredientGroups = [
      for (final ingrdGroup in recipe.ingredientGroups)
        IngredientGroupState(
          name: ingrdGroup.name,
          ingredients: ingrdGroup.ingredients
              .map(
                (e) => IngredientState(
                  amountMin: e.amount,
                  amountMax: e.amountMax ?? "",
                  details: e.details ?? "",
                  unit: e.unit.name.value(),
                  food: e.food.name.value(),
                  selectedUnit: e.unit,
                  selectedFood: e.food,
                ),
              )
              .toList(),
        ),
    ];
    if (instructionsGroups.isEmpty) {
      instructionsGroups.add(InstructionGroupState(name: '', instructions: []));
    }
    if (ingredientGroups.isEmpty) {
      ingredientGroups.add(const IngredientGroupState());
    }

    return RecipeEditState(
        // formKey: GlobalKey<FormState>(),
        lang: recipe.language,
        title: recipe.title,
        subtitle: recipe.subtitle ?? "",
        private: recipe.private,
        ownerComment: recipe.ownerComment ?? "",
        difficulty: recipe.difficulty ?? 0,
        categories: recipe.categories,
        tags: recipe.tags,
        servings: recipe.servings.toString(),
        prepTime: recipe.prepTime?.toString() ?? "",
        cookTime: recipe.cookTime?.toString() ?? "",
        sourceName: recipe.sourceName ?? "",
        sourcePage: recipe.sourcePage?.toString() ?? "",
        sourceUrl: recipe.sourceUrl ?? "",
        instructionGroups: instructionsGroups,
        ingredientGroups: ingredientGroups,
        recipe: recipe);
  }

  void rebuildStateFromRecipe(Recipe recipe) {
    state = AsyncValue.data(rebuildStateFromRecipeImpl(recipe).copyWith(
      validRecipeCategoryChoices: state.value!.validRecipeCategoryChoices,
    ));
  }

  void stepStateBack() {
    final newState =
        ref.watch(recipeEditorHistoryControllerProvider.notifier).softPop();
    if (newState != null) {
      debugPrint("setting new state");
      state = AsyncValue.data(
          newState.copyWith(triggered: !state.value!.triggered));
    }
  }

  void stepStateForward() {
    final newState =
        ref.watch(recipeEditorHistoryControllerProvider.notifier).forward();
    if (newState != null) {
      debugPrint("setting new state");

      state = AsyncValue.data(
          newState.copyWith(triggered: !state.value!.triggered));
    }
  }

  void pushState(RecipeEditState newState) {
    ref.watch(recipeEditorHistoryControllerProvider.notifier).push(newState);
  }

  void setState(RecipeEditState newState) {
    state = AsyncValue.data(newState);
  }

  void pushAndUpdateState(RecipeEditState newState) {
    state = AsyncValue.data(ref
        .watch(recipeEditorHistoryControllerProvider.notifier)
        .push(newState));
  }

  void updateTitle(String title) {
    pushAndUpdateState(state.value!.copyWith(title: title));
  }

  void updateSubtitle(String subtitle) {
    pushAndUpdateState(state.value!.copyWith(subtitle: subtitle));
  }

  void updatePrivate(bool private) {
    pushAndUpdateState(state.value!.copyWith(private: private));
  }

  void updateOwnerComment(String ownerComment) {
    pushAndUpdateState(state.value!.copyWith(ownerComment: ownerComment));
  }

  // @Default([]) List<Tag> tags,
  // @Default([]) List<RecipeCategory> categories,

  void updateCategories(List<int>? categories) {
    final newCategories = categories!
        .map((e) => state.value!.validRecipeCategoryChoices[e]!)
        .toList();
    setState(state.value!.copyWith(categories: newCategories));
    // pushAndUpdateState(state.value!.copyWith(categories: newCategories));
  }

  void updateTags(List<Tag> tags) {
    pushAndUpdateState(state.value!.copyWith(tags: tags));
  }

  void updateDifficulty(int difficulty) {
    state = AsyncValue.data(ref
        .watch(recipeEditorHistoryControllerProvider.notifier)
        .push(state.value!.copyWith(difficulty: difficulty)));
    // pushAndUpdateState(state.value!.copyWith(difficulty: difficulty));
  }

  void updateServings(String servings) {
    pushAndUpdateState(state.value!.copyWith(servings: servings));
  }

  void updatePrepTime(String prepTime) {
    pushAndUpdateState(state.value!.copyWith(prepTime: prepTime));
  }

  void updateCookTime(String cookTime) {
    pushAndUpdateState(state.value!.copyWith(cookTime: cookTime));
  }

  void updateSourceName(String sourceName) {
    pushAndUpdateState(state.value!.copyWith(sourceName: sourceName));
  }

  void updateSourcePage(String sourcePage) {
    pushAndUpdateState(state.value!.copyWith(sourcePage: sourcePage));
  }

  void updateSourceUrl(String sourceUrl) {
    pushAndUpdateState(state.value!.copyWith(sourceUrl: sourceUrl));
  }

  // for these kind of updates we dont need to trigger a screen update
  void moveInstruction(int groupId, int oldIndex, int newIndex) {
    final newGroups = [...state.value!.instructionGroups!];
    newGroups[groupId] = newGroups[groupId].move(oldIndex, newIndex);
    pushAndUpdateState(state.value!.copyWith(instructionGroups: newGroups));
  }

  int moveInstructionUp(int groupId, int index) {
    if (index == 0) {
      return index;
    }

    final newGroups = [...state.value!.instructionGroups!];
    newGroups[groupId] = newGroups[groupId].move(index, index - 1);
    pushAndUpdateState(state.value!.copyWith(instructionGroups: newGroups));
    return index - 1;
  }

  int moveInstructionDown(int groupId, int index) {
    if (index ==
        state.value!.instructionGroups![groupId].instructions.length - 1) {
      return index;
    }

    final newGroups = [...state.value!.instructionGroups!];
    newGroups[groupId] = newGroups[groupId].move(index, index + 2);

    pushAndUpdateState(state.value!.copyWith(instructionGroups: newGroups));

    return index + 1;
  }

  void updateInstruction(int groupId, int instructionId, String update) {
    final newGroups = [...state.value!.instructionGroups!];
    final instructions = [...newGroups[groupId].instructions].toList();
    instructions[instructionId] = update;
    newGroups[groupId] =
        newGroups[groupId].copyWith(instructions: instructions);
    pushAndUpdateState(state.value!.copyWith(instructionGroups: newGroups));
  }

  void addInstruction(int groupId) {
    final newGroups = [...state.value!.instructionGroups!];
    newGroups[groupId] = newGroups[groupId].add();
    pushAndUpdateState(state.value!.copyWith(instructionGroups: newGroups));
  }

  void deleteInstruction(int groupId, int instructionId) {
    final newGroups = [...state.value!.instructionGroups!];
    newGroups[groupId] = newGroups[groupId].delete(instructionId);
    pushAndUpdateState(state.value!.copyWith(instructionGroups: newGroups));
  }

  void addInstructionGroup() {
    pushAndUpdateState(state.value!.copyWith(instructionGroups: [
      ...state.value!.instructionGroups!,
      // ignore: prefer_const_constructors
      InstructionGroupState(name: "", instructions: [""])
    ]));
  }

  void deleteInstructionGroup(int index) {
    final tmp = [...state.value!.instructionGroups!];
    tmp.removeAt(index);
    pushAndUpdateState(state.value!.copyWith(instructionGroups: tmp));
  }

  void moveInstructionGroup(int oldIndex, int newIndex) {
    final tmp = [...state.value!.instructionGroups!];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = tmp.removeAt(oldIndex);
    tmp.insert(newIndex, item);
    pushAndUpdateState(state.value!.copyWith(instructionGroups: tmp));
  }

  void updateInstructionGroupName(int groupId, String name) {
    final newGroups = [...state.value!.instructionGroups!];
    newGroups[groupId] = newGroups[groupId].copyWith(name: name);
    pushAndUpdateState(state.value!.copyWith(instructionGroups: newGroups));
  }

  // Ingredients
  void moveIngredient(int groupId, int oldIndex, int newIndex) {
    final newGroups = [...state.value!.ingredientGroups];
    newGroups[groupId] = newGroups[groupId].move(oldIndex, newIndex);
    pushAndUpdateState(state.value!.copyWith(ingredientGroups: newGroups));
  }

  void updateIngredient(int groupId, int ingredientId, IngredientState update) {
    debugPrint("updateIngredient $groupId $ingredientId $update");
    final grps = [...state.value!.ingredientGroups];
    grps[groupId] = grps[groupId].updateIngredient(ingredientId, update);
    if (update.selectedFood != null &&
        update.selectedFood!.id !=
            grps[groupId].ingredients[ingredientId].selectedFood?.id) {
      if (kDebugMode) {
        debugPrint(update.selectedFood.toString());
        debugPrint(
            grps[groupId].ingredients[ingredientId].selectedFood.toString());
        debugPrint("async update due to food");
      }
    } else {
      if (kDebugMode) {
        debugPrint("regular food ${update.selectedFood}");
      }

      state.value!.ingredientGroups = grps;
    }
    pushAndUpdateState(state.value!.copyWith(ingredientGroups: grps));
  }

  void addIngredient(int groupId) {
    final newGroups = [...state.value!.ingredientGroups];
    newGroups[groupId] = newGroups[groupId].add();
    pushAndUpdateState(state.value!.copyWith(ingredientGroups: newGroups));
  }

  void deleteIngredient(int groupId, int ingredientId) {
    final ingrCpy = [...state.value!.ingredientGroups[groupId].ingredients];
    ingrCpy.removeAt(ingredientId);

    // place it back
    final newGroups = [...state.value!.ingredientGroups];
    newGroups[groupId] = newGroups[groupId].copyWith(ingredients: ingrCpy);

    pushAndUpdateState(state.value!.copyWith(ingredientGroups: newGroups));
  }

  void addIngredientGroup() {
    pushAndUpdateState(state.value!.copyWith(ingredientGroups: [
      ...state.value!.ingredientGroups,
      // ignore: prefer_const_constructors
      IngredientGroupState(ingredients: [IngredientState()])
    ]));
  }

  void deleteIngredientGroup(int index) {
    final tmp = [...state.value!.ingredientGroups];
    tmp.removeAt(index);
    pushAndUpdateState(state.value!.copyWith(ingredientGroups: tmp));
  }

  void moveIngredientGroup(int oldIndex, int newIndex) {
    final tmp = [...state.value!.ingredientGroups];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = tmp.removeAt(oldIndex);
    tmp.insert(newIndex, item);
    pushAndUpdateState(state.value!.copyWith(ingredientGroups: tmp));
  }

  void updateIngredientGroupName(int groupId, String name) {
    final grps = [...state.value!.ingredientGroups];
    grps[groupId] = grps[groupId].copyWith(name: name);
    pushAndUpdateState(state.value!.copyWith(ingredientGroups: grps));
  }

  void updateLanguage(String lang) {
    debugPrint("updateLanguage $lang");
    pushAndUpdateState(state.value!.copyWith(lang: lang));
  }

  void purgeEmptyOptionals() {
    final List<int> toDeleteInstruction = [];
    state.value!.instructionGroups!.asMap().forEach((key, value) {
      final allEmpty = value.instructions.every((element) => element.isEmpty);

      if (value.name.isEmpty && (value.instructions.isEmpty || allEmpty)) {
        toDeleteInstruction.add(key);
      }
    });
    for (final index in toDeleteInstruction) {
      deleteInstructionGroup(index);
    }

    final List<int> toDeleteIngredients = [];
    state.value!.ingredientGroups.asMap().forEach((key, value) {
      if (value.name.isEmpty && value.ingredients.isEmpty) {
        toDeleteIngredients.add(key);
      }
    });
    for (final index in toDeleteIngredients) {
      deleteIngredientGroup(index);
    }
  }

  // communication with backend
  Future<Recipe?> updateRecipe_() async {
    // Update the recipe class with the informations provided
    final ingredientGroups = state.value!.ingredientGroups
        .map((e) => IngredientGroup(
            name: e.name,
            ingredients: e.ingredients
                .map((i) => Ingredient(
                    amount: i.amountMin,
                    amountMax: i.amountMax,
                    unit: i.selectedUnit!,
                    food: i.selectedFood!,
                    details: i.details))
                .toList()))
        .toList();

    final instructionGroups = state.value!.instructionGroups!
        .map((e) => InstructionGroup(
            name: e.name,
            instructions:
                e.instructions.map((text) => Instruction(text: text)).toList()))
        .toList();

    // manually push all tags that might not have been create on remote yet!
    state = AsyncData(state.value!.copyWith(tags: [
      ...state.value!.tags.where((e) => e.id.isNotEmpty),
      ...await Future.wait(state.value!.tags
          .where((e) => e.id.isEmpty)
          .map((e) =>
              ref.read(apiServiceProvider).createTag(jsonEncode(e.toJson())))
          .toList())
    ]));

    final newRecipe = state.value!.recipe!.copyWith(
        title: state.value!.title,
        subtitle: state.value!.subtitle,
        language: state.value!.lang,
        ownerComment: state.value!.ownerComment,
        difficulty: state.value!.difficulty,
        categories: state.value!.categories,
        tags: state.value!.tags,
        servings: int.tryParse(state.value!.servings) ?? 0,
        prepTime: int.tryParse(state.value!.prepTime),
        cookTime: int.tryParse(state.value!.cookTime),
        sourceName: state.value!.sourceName,
        sourcePage: int.tryParse(state.value!.sourcePage),
        sourceUrl: state.value!.sourceUrl,
        private: state.value!.private,
        ingredientGroups: ingredientGroups,
        instructionGroups: instructionGroups);
    final recipeJson = newRecipe.toJson();
    final apiService = ref
        .read(apiServiceProvider); // TODO why is this needed to keep it alive?

    if (newRecipe.recipeId.isEmpty) {
      recipeJson.remove("recipe_id");
      return apiService.createRecipeRemote(jsonEncode(recipeJson),
          lang: state.value!.lang);
    } else {
      return apiService.updateRecipeRemote(
          newRecipe.recipeId, jsonEncode(recipeJson));
    }
  }

  Future<bool> updateRecipe() async {
    saveRecipeDraft();
    // if (state.value!.hasUnpersistedChanges) {
    // }

    final recipeValue = await AsyncValue.guard(updateRecipe_);
    if (recipeValue.hasError) {
      if (recipeValue.error is AuthException) {
        openReauthenticationDialog(onConfirm: updateRecipe);
      } else if (recipeValue.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      } else {
        log("Uncaught error... ${recipeValue.error}");
      }
      return false;
    } else {
      state = AsyncData(state.value!.copyWith(recipe: recipeValue.value));
      return (recipeValue.value == null) ? false : true;
    }
  }

  void saveRecipeDraft() async {
    final db = ref.read(sqliteDbProvider);

    final id = await db.insert(
      RECIPE_DRAFT_DB_KEY,
      state.value!.toDBMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint("Stored recipe draft in database as id: $id!");
    if (state.value!.pk == null) {
      state = AsyncValue.data(state.value!.copyWith(pk: id));
      saveRecipeDraft(); // FIXME: to save one version with the pk in the json string...gosh this sucks arse
    }
  }

  void deleteRecipeDraft() async {
    final db = ref.read(sqliteDbProvider);

    final numDeleted = await db.delete(
      RECIPE_DRAFT_DB_KEY,
      where: 'id = ?',
      whereArgs: [state.value!.pk],
    );
    print(
        "Deleted recipe draft [$state.value!.pk] in database as! (nd: $numDeleted)");
  }

  Future<RecipeEditState?> loadRecipeDraft(int draftId) async {
    final db = ref.read(sqliteDbProvider);
    final ret = await db
        .query(RECIPE_DRAFT_DB_KEY, where: 'id = ?', whereArgs: [draftId]);

    if (ret.isEmpty) {
      return null;
    }

    return RecipeEditState.fromDBMap(ret[0]);
  }

  void fillRecipeFromJSON(Map<String, dynamic> json) async {
    state = const AsyncValue.loading();

    final recipeBackup = state.value!.recipe;
    pushAndUpdateState(state.value?.copyWith(recipe: null) ?? state.value!);

    // final state = RecipeEditState(
    //   // formKey: GlobalKey<FormState>(),

    //   // ingredientGroups: ingredientGroups,
    // );

    // first we get the language as indicated by the recipe, so we can adjust queries accordingly
    final String lang = json['language']?.toString() ?? "";

    final instructions = <InstructionGroupState>[];
    if (json["instruction_groups"] != null &&
        json["instruction_groups"] is List) {
      for (final e in (json["instruction_groups"] as List<dynamic>)) {
        try {
          final inst = <String>[];
          for (final tel in (e["instructions"] as List<dynamic>)) {
            if (tel["text"] != null) inst.add(tel["text"].toString());
          }
          final grp =
              InstructionGroupState(name: e["name"], instructions: inst);
          instructions.add(grp);
        } catch (e) {
          debugPrint("Invalid JSON part (instruction), skipping");
        }
      }
    }

    final ingredients = <IngredientGroupState>[];
    if (json["ingredient_groups"] != null &&
        json["ingredient_groups"] is List) {
      for (final e in (json["ingredient_groups"] as List<dynamic>)) {
        try {
          final ingr = <IngredientState>[];
          for (final tel in (e["ingredients"] as List<dynamic>)) {
            // parse unit and match against database

            Unit? unit;
            String unitString = "";
            final units = await ref
                .read(apiServiceProvider)
                .getUnits(pageSize: 1000, language: lang);
            if (tel["unit"] != null) {
              final unitSearch = tel["unit"].toString().toLowerCase();
              for (final u in units) {
                if ((u.abbreviation?.value().toLowerCase() ?? "XXX!XXX") ==
                        unitSearch ||
                    u.name.value().toLowerCase() == unitSearch ||
                    (u.namePlural?.value().toLowerCase() ?? "XXX!XXX") ==
                        unitSearch) {
                  unit = u;
                  unitString = u.name.value();
                }
              }
            }

            // parse food and match against database

            Food? food;
            String foodString = tel["food"] ?? "";
            if (tel["food"] != null) {
              final foods = await ref.read(apiServiceProvider).getFoods(
                  search: tel["food"] ?? "", pageSize: 10, language: lang);
              final foodSearch = tel["food"].toString().toLowerCase();
              for (final f in foods) {
                if (f.name.value().toLowerCase() == foodSearch) {
                  food = f;
                  foodString = f.name.value();
                }
              }

              // if (food == null) {
              //   final foodSyns = await ref
              //       .read(apiServiceProvider)
              //       .getFoodSynonyms(search: tel["food"] ?? "", pageSize: 100);
              //   for (final f in foodSyns) {
              //     if (f.food.toLowerCase() == foodSearch) {
              //       food = f.;
              //       foodString = f.name.value();
              //     }
              //   }
              // }
            }

            ingr.add(IngredientState(
              amountMin: tel["amount_min"]?.toString() ?? "",
              amountMax: tel["amount_max"]?.toString() ?? "",
              details: tel["amount_max"]?.toString() ?? "",
              selectedUnit: unit,
              unit: unitString,
              selectedFood: food,
              food: foodString,
            ));
          }
          final grp = IngredientGroupState(name: e["name"], ingredients: ingr);
          ingredients.add(grp);
        } catch (e) {
          debugPrint("Invalid JSON part (ingredient), skipping: $e");
        }
      }
    }

    pushAndUpdateState(state.value!.copyWith(
        lang: lang,
        title: (json["title"] ?? "").toString(),
        subtitle: (json["subtitle"] ?? "").toString(),
        // check if entry is of type bool, else set to private

        private: json["private"] is bool ? json["private"] ?? false : true,
        ownerComment: (json["owner_comment"] ?? "").toString(),
        difficulty: (int.tryParse((json["difficulty"] ?? "").toString()) ?? 0)
            .clamp(0, 3),
        // categories: recipe.categories,
        // tags: recipe.tags,
        servings: (json["servings"] ?? "").toString(),
        prepTime: (json["prep_time"] ?? "").toString(),
        cookTime: (json["cook_time"] ?? "").toString(),
        sourceName: (json["source_name"] ?? "").toString(),
        sourcePage: (json["source_page"] ?? "").toString(),
        sourceUrl: (json["source_url"] ?? "").toString(),
        instructionGroups: instructions,
        ingredientGroups: ingredients,
        recipe: recipeBackup));
  }
}

@freezed
class FoodCreationState with _$FoodCreationState {
  factory FoodCreationState({
    @Default({}) Map<String, String> langFields,
    @Default("") String kcal,
    @Default("") String totalFat,
    @Default("") String saturatedFat,
    @Default("") String polyunsaturatedFat,
    @Default("") String monounsaturatedFat,
    @Default("") String cholestoral,
    @Default("") String sodium,
    @Default("") String totalCarbohydrates,
    @Default("") String carbohydrateDietaryFiber,
    @Default("") String carbohydrateSugar,
    @Default("") String protein,
    @Default("") String lactose,
    @Default("") String fructose,
    @Default("") String glucose,
  }) = _FoodCreationState;
}

@riverpod
class FoodCreationController extends _$FoodCreationController {
  @override
  FoodCreationState build(
      {required String initialLanguage, String initialValue = ""}) {
    final langFields = {initialLanguage: initialValue};
    final otherLangs = AVAILABLE_LANGUAGES.map((key, value) => MapEntry(
          key,
          "",
        ));
    otherLangs.remove(initialLanguage);
    // now the initial lang is at the top
    langFields.addAll(otherLangs);

    return FoodCreationState(langFields: langFields);
  }

  Future<Food?> submit() async {
    final translatedValues = <TranslatedValue>[];
    for (final entry in state.langFields.entries) {
      if (entry.value != "") {
        translatedValues
            .add(TranslatedValue(value: entry.value, lang: entry.key));
      }
    }
    final nameField = TranslatedField(values: translatedValues);
    final foodItem = Food(id: "", name: nameField);
    final apiService = ref.read(apiServiceProvider);
    var json = foodItem.toJson();
    final foodString = jsonEncode(json);

    final createdFoodItem = await AsyncValue.guard(() =>
        apiService.createFood(foodString, language: state.langFields["0"]));
    if (createdFoodItem.hasError) {
      handleDefaultAsyncError(
        createdFoodItem.error!,
        // onConfirmReauth: (() => routingCallback(recipeId)),
        // onConfirmTimeout: (() => routingCallback(recipeId)),
      );
      return null;
    } else {
      return createdFoodItem.value;
    }
  }

  void updateLangFields(MapEntry entry) {
    final langFields = {...state.langFields};
    langFields[entry.key] = entry.value;
    state = state.copyWith(langFields: langFields);
  }

  void updateKcal(String kcal) {
    state = state.copyWith(kcal: kcal);
  }

  void updatetotalFat(String totalFat) {
    state = state.copyWith(totalFat: totalFat);
  }

  void updateSaturatedFat(String saturatedFat) {
    state = state.copyWith(saturatedFat: saturatedFat);
  }

  void updatePolyunsaturatedFat(String polyunsaturatedFat) {
    state = state.copyWith(polyunsaturatedFat: polyunsaturatedFat);
  }

  void updateMonounsaturatedFat(String monounsaturatedFat) {
    state = state.copyWith(monounsaturatedFat: monounsaturatedFat);
  }

  void updateCholestoral(String cholestoral) {
    state = state.copyWith(cholestoral: cholestoral);
  }

  void updateSodium(String sodium) {
    state = state.copyWith(sodium: sodium);
  }

  void updateTotalCarbohydrates(String totalCarbohydrates) {
    state = state.copyWith(totalCarbohydrates: totalCarbohydrates);
  }

  void updateCarbohydrateDietaryFiber(String carbohydrateDietaryFiber) {
    state = state.copyWith(carbohydrateDietaryFiber: carbohydrateDietaryFiber);
  }

  void updateCarbohydrateSugar(String carbohydrateSugar) {
    state = state.copyWith(carbohydrateSugar: carbohydrateSugar);
  }

  void updateProtein(String protein) {
    state = state.copyWith(protein: protein);
  }

  void updateLactose(String lactose) {
    state = state.copyWith(lactose: lactose);
  }

  void updateFructose(String fructose) {
    state = state.copyWith(fructose: fructose);
  }

  void updateGlucose(String glucose) {
    state = state.copyWith(glucose: glucose);
  }
}

@unfreezed
class RecipeEditorHistoryState with _$RecipeEditorHistoryState {
  factory RecipeEditorHistoryState({
    @Default([]) List<RecipeEditState> history,
    @Default(-1) int current,
  }) = _RecipeEditorHistoryState;
}

@riverpod
class RecipeEditorHistoryController extends _$RecipeEditorHistoryController {
  @override
  RecipeEditorHistoryState build() {
    return RecipeEditorHistoryState();
  }

  void reset() {}

  RecipeEditState push(RecipeEditState editState) {
    debugPrint("History push....");
    debugPrint("before: ${state.current},${state.history.length}");

    if (state.current == 0) {
      final history = [state.history[0], editState];
      state = state.copyWith(history: history, current: state.current + 1);
    } else if (state.current < state.history.length - 1 && state.current > 0) {
      final history = [
        state.history[0],
        ...state.history.sublist(1, state.current),
        editState
      ];
      if (history.length > MAX_HISTORY_STEPS) {
        history.removeAt(0);
      }
      state = state.copyWith(history: history, current: state.current + 1);
    } else {
      final history = [...state.history, editState];
      if (history.length > MAX_HISTORY_STEPS) {
        history.removeAt(0);
      }
      state = state.copyWith(history: history, current: state.history.length);
    }
    debugPrint("${state.current},${state.history.length}");
    return editState;
  }

  bool canPop() {
    return state.current > 0;
  }

  bool canForward() {
    return state.current < state.history.length - 1;
  }

  RecipeEditState? softPop() {
    debugPrint("${state.current},${state.history.length}, pop");
    if (state.current <= 0) {
      // no history to pop
      return null;
    } else if (canPop()) {
      final retIdx = state.current - 1;
      --state.current;
      debugPrint("sending state back... $retIdx");
      return state.history[retIdx];
    }

    return null;
    // return state.history[state.current - 1];
  }

  RecipeEditState? forward() {
    debugPrint("${state.current}->${state.history.length}, forward");

    if (canForward()) {
      return state.history[++state.current];
    }
    return null;
  }
}
