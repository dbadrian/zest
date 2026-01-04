library zest.api;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../recipes/models/food.dart';
import 'pagination.dart';

part 'food_list_response.freezed.dart';
part 'food_list_response.g.dart';

@freezed
class FoodListResponse with _$FoodListResponse {
  factory FoodListResponse({
    required PaginationMeta pagination,
    required List<Food> results,
  }) = _FoodListResponse;

  factory FoodListResponse.fromJson(Map<String, dynamic> json) =>
      _$FoodListResponseFromJson(json);

  @override
  String toString() {
    return 'FoodListResponse{Lenght: ${results.length}}';
  }
}
