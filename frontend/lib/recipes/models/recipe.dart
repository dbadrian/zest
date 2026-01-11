import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zest/recipes/models/models.dart';

part 'recipe.freezed.dart';
part 'recipe.g.dart';

@freezed
abstract class Ingredient with _$Ingredient {
  const factory Ingredient({
    required String? food,
    @JsonKey(name: 'amount_min') required double? amountMin,
    @JsonKey(name: 'amount_max') required double? amountMax,
    required String? comment,
    required Unit? unit,
  }) = _Ingredient;

  const Ingredient._();
  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      _$IngredientFromJson(json);

  bool hasMetricConversion() {
    if (unit != null &&
        unit!.unitSystem != "Metric" &&
        unit!.unitSystem.isNotEmpty) {
      return true;
    }
    return false;
  }
}

@freezed
abstract class IngredientGroup with _$IngredientGroup {
  const factory IngredientGroup({
    required String? name,
    required List<Ingredient> ingredients,
  }) = _IngredientGroup;

  factory IngredientGroup.fromJson(Map<String, dynamic> json) =>
      _$IngredientGroupFromJson(json);
}

@freezed
abstract class InstructionGroup with _$InstructionGroup {
  const factory InstructionGroup({
    required String? name,
    required String instructions,
  }) = _InstructionGroup;

  factory InstructionGroup.fromJson(Map<String, dynamic> json) =>
      _$InstructionGroupFromJson(json);
}

@freezed
abstract class RecipeRevision with _$RecipeRevision {
  const factory RecipeRevision({
    required String? title,
    required String? subtitle,
    @JsonKey(name: 'owner_comment') required String? ownerComment,
    required int? difficulty,
    required int? servings,
    @JsonKey(name: 'prep_time') required int? prepTime,
    @JsonKey(name: 'cook_time') required int? cookTime,
    @JsonKey(name: 'source_name') required String? sourceName,
    @JsonKey(name: 'source_page') required String? sourcePage,
    @JsonKey(name: 'source_url') required String? sourceUrl,
    required List<RecipeCategory> categories,
    @JsonKey(name: 'instruction_groups')
    required List<InstructionGroup> instructionGroups,
    @JsonKey(name: 'ingredient_groups')
    required List<IngredientGroup> ingredientGroups,
  }) = _RecipeRevision;

  const RecipeRevision._();

  factory RecipeRevision.fromJson(Map<String, dynamic> json) =>
      _$RecipeRevisionFromJson(json);

  int? totalTime() {
    if (prepTime == null && cookTime == null) {
      return null;
    }

    return (prepTime ?? 0) + (cookTime ?? 0);
  }
}

@freezed
abstract class Recipe with _$Recipe {
  const factory Recipe({
    required int id,
    required String language,
    @JsonKey(name: 'owner_id') required String ownerId,
    @JsonKey(name: 'is_private') required bool isPrivate,
    @JsonKey(name: 'is_draft') required bool isDraft,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'is_favorited') required bool isFavorited,
    @JsonKey(name: 'latest_revision') required RecipeRevision latestRevision,
  }) = _Recipe;

  const Recipe._();
  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);

  bool hasMetricConversion() {
    for (final g in latestRevision.ingredientGroups) {
      for (final i in g.ingredients) {
        if (i.hasMetricConversion()) {
          return true;
        }
      }
    }
    return false;
  }
}

@freezed
abstract class RecipeListView with _$RecipeListView {
  const factory RecipeListView({
    required int id,
    required String language,
    @JsonKey(name: 'owner_id') required String ownerId,
    @JsonKey(name: 'is_private') required bool isPrivate,
    @JsonKey(name: 'is_draft') required bool isDraft,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    required String? title,
    required String? subtitle,
    required int? servings,
    required int? difficulty,
    @JsonKey(name: 'is_favorited') required bool isFavorited,
    @JsonKey(name: 'owner_comment') required String? ownerComment,
    @JsonKey(name: 'prep_time') required int? prepTime,
    @JsonKey(name: 'cook_time') required int? cookTime,
    required List<String> categories,
  }) = _RecipeListView;

  factory RecipeListView.fromJson(Map<String, dynamic> json) =>
      _$RecipeListViewFromJson(json);
}
