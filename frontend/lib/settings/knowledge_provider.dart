import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_service.dart';
import '../authentication/auth_service.dart';
import '../authentication/reauthentication_dialog.dart';
import '../recipes/models/recipe_category.dart';
import '../utils/networking.dart';

part 'knowledge_provider.freezed.dart';
part 'knowledge_provider.g.dart';

@freezed
class KnowledgeState with _$KnowledgeState {
  factory KnowledgeState({
    @Default({}) Map<int, RecipeCategory> validRecipeCategoryChoices,
  }) = _KnowledgeState;
}

@riverpod
class Knowledge extends _$Knowledge {
  @override
  FutureOr<KnowledgeState> build() async {
    final categories = await AsyncValue.guard(() =>
        ref.read(apiServiceProvider).getRecipeCategories(pageSize: 10000));
    if (categories.hasError) {
      if (categories.error is AuthException) {
        openReauthenticationDialog(
            // TODO: onconfirm
            );
      } else if (categories.error is ServerNotReachableException) {
        openServerNotAvailableDialog();
      }
    }
    // express the list as a map
    final validCategories = {for (final e in categories.value!) e.id: e};
    return KnowledgeState(
      validRecipeCategoryChoices: validCategories,
    );
  }
}
