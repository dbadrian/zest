import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/recipes/recipe_repository.dart';
import 'package:zest/settings/settings_provider.dart';

import '../../authentication/auth_service.dart';
import '../models/recipe.dart';

part 'details_controller.g.dart';

@riverpod
class RecipeDetailsController extends _$RecipeDetailsController {
  // you can add named or positional parameters to the build method
  @override
  FutureOr<Recipe?> build(int recipeId) async {
    String _ = ref.watch(settingsProvider).current.language;
    final recipe = await AsyncValue.guard(() => _loadRecipe());
    if (recipe.hasError) {
      // hand it out to the screen to deal with.
      throw recipe.error!;
    } else {
      return recipe.value;
    }
  }

  bool get isEditable {
    if (state.hasValue) {
      // all values should be not null if user got to this point
      final userId = ref.read(authenticationServiceProvider).value?.user.id;
      return userId != null ? userId == state.value!.ownerId : false;
    }
    return false;
  }

  bool isDeleteable() {
    if (state.hasValue) {
      // all values should be not null if user got to this point
      final userId = ref.read(authenticationServiceProvider).value?.user.id;
      return userId != null ? userId == state.value!.ownerId : false;
    }
    return false;
  }

  Future<Recipe?> _loadRecipe() async {
    return await ref.read(recipeRepositoryProvider).getRecipeById(recipeId);
  }

  Future<bool> loadRecipe({String? servings, bool? toMetric}) async {
    var ret = await AsyncValue.guard(() => _loadRecipe());

    if (ret.hasError) {
      return false;
    }
    // if (ret.hasError) {
    //   if (ret.error is ApiException) {
    //     openReauthenticationDialog(
    //         onConfirm: () => loadRecipe(servings: servings));
    //   } else if (ret.error is ServerNotReachableException) {
    //     openServerNotAvailableDialog();
    //   }
    //   return false;
    // }

    // recipe pulled, now we calculate the modified servings count
    if (servings != null && ret.value!.latestRevision.servings != null) {
      final ratio = int.parse(servings) / ret.value!.latestRevision.servings!;

      ret = AsyncValue.data(ret.value!.copyWith.latestRevision(
          ingredientGroups: ret.value!.latestRevision.ingredientGroups
              .map((g) => g.copyWith(
                  ingredients: g.ingredients
                      .map((i) => i.copyWith(
                          amountMax: tryMultiply(i.amountMax, ratio),
                          amountMin: tryMultiply(i.amountMin, ratio)))
                      .toList()))
              .toList()));
    }

    if (toMetric != null && toMetric) {
      ret = AsyncValue.data(ret.value!.copyWith.latestRevision(
          ingredientGroups: ret.value!.latestRevision.ingredientGroups
              .map((g) => g.copyWith(
                      ingredients: g.ingredients.map((i) {
                    if (!i.hasMetricConversion()) {
                      return i;
                    }

                    return i.copyWith(
                        unit: i.unit!.copyWith(
                            name: i.unit!.baseUnit!, unitSystem: "Metric"),
                        amountMax: tryMultiply(
                            i.amountMax, i.unit?.conversionFactor ?? 1.0),
                        amountMin: tryMultiply(
                            i.amountMin, i.unit?.conversionFactor ?? 1.0));
                  }).toList()))
              .toList()));
    }

    state = ret;
    return true;
  }

  double? tryMultiply(double? a, double ratio) {
    if (a == null) {
      return a;
    }
    return a * ratio;
  }

  void addToFavorites() async {
    state = await AsyncValue.guard(() =>
        ref.read(recipeRepositoryProvider).addRecipeToFavorites(recipeId));
  }

  void deleteFromFavorites() async {
    state = await AsyncValue.guard(() =>
        ref.read(recipeRepositoryProvider).removeRecipeFromFavorites(recipeId));
  }

  Future<bool> deleteRecipe() async {
    final ret = await AsyncValue.guard(
        () => ref.read(recipeRepositoryProvider).deleteRecipeById(recipeId));
    // TODO: Mid: pretty unclear error snackbar as consequence.
    // fovoriting kills the whole detail view. maybe align?
    return ret.valueOrNull ?? false;
  }
}
