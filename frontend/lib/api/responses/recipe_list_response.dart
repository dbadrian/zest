import 'package:freezed_annotation/freezed_annotation.dart';

import '../../recipes/models/recipe.dart';
import 'pagination.dart';

part 'recipe_list_response.freezed.dart';
part 'recipe_list_response.g.dart';

@freezed
class RecipeListResponse with _$RecipeListResponse {
  factory RecipeListResponse({
    required PaginationResponse pagination,
    required List<Recipe> recipes,
  }) = _RecipeListResponse;

  factory RecipeListResponse.fromJson(Map<String, dynamic> json) =>
      _$RecipeListResponseFromJson(json);

  // Map<String, dynamic> toJson() => _$RecipeListResponseToJson(this);

  @override
  String toString() {
    return 'RecipeListResponse{Lenght: ${recipes.length}}';
  }
}
