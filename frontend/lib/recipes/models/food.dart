import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zest/recipes/models/translated_field.dart';

// import 'translated_field.dart';

part 'food.freezed.dart';
part 'food.g.dart';

@freezed
@JsonSerializable(explicitToJson: true)
class NutritionalValue with _$NutritionalValue {
  factory NutritionalValue({
    int? kcal,
    @JsonKey(name: 'total_fat') double? totalFat,
    @JsonKey(name: 'saturated_fat') double? saturatedFat,
    @JsonKey(name: 'polyunsaturated_fat') double? polyunsaturatedFat,
    @JsonKey(name: 'monounsaturated_fat') double? monounsaturatedFat,
    double? cholestoral,
    double? sodium,
    @JsonKey(name: 'total_carbohydrates') double? totalCarbohydrates,
    @JsonKey(name: 'carbohydrate_dietary_fiber')
    double? carbohydrateDietaryFiber,
    @JsonKey(name: 'carbohydrate_sugar') double? carbohydrateSugar,
    double? protein,
    double? lactose,
    double? fructose,
    double? glucose,
  }) = _NutritionalValue;

  // factory NutritionalValue.fromJson(Map<String, dynamic> json) {
  //   return _$NutritionalValueFromJson(json);
  // }

  // Map<String, dynamic> toJson() {
  //   return _$NutritionalValueToJson(this);
  // }
}

@freezed
class FoodSynonym with _$FoodSynonym {
  factory FoodSynonym({
    required String id,
    required String name,
    required String language,
    required String food,
    @JsonKey(includeToJson: false) double? similarity,
  }) = _FoodSynonym;

  factory FoodSynonym.fromJson(Map<String, dynamic> json) =>
      _$FoodSynonymFromJson(json);
}

@freezed
// @JsonSerializable(explicitToJson: true)
class Food extends Object with _$Food {
  factory Food({
    required String id,
    required TranslatedField name,
    TranslatedField? description,
    @Default([]) nutrients,
    @Default([]) List<FoodSynonym> synonyms,
    @JsonKey(includeToJson: false) double? similarity,
  }) = _Food;

  factory Food.fromJson(Map<String, dynamic> json) => _$FoodFromJson(json);

  // Map<String, dynamic> toJsonExplicit() => <String, dynamic>{
  //       'id': id,
  //       'name': name.toJson(),
  //     };

  // String toJson() {
  //   return id;
  // }
}
