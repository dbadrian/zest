import 'package:freezed_annotation/freezed_annotation.dart';

import 'food.dart';
import 'unit.dart';

part 'ingredient.freezed.dart';
part 'ingredient.g.dart';

@freezed
// @JsonSerializable(explicitToJson: true, includeIfNull: false)
class Ingredient with _$Ingredient {
  const Ingredient._();
  const factory Ingredient({
    required String amount,
    @JsonKey(name: 'amount_max') String? amountMax,
    required Unit unit,
    required Food food,
    final String? details,
  }) = _Ingredient;

  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      _$IngredientFromJson(json);

  String getAmount() {
    final amount_ = double.parse(double.parse(amount).toStringAsFixed(3));
    return (amountMax != null)
        ? "$amount_-${double.parse(double.parse(amountMax!).toStringAsFixed(3))}"
        : amount_.toString();
  }

  String getUnitAbbreviation({String? matchLanguage}) {
    // Check if abbreviation for desired alnguage is available
    if (unit.abbreviation != null) {
      if (unit.abbreviation!.activeLanguage() == (matchLanguage ?? "")) {
        return unit.abbreviation!.value();
      }
    }

    if (unit.namePlural != null && amount != "1") {
      return unit.namePlural!.value();
    } else {
      return unit.name.value();
    }
  }

  String getFood() {
    return (details != null)
        ? "${food.name.value()}, $details"
        : food.name.value();
  }

  // factory Ingredient.fromJson(Map<String, dynamic> json) {
  //   return _$IngredientFromJson(json);
  // }

  // Map<String, dynamic> toJson() {
  //   return _$IngredientToJson(this);
  // }
}

@freezed
// @JsonSerializable(explicitToJson: true)
class IngredientGroup with _$IngredientGroup {
  factory IngredientGroup({
    required String name,
    required List<Ingredient> ingredients,
  }) = _IngredientGroup;

  factory IngredientGroup.fromJson(Map<String, dynamic> json) =>
      _$IngredientGroupFromJson(json);

  // factory IngredientGroup.fromJson(Map<String, dynamic> json) {
  //   return _$IngredientGroupFromJson(json);
  // }

  // Map<String, dynamic> toJson() {
  //   return _$IngredientGroupToJson(this);
  // }
}
