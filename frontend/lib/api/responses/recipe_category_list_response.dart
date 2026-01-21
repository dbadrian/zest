library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zest/api/responses/responses.dart';

import 'package:zest/recipes/models/recipe_category.dart';

part 'recipe_category_list_response.freezed.dart';
part 'recipe_category_list_response.g.dart';

@freezed
class RecipeCategoryListResponse with _$RecipeCategoryListResponse {
  factory RecipeCategoryListResponse({
    required PaginationMeta pagination,
    required List<RecipeCategory> results,
  }) = _RecipeCategoryListResponse;

  factory RecipeCategoryListResponse.fromJson(Map<String, dynamic> json) =>
      _$RecipeCategoryListResponseFromJson(json);

  @override
  String toString() {
    return 'RecipeCategoryListResponse{Lenght: ${results.length}}';
  }
}
