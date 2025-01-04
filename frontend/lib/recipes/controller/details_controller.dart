import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/api/api_service.dart';
import 'package:zest/recipes/models/recipe_favorite.dart';
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
  FutureOr<Recipe?> build(String recipeId) async {
    // set state to loading only for the initial page build
    // afterwards we want silent updates?
    state = const AsyncValue.loading();

    String language = ref.watch(settingsProvider).current.language;
    final recipeValue =
        await AsyncValue.guard(() => _loadRecipe(language: language));
    if (recipeValue.hasError) {
      if (recipeValue.error is AuthException) {
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
      final userId = ref.read(authenticationServiceProvider).value?.user?.id;
      return userId != null ? userId == state.value!.owner : false;
    }
    return false;
  }

  bool isDeleteable() {
    if (state.hasValue) {
      // all values should be not null if user got to this point
      final userId = ref.read(authenticationServiceProvider).value?.user?.id;
      return userId != null ? userId == state.value!.owner : false;
    }
    return false;
  }

  Future<Recipe?> _loadRecipe(
      {String? servings, String? language, bool? toMetric}) async {
    return await ref.read(apiServiceProvider).getRecipe(recipeId,
        servings: servings, toMetric: toMetric, language: language);
  }

  Future<bool> loadRecipe({String? servings}) async {
    final servings_ = servings ?? state.valueOrNull?.servings.toString();
    final ret = await AsyncValue.guard(
        () => _loadRecipe(servings: servings_, toMetric: toMetric));
    if (ret.hasError) {
      if (ret.error is AuthException) {
        openReauthenticationDialog(
            onConfirm: () => loadRecipe(servings: servings));
      } else if (ret.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
      return false;
    }
    state = ret;
    return true;
  }

  Future<bool> reloadRecipe() async {
    toMetric = false;
    final ret = await AsyncValue.guard(() => _loadRecipe(toMetric: false));
    if (ret.hasError) {
      if (ret.error is AuthException) {
        openReauthenticationDialog(onConfirm: () => _loadRecipe());
      } else if (ret.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
      return false;
    }
    state = ret;
    return true;
  }

  Future<RecipeFavorite?> _addRecipeToFavorite() async {
    return await ref
        .read(apiServiceProvider)
        .addRecipeToFavorites(recipeId: recipeId);
  }

  void addToFavorites() async {
    final ret = await AsyncValue.guard(() => _addRecipeToFavorite());

    if (ret.hasError) {
      if (ret.error is AuthException) {
        openReauthenticationDialog(onConfirm: () => _addRecipeToFavorite());
      } else if (ret.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
    }

    final servings_ = state.valueOrNull?.servings.toString();
    final ret2 = await AsyncValue.guard(() => _loadRecipe(servings: servings_));
    if (ret2.hasError) {
      if (ret2.error is AuthException) {
        openReauthenticationDialog(
            onConfirm: () => loadRecipe(servings: servings_));
      } else if (ret2.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
    }
    state = ret2;
  }

  Future<void> _deleteFromFavorites() async {
    await ref
        .read(apiServiceProvider)
        .deleteRecipeFromFavorites(recipeId: recipeId);
  }

  void deleteFromFavorites() async {
    final ret = await AsyncValue.guard(() => _deleteFromFavorites());

    if (ret.hasError) {
      if (ret.error is AuthException) {
        openReauthenticationDialog(onConfirm: () => _deleteFromFavorites());
      } else if (ret.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
    }

    final servings_ = state.valueOrNull?.servings.toString();
    final ret2 = await AsyncValue.guard(() => _loadRecipe(servings: servings_));
    if (ret2.hasError) {
      if (ret2.error is AuthException) {
        openReauthenticationDialog(
            onConfirm: () => loadRecipe(servings: servings_));
      } else if (ret2.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
    }
    state = ret2;
  }

  Future<bool> _deleteRecipe() async {
    return await ref
        .read(apiServiceProvider)
        .deleteRecipeRemote(recipeId: recipeId);
  }

  Future<bool> deleteRecipe() async {
    final ret = await AsyncValue.guard(() => _deleteRecipe());

    if (ret.hasError) {
      if (ret.error is AuthException) {
        openReauthenticationDialog(onConfirm: () => _deleteRecipe());
      } else if (ret.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
    }
    return ret.value ?? false;
  }
}

// class RecipeDetailsController extends StateNotifier<AsyncValue<Recipe>> {
//   RecipeDetailsController({required this.apiService, required this.recipeId})
//       : super(const AsyncValue.loading());
//   final APIService apiService;
//   final String recipeId;
//   final bool toMetric = false;

//   Future<void> loadRecipe({String? servings}) async {
//     state = const AsyncValue.loading();

//     // TODO: replace with custom internal async-guard
//     state = await AsyncValue.guard(() =>
//         apiService.getRecipe(recipeId, servings: servings, toMetric: toMetric));

//     // try {
//     //   _recipe = await apiService.getRecipe(recipeId,
//     //       servings: servings, toMetric: toMetric.value);
//     //   recipe.value = _recipe;
//     //   isInitialized.value = true;
//     //   return true;
//     // } on AuthException {
//     //   openReAuthenticationDialog(onConfirm: () {
//     //     // Get.delete<RecipeDetailsController>();
//     //     // final ctrl =
//     //     //     Get.put<RecipeDetailsController>(RecipeDetailsController(recipeId));
//     //     // Get.rootDelegate.offNamed(Routes.RECIPE_DETAILS(recipeId));
//     //     if (!isInitialized.value) {
//     //       Get.rootDelegate.offNamed(Routes.HOME);
//     //     }
//     //     // isInitialized.value = true;
//     //   });
//     //   return false;
//     // } on ServerNotReachableException {
//     //   openServerNotAvailableDialog(onPressed: () {
//     //     if (!isInitialized.value) {
//     //       Get.rootDelegate.offNamed(Routes.HOME);
//     //     }
//     //   });
//     //   return false;
//     // }
//   }

//   Future<void> reload({String? servings}) async {
//     await loadRecipe(servings: servings);
//   }
// }

// final recipeListProvider =
//     StateNotifierProvider<RecipeDetailsController, AsyncValue<Recipe>>((ref) {
//   return RecipeDetailsController(ref.read(apiServiceProvider));
// });
