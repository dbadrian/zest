import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zest/recipes/models/models.dart';

part 'recipe_draft.freezed.dart';
part 'recipe_draft.g.dart';

@freezed
abstract class IngredientDraft with _$IngredientDraft {
  const factory IngredientDraft({
    @JsonKey(name: 'unit_id') required int? unitId,
    @JsonKey(name: 'amount_min') required double? amountMin,
    @JsonKey(name: 'amount_max') required double? amountMax,
    required String food,
    required String? comment,
  }) = _IngredientDraft;

  factory IngredientDraft.fromJson(Map<String, dynamic> json) =>
      _$IngredientDraftFromJson(json);
}

@freezed
abstract class IngredientGroupDraft with _$IngredientGroupDraft {
  const factory IngredientGroupDraft({
    required String? name,
    required List<IngredientDraft> ingredients,
  }) = _IngredientGroupDraft;

  factory IngredientGroupDraft.fromJson(Map<String, dynamic> json) =>
      _$IngredientGroupDraftFromJson(json);
}

@freezed
abstract class RecipeRevisionDraft with _$RecipeRevisionDraft {
  const factory RecipeRevisionDraft({
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
    required List<int> categories,
    @JsonKey(name: 'instruction_groups')
    required List<InstructionGroup> instructionGroups,
    @JsonKey(name: 'ingredient_groups')
    required List<IngredientGroupDraft> ingredientGroups,
  }) = _RecipeRevisionDraft;

  factory RecipeRevisionDraft.fromJson(Map<String, dynamic> json) =>
      _$RecipeRevisionDraftFromJson(json);
}

@freezed
abstract class RecipeDraft with _$RecipeDraft {
  const factory RecipeDraft({
    required String language,
    @JsonKey(name: 'is_private') required bool isPrivate,
    @JsonKey(name: 'is_draft') required bool isDraft,
    @JsonKey(name: 'content') required RecipeRevisionDraft latestRevision,
  }) = _RecipeDraft;

  factory RecipeDraft.fromJson(Map<String, dynamic> json) =>
      _$RecipeDraftFromJson(json);
}
