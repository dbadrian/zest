import 'package:freezed_annotation/freezed_annotation.dart';

import '../../recipes/models/recipe_category.dart';
import 'pagination.dart';

part 'recipe_categories_list_response.freezed.dart';
part 'recipe_categories_list_response.g.dart';

@freezed
class RecipeCategoryListResponse with _$RecipeCategoryListResponse {
  factory RecipeCategoryListResponse({
    required PaginationResponse pagination,
    @JsonKey(name: 'recipe_categories')
    required List<RecipeCategory> categories,
  }) = _RecipeCategoryListResponse;

  factory RecipeCategoryListResponse.fromJson(Map<String, dynamic> json) =>
      _$RecipeCategoryListResponseFromJson(json);
}
