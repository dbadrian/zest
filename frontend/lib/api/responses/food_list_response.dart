library zest.api;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../recipes/models/food.dart';
import 'pagination.dart';

part 'food_list_response.freezed.dart';
part 'food_list_response.g.dart';

@freezed
class FoodListResponse with _$FoodListResponse {
  factory FoodListResponse({
    required PaginationResponse pagination,
    required List<Food> foods,
  }) = _FoodListResponse;

  factory FoodListResponse.fromJson(Map<String, dynamic> json) =>
      _$FoodListResponseFromJson(json);

  @override
  String toString() {
    return 'FoodListResponse{Lenght: ${foods.length}}';
  }
}

@freezed
class FoodSynonymsListResponse with _$FoodSynonymsListResponse {
  factory FoodSynonymsListResponse({
    required PaginationResponse pagination,
    @JsonKey(name: 'food_synonyms') required List<FoodSynonym> foodSynonyms,
  }) = _FoodSynonymsListResponse;

  factory FoodSynonymsListResponse.fromJson(Map<String, dynamic> json) =>
      _$FoodSynonymsListResponseFromJson(json);

  @override
  String toString() {
    return 'FoodListResponse{Lenght: ${foodSynonyms.length}}';
  }
}
