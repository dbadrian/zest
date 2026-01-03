import 'package:freezed_annotation/freezed_annotation.dart';

import 'recipe_list_item.dart';

part 'recipe_full.freezed.dart';

/// Full recipe with raw JSON stored separately
/// We don't parse the full nested structure, just wrap the JSON
@freezed
abstract class RecipeFull with _$RecipeFull {
  const factory RecipeFull({
    required int id,
    required Map<String, dynamic> rawJson,
    required DateTime cachedAt,
  }) = _RecipeFull;

  const RecipeFull._();

  /// Get list item from full recipe
  RecipeListItem toListItem() {
    return RecipeListItem.fromFullRecipe(rawJson);
  }

  /// Access specific fields without full parsing
  String get title =>
      (rawJson['latest_revision'] as Map<String, dynamic>)['title'] as String;

  String? get subtitle =>
      (rawJson['latest_revision'] as Map<String, dynamic>)['subtitle']
          as String?;

  int get difficulty =>
      (rawJson['latest_revision'] as Map<String, dynamic>)['difficulty'] as int;

  List<dynamic> get ingredientGroups =>
      (rawJson['latest_revision'] as Map<String, dynamic>)['ingredient_groups']
          as List<dynamic>;

  List<dynamic> get instructionGroups =>
      (rawJson['latest_revision'] as Map<String, dynamic>)['instruction_groups']
          as List<dynamic>;
}
