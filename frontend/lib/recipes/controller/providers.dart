import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/api/responses/multilingual_data_response.dart';
import 'package:zest/recipes/models/food.dart';
import 'package:zest/recipes/models/recipe.dart';
import 'package:zest/recipes/models/recipe_category.dart';
import 'package:zest/recipes/models/unit.dart';
import 'package:zest/recipes/recipe_repository.dart';
import 'package:zest/recipes/static_data_repository.dart';
import 'package:zest/settings/settings_provider.dart';
import 'package:zest/utils/languages.dart';

part 'providers.g.dart';

class RecipeFormData {
  final List<RecipeCategory> categories;
  final List<Unit> units;
  final List<Food> foods;
  final Map<String, dynamic> currentLanguageData;
  final Map<String, String> localizedLanguageNames;

  RecipeFormData(
      {required this.categories,
      required this.units,
      required this.foods,
      required this.currentLanguageData,
      required this.localizedLanguageNames});
}

@riverpod
Future<RecipeFormData> recipeStaticData(Ref ref) async {
  final repo = ref.watch(staticRepositoryProvider);
  final language =
      ref.watch(settingsProvider.select((s) => s.current.language));

  final localizedLanguages = await getLocalizedLanguages(language);

  // load all resources in parallel
  final results = await Future.wait([
    repo.getCategories(),
    repo.getUnits(),
    repo.getFoods(),
    repo.getMultilingualData()
  ]);

  final mld = results[3] as MultilingualData;
  final currentLanguageData = mld.getByLanguage(language);

  return RecipeFormData(
    categories: results[0] as List<RecipeCategory>,
    units: results[1] as List<Unit>,
    foods: results[2] as List<Food>,
    currentLanguageData: currentLanguageData,
    localizedLanguageNames: localizedLanguages,
  );
}

@riverpod
Future<(RecipeFormData, Recipe?)> staticAndRecipeData(Ref ref,
    {int? recipeId}) async {
  final staticData = await ref.watch(recipeStaticDataProvider.future);

  Recipe? recipe;
  if (recipeId != null) {
    recipe = await ref.read(recipesProvider(recipeId).future);
  }

  return (staticData, recipe);
}
