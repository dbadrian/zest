import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipe_favorite.freezed.dart';
part 'recipe_favorite.g.dart';

@freezed
// @JsonSerializable(explicitToJson: true)
class RecipeFavorite with _$RecipeFavorite {
  factory RecipeFavorite(
      {required String id,
      required String recipe,
      required String user}) = _RecipeFavorite;

  factory RecipeFavorite.fromJson(Map<String, dynamic> json) =>
      _$RecipeFavoriteFromJson(json);
}
