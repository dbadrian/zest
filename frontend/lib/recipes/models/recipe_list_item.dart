import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipe_list_item.freezed.dart';
part 'recipe_list_item.g.dart';

/// Lightweight recipe model for list views
@freezed
abstract class RecipeListItem with _$RecipeListItem {
  const factory RecipeListItem({
    required int id,
    required String title,
    String? subtitle,
    required int difficulty,
    @JsonKey(name: 'prep_time') int? prepTime,
    @JsonKey(name: 'cook_time') int? cookTime,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'is_private') required bool isPrivate,
  }) = _RecipeListItem;

  factory RecipeListItem.fromJson(Map<String, dynamic> json) =>
      _$RecipeListItemFromJson(json);

  /// Extract list item from full recipe JSON
  factory RecipeListItem.fromFullRecipe(Map<String, dynamic> json) {
    final revision = json['latest_revision'] as Map<String, dynamic>;
    return RecipeListItem(
      id: json['id'] as int,
      title: revision['title'] as String,
      subtitle: revision['subtitle'] as String?,
      difficulty: revision['difficulty'] as int,
      prepTime: revision['prep_time'] as int?,
      cookTime: revision['cook_time'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isPrivate: json['is_private'] as bool,
    );
  }
}
