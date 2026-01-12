import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/core/network/api_exception.dart';
import 'package:zest/recipes/recipe_repository.dart';
import 'package:zest/settings/settings_provider.dart';

import '../../authentication/auth_service.dart';
import '../../utils/networking.dart';
import '../models/recipe.dart';

part 'details_controller.g.dart';

@riverpod
class RecipeDetailsController extends _$RecipeDetailsController {
  // you can add named or positional parameters to the build method
  @override
  FutureOr<Recipe?> build(int recipeId) async {
    // set state to loading only for the initial page build
    // afterwards we want silent updates?
    state = const AsyncValue.loading();

    String _ = ref.watch(settingsProvider).current.language;
    final recipeValue = await AsyncValue.guard(() => _loadRecipe());
    if (recipeValue.hasError) {
      if (recipeValue.error is ApiException) {
        // TODO: HIGH handle elsewhere?
        // openReauthenticationDialog(onConfirm: loadRecipe);
      } else if (recipeValue.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
      return null;
    } else {
      return Future<Recipe>.value(recipeValue.value);
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

  Future<Recipe?> _addRecipeToFavorite() async {
    return await ref
        .read(recipeRepositoryProvider)
        .addRecipeToFavorites(recipeId);
  }

  void addToFavorites() async {
    final ret = await AsyncValue.guard(() => _addRecipeToFavorite());
    // TODO: HIGH handle errors
    state = ret;
  }

  Future<Recipe?> _deleteFromFavorites() async {
    return await ref
        .read(recipeRepositoryProvider)
        .removeRecipeFromFavorites(recipeId);
  }

  void deleteFromFavorites() async {
    final ret = await AsyncValue.guard(() => _deleteFromFavorites());
    state = ret;
    // if (ret.hasError) {
    //   if (ret.error is ApiException) {
    //     openReauthenticationDialog(onConfirm: () => _deleteFromFavorites());
    //   } else if (ret.error is ServerNotReachableException) {
    //     openServerNotAvailableDialog();
    //   }
    // }

    // final servings_ = state.valueOrNull?.servings.toString();
    // final ret2 = await AsyncValue.guard(() => _loadRecipe(servings: servings_));
    // if (ret2.hasError) {
    //   if (ret2.error is ApiException) {
    //     openReauthenticationDialog(
    //         onConfirm: () => loadRecipe(servings: servings_));
    //   } else if (ret2.error is ServerNotReachableException) {
    //     openServerNotAvailableDialog();
    //   }
    // }
    // state = ret2;
  }

  Future<bool> _deleteRecipe() async {
    return await ref.read(recipeRepositoryProvider).deleteRecipeById(recipeId);
  }

  Future<bool> deleteRecipe() async {
    final ret = await AsyncValue.guard(() => _deleteRecipe());

    if (ret.hasError) {
      if (ret.error is ApiException) {
        // TODO: HIGH handle reauth elsewhere
        // openReauthenticationDialog(onConfirm: () => _deleteRecipe());
      } else if (ret.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
    }
    return ret.value ?? false;
  }
}
