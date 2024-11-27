import 'package:freezed_annotation/freezed_annotation.dart';

import 'ingredient.dart';
import 'instruction.dart';
import 'recipe_category.dart';
import 'tag.dart';

part 'recipe.freezed.dart';
part 'recipe.g.dart';

@freezed
// @JsonSerializable(explicitToJson: true, includeIfNull: false)
class Recipe with _$Recipe {
  const Recipe._();
  @JsonSerializable(explicitToJson: true)
  factory Recipe({
    String? id,
    @JsonKey(name: 'recipe_id') required String recipeId,
    @JsonKey(name: 'original_recipe_id') String? originalRecipeId,
    @JsonKey(name: 'date_created') required DateTime dateCreated,
    required String owner,
    required String? language,
    required String title,
    String? subtitle,
    required bool private,
    @JsonKey(name: 'owner_comment') required String? ownerComment,
    required List<Tag> tags,
    required List<RecipeCategory> categories,
    int? difficulty,
    required int servings,
    @JsonKey(name: 'prep_time') int? prepTime,
    @JsonKey(name: 'cook_time') int? cookTime,
    @JsonKey(name: 'total_time') int? totalTime,
    @JsonKey(name: 'is_up_to_date', defaultValue: false) bool? isUpToDate,
    @JsonKey(name: 'is_translation') bool? isTranslation,
    @JsonKey(name: 'is_favorite') bool? isFavorite,
    @JsonKey(name: 'source_name') String? sourceName,
    @JsonKey(name: 'source_page') int? sourcePage,
    @JsonKey(name: 'source_url') String? sourceUrl,
    @JsonKey(name: 'ingredient_groups')
    @freezed
    required List<IngredientGroup> ingredientGroups,
    @JsonKey(name: 'instruction_groups')
    required List<InstructionGroup> instructionGroups,
  }) = _Recipe;

  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);

  bool hasMetricConversion() {
    // Returns True, if recipe contains one ingredient that has a conversion
    for (final group in ingredientGroups) {
      for (final ingredient in group.ingredients) {
        final unit = ingredient.unit;
        if (!unit.isMetric && unit.hasConversion) return true;
        // if (unit.hasConversion) return true;
      }
    }
    // no unit that can be converted
    return false;
  }
}
