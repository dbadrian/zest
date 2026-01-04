import 'dart:async';
import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/api/api_service.dart';
import 'package:zest/api/responses/pagination.dart';
import 'package:zest/api/responses/responses.dart';
import 'package:zest/core/cache/cache_providers.dart';
import 'package:zest/core/providers/http_client_provider.dart';

import '../../../core/cache/cache_manager.dart';
import '../../../core/cache/cache_entry.dart';
import '../../../core/cache/cache_strategy.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/api_response.dart';

import 'package:zest/recipes/models/recipe_list_item.dart';

import 'models/recipe.dart';

part 'recipe_repository.g.dart';

class RecipeRepository {
  final APIService _client;
  final CacheManager<RecipeListItem> _listCache;
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

  Future<bool> deleteRecipeById(int recipeId) async {
    return await _client.deleteRecipeById(recipeId);
  }

  Future<RecipeSearchListResponse> searchRecipes(String query) async {
    return await _client.searchRecipes(query);
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
