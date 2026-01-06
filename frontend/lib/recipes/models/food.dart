import 'package:freezed_annotation/freezed_annotation.dart';

part 'food.freezed.dart';
part 'food.g.dart';

@freezed
abstract class Food with _$Food {
  const factory Food({
    required String name,
    String? description,
    required String language,
    // @JsonKey(name: 'wiki_id') String? wikiId,
    // @JsonKey(name: 'openfooodfacts_id') String? openfoodfactsId,
    // @JsonKey(name: 'usda_ndb_id') String? usdaNdbId,
  }) = _Food;

  factory Food.fromJson(Map<String, dynamic> json) => _$FoodFromJson(json);
}
