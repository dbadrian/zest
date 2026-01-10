import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/api/api_service.dart';
import 'package:zest/api/responses/responses.dart';
import 'package:zest/core/cache/cache_providers.dart';
import 'package:zest/recipes/models/recipe_draft.dart';

import '../../../core/cache/cache_manager.dart';

import 'package:zest/recipes/models/recipe_list_item.dart';

import 'models/recipe.dart';

part 'recipe_repository.g.dart';

class RecipeRepository {
  final APIService _client;
  // ignore: unused_field
  final CacheManager<RecipeListItem> _listCache;
  // ignore: unused_field
  final CacheManager<Recipe> _fullRecipeCache;

  RecipeRepository({
    required APIService client,
    required CacheManager<RecipeListItem> listCache,
    required CacheManager<Recipe> fullRecipeCache,
  })  : _client = client,
        _listCache = listCache,
        _fullRecipeCache = fullRecipeCache;

  Future<RecipeListResponse> getRecipes(
      {int page = 1, int? pageSize, bool forceRefresh = false}) async {
    // TODO: implement caching online/offline usage
    return await _client.getRecipes(page: page, pageSize: pageSize);
  }

  Future<Recipe?> getRecipeById(int recipeId,
      {bool forceRefresh = false}) async {
    // TODO: implement caching online/offline usage
    return await _client.getRecipeById(recipeId);
  }

  Future<Recipe?> createRecipe(RecipeDraft draft) async {
    return await _client.createRecipe(draft);
  }

  Future<Recipe?> updateRecipe(int recipeId, RecipeDraft draft) async {
    return await _client.updateRecipe(recipeId, draft);
  }

  Future<bool> deleteRecipeById(int recipeId) async {
    return await _client.deleteRecipeById(recipeId);
  }

  Future<Recipe?> addRecipeToFavorites(int recipeId) async {
    return await _client.addRecipeToFavorites(recipeId);
  }

  Future<Recipe?> removeRecipeFromFavorites(int recipeId) async {
    return await _client.removeRecipeFromFavorites(recipeId);
  }

  Future<RecipeSearchListResponse> searchRecipes(
    String query, {
    List<String>? languages,
    List<String>? categories,
  }) async {
    return await _client.searchRecipes(query,
        languages: languages, categories: categories);
  }
}

@Riverpod(keepAlive: true)
RecipeRepository recipeRepository(Ref ref) {
  return RecipeRepository(
    client: ref.watch(apiServiceProvider),
    listCache: ref.watch(recipeListCacheManagerProvider),
    fullRecipeCache: ref.watch(recipeFullCacheManagerProvider),
  );
}

@riverpod
Future<Recipe?> recipes(Ref ref, int recipeId) async {
  final repo = ref.read(recipeRepositoryProvider);
  return repo.getRecipeById(recipeId);
}
