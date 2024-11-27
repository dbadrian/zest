import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'translated_field.dart';

part 'unit.freezed.dart';
part 'unit.g.dart';

@freezed
// @JsonSerializable(explicitToJson: true, includeIfNull: false)
class Unit with _$Unit {
  factory Unit({
    required int id,
    @JsonKey(includeToJson: true) required TranslatedField name,
    @JsonKey(name: 'name_plural', includeToJson: true)
    TranslatedField? namePlural,
    @JsonKey(includeToJson: true) TranslatedField? abbreviation,
    @JsonKey(name: 'base_unit', includeToJson: true) String? baseUnit,
    @JsonKey(name: 'conversion_factor', includeToJson: true)
    String? conversionFactor,
    @JsonKey(name: 'unit_system', includeToJson: true) String? unitSystem,
    @JsonKey(name: 'has_conversion', includeToJson: true)
    required bool hasConversion,
    @JsonKey(name: 'is_metric', includeToJson: true) required bool isMetric,
    @JsonKey(name: 'is_imperial', includeToJson: true) required bool isImperial,
    @JsonKey(name: 'is_us', includeToJson: true) required bool isUS,
  }) = _Unit;

  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);
}
