import 'package:freezed_annotation/freezed_annotation.dart';

part 'unit.freezed.dart';
part 'unit.g.dart';

@freezed
abstract class Unit with _$Unit {
  const factory Unit({
    required int id,
    required String name,
    @JsonKey(name: 'base_unit') String? baseUnit,
    @JsonKey(name: 'unit_system') required String unitSystem,
    @JsonKey(name: 'conversion_factor') double? conversionFactor,
  }) = _Unit;

  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);
}
