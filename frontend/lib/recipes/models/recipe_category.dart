import 'package:freezed_annotation/freezed_annotation.dart';

import 'translated_field.dart';

part 'recipe_category.freezed.dart';
part 'recipe_category.g.dart';

@freezed
// @JsonSerializable(explicitToJson: true, includeIfNull: false)
class RecipeCategory with _$RecipeCategory {
  @JsonSerializable(explicitToJson: true)
  factory RecipeCategory({
    required int id,
    @JsonKey(includeToJson: false) TranslatedField? name,
    @JsonKey(name: "name_plural", includeToJson: false)
    TranslatedField? namePlural,
  }) = _RecipeCategory;

  factory RecipeCategory.fromJson(Map<String, dynamic> json) =>
      _$RecipeCategoryFromJson(json);
}
