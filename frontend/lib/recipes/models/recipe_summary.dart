library zest.api;

import 'package:json_annotation/json_annotation.dart';

part 'recipe_summary.g.dart';

@JsonSerializable(explicitToJson: true)
class RecipeSummary {
  String id;

  @JsonKey(name: 'recipe_id')
  String recipeId;

  @JsonKey(name: 'date_created')
  DateTime dateCreated;
  String owner;
  String title;
  String subtitle;

  int? difficulty;
  int? servings;

  @JsonKey(name: 'prep_time')
  int? prepTime;
  @JsonKey(name: 'cook_time')
  int? cookTime;
  @JsonKey(name: 'total_time')
  int? totalTime;

  RecipeSummary(
      this.id,
      this.recipeId,
      this.dateCreated,
      this.owner,
      this.title,
      this.subtitle,
      this.difficulty,
      this.servings,
      this.prepTime,
      this.cookTime,
      this.totalTime);

  factory RecipeSummary.fromJson(Map<String, dynamic> json) {
    return _$RecipeSummaryFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$RecipeSummaryToJson(this);
  }
}
