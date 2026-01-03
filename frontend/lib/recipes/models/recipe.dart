import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zest/recipes/models/models.dart';

part 'recipe.freezed.dart';
part 'recipe.g.dart';

@freezed
abstract class RecipeRevision with _$RecipeRevision {
  const factory RecipeRevision({
    required String title,
    required String? subtitle,
    @JsonKey(name: 'owner_comment') required String? ownerComment,
    required int difficulty,
    required int? servings,
    @JsonKey(name: 'prep_time') required int? prepTime,
    @JsonKey(name: 'cook_time') required int? cookTime,
    required List<RecipeCategory> categories,
  }) = _RecipeRevision;

  factory RecipeRevision.fromJson(Map<String, dynamic> json) =>
      _$RecipeRevisionFromJson(json);
}

@freezed
abstract class Recipe with _$Recipe {
  const factory Recipe({
    required int id,
    required String language,
    @JsonKey(name: 'is_private') required bool isPrivate,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'latest_revision') required RecipeRevision latestRevision,
  }) = _Recipe;

  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);
}
