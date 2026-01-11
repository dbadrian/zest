import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/core/network/api_exception.dart';
import 'package:zest/recipes/recipe_repository.dart';
import 'package:zest/settings/settings_provider.dart';

import '../../authentication/auth_service.dart';
import '../../authentication/reauthentication_dialog.dart';
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
        openReauthenticationDialog(onConfirm: loadRecipe);
      } else if (recipeValue.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
      return null;
    } else {
      return Future<Recipe>.value(recipeValue.value);
    }
  }

  // TODO: Public getter/setter -> not recommended
  bool toMetric = false;

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

  Future<bool> loadRecipe({String? servings}) async {
    var ret = await AsyncValue.guard(() => _loadRecipe());
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

    state = ret;
    return true;
  }

  double? tryMultiply(double? a, double ratio) {
    if (a == null) {
      return a;
    }

    return a * ratio;
  }

  Future<bool> reloadRecipe() async {
    toMetric = false;
    final ret = await AsyncValue.guard(() => _loadRecipe());
    if (ret.hasError) {
      if (ret.error is ApiException) {
        openReauthenticationDialog(onConfirm: () => _loadRecipe());
      } else if (ret.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
      return false;
    }
    state = ret;
    return true;
  }

  // Future<bool> translateRecipe() async {
  //   if (!state.hasValue) {
  //     return false;
  //   }

  //   final oldState = state.value!;
  //   state = AsyncValue.loading();

  //   await ref.read(geminiRequestProvider.notifier).translateRecipe(
  //         GeminiTranslateRequest(
  //           recipeData: state.value!,
  //           targetLanguage: "cz", // TODO: Hardcoded
  //           schema: recipeTranslationSchema,
  //         ),
  //       );

  //   final response = ref.read(geminiRequestProvider).asData?.value;
  //   if (response?.structuredData != null) {
  //     try {
  //       final cleanedData = response!.structuredData!;
  //       cleanedData.remove("categories");
  //       // manually remove the categories
  //       // TODO: Fix this, when the backend API is less shit

  //       final newRecipeJson = mergeMaps(state.value!.toJson(), cleanedData);
  //       final newRecipe = Recipe.fromJson(newRecipeJson);

  //       // patch in categories from before...
  //       final finalRecipe =
  //           newRecipe.copyWith(categories: state.value!.categories);

  //       state = AsyncValue.data(finalRecipe);
  //       // state = AsyncValue.data(oldState);
  //     } catch (e) {
  //       debugPrint("Invalid JSON: $e");
  //     }
  //   } else {
  //     debugPrint("Failed to translate recipe");
  //     // TODO: SnackBar
  //     state = AsyncValue.data(oldState);
  //   }

  //   // // Process the result
  //   // final response = ref.read(geminiRequestProvider).asData?.value;
  //   // if (response?.structuredData != null) {
  //   //   try {
  //   //     final instructionGroups =
  //   //         (response?.structuredData?["instruction_groups"] as List<dynamic>)
  //   //             .map((e) => InstructionGroup.fromJson(e))
  //   //             .toList();
  //   //     //      ??
  //   //     // List<InstructionGroup>.empty();

  //   //     if (response?.structuredData?.containsKey("ingredient_groups") !=
  //   //         null) {
  //   //       final translated_ingredients =
  //   //           response!.structuredData!["ingredient_groups"];
  //   //       final ingredientGroups =
  //   //           state.value!.ingredientGroups.asMap().map((idx, value) {
  //   //         value.copyWith(name: translated_ingredients[idx]["name"]);
  //   //       });
  //   //     }

  //   //     final recipeCopy = state.value!.copyWith(
  //   //         title: response?.structuredData?["title"] ?? state.value!.title,
  //   //         subtitle:
  //   //             response?.structuredData?["subtitle"] ?? state.value!.subtitle,
  //   //         ownerComment: response?.structuredData?["owner_comment"] ??
  //   //             state.value!.language,
  //   //         language:
  //   //             response?.structuredData?["language"] ?? state.value!.language,
  //   //         isTranslation: true,
  //   // //         instructionGroups: instructionGroups);
  //   //     state = AsyncValue.data(recipeCopy);
  //   //   } catch (e) {
  //   //     debugPrint("Invalid JSON: $e");
  //   //   }
  //   // } else {
  //   //   debugPrint("Failed to translate recipe");
  //   // }

  //   return true;
  // }

  Future<Recipe?> _addRecipeToFavorite() async {
    return await ref
        .read(recipeRepositoryProvider)
        .addRecipeToFavorites(recipeId);
  }

  void addToFavorites() async {
    final ret = await AsyncValue.guard(() => _addRecipeToFavorite());
    state = ret;

    // if (ret.hasError) {
    //   if (ret.error is ApiException) {
    //     openReauthenticationDialog(onConfirm: () => _addRecipeToFavorite());
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
        openReauthenticationDialog(onConfirm: () => _deleteRecipe());
      } else if (ret.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
    }
    return ret.value ?? false;
  }
}
