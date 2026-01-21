import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipe_category.freezed.dart';
part 'recipe_category.g.dart';

@freezed
abstract class RecipeCategory with _$RecipeCategory {
  const factory RecipeCategory({required int id, required String name}) =
      _RecipeCategory;

  factory RecipeCategory.fromJson(Map<String, dynamic> json) =>
      _$RecipeCategoryFromJson(json);
}
