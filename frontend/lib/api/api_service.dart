import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/api/responses/multilingual_data_response.dart';
import 'package:zest/api/responses/recipe_category_list_response.dart';
import 'package:zest/core/network/http_client.dart';
import 'package:zest/core/providers/http_client_provider.dart';
import 'package:zest/recipes/models/recipe_draft.dart';

import 'package:zest/utils/networking.dart';

import '../recipes/models/models.dart';
import 'responses/responses.dart';

part 'api_service.g.dart';

class APIService {
  final ApiHttpClient client;
  final Ref ref;

  APIService({required this.ref, required this.client});

  //////////////////////////////////////////////////////////////////////////////
  /// RECIPES REQUESTS
  //////////////////////////////////////////////////////////////////////////////

  Future<RecipeListResponse> getRecipes({int page = 1, int? pageSize}) async {
    final queryParameters = {
      "page": page.toString(),
      if (pageSize != null) 'page_size': pageSize.toString(),
    };

    final response = await client.get<RecipeListResponse>(
        "/recipes", RecipeListResponse.fromJson,
        queryParams: queryParameters);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<RecipeSearchListResponse> searchRecipes(
    String query, {
    int page = 1,
    int? pageSize = 50,
    List<String>? categories,
    List<String>? languages,
  }) async {
    final queryParameters = {
      "q": query,
      "page": page.toString(),
      if (pageSize != null) 'page_size': pageSize.toString(),
      if (categories != null && categories.isNotEmpty) 'categories': categories,
      if (languages != null) 'languages': languages,
    };

    final response = await client.get<RecipeSearchListResponse>(
        "/recipes/search", RecipeSearchListResponse.fromJson,
        queryParams: queryParameters);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<Recipe> getRecipeById(int recipeId) async {
    final response =
        await client.get<Recipe>("/recipes/$recipeId", Recipe.fromJson);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<Recipe?> updateRecipe(int recipeId, RecipeDraft recipe) async {
    final response = await client.put<Recipe>(
        "/recipes/$recipeId", Recipe.fromJson,
        body: recipe.toJson());

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<Recipe?> createRecipe(RecipeDraft recipe) async {
    final response = await client.post<Recipe>("/recipes", Recipe.fromJson,
        body: recipe.toJson());

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<Recipe?> saveRecipeDraft(RecipeDraft recipe) async {
    return null;
    // final response = await client.post<Recipe>("/recipes", Recipe.fromJson,
    //     body: recipe.toJson());

    // if (response.isSuccess) {
    //   return response.dataOrNull!;
    // } else {
    //   throw response.errorOrNull!;
    // }
  }

  Future<bool> deleteRecipeById(int recipeId) async {
    final response = await client.delete<Null>("/recipes/$recipeId", null);
    return response.isSuccess;
  }

  Future<Recipe?> addRecipeToFavorites(int recipeId) async {
    final response = await client.post<Recipe>(
        "/recipes/$recipeId/favorites", Recipe.fromJson);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<Recipe?> removeRecipeFromFavorites(int recipeId) async {
    final response = await client.delete<Recipe>(
        "/recipes/$recipeId/favorites", Recipe.fromJson);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// RECIPE STATIC DATA
  //////////////////////////////////////////////////////////////////////////////
  Future<RecipeCategoryListResponse> getRecipeCategories(
      {int page = 1, int? pageSize}) async {
    final queryParameters = {
      "page": page.toString(),
      if (pageSize != null) 'page_size': pageSize.toString(),
    };
    final response = await client.get<RecipeCategoryListResponse>(
        "/recipes/categories", RecipeCategoryListResponse.fromJson,
        queryParams: queryParameters);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<FoodListResponse> getRecipeFoodCandidates(
      {int page = 1, int? pageSize}) async {
    final queryParameters = {
      "page": page.toString(),
      if (pageSize != null) 'page_size': pageSize.toString(),
    };
    final response = await client.get<FoodListResponse>(
        "/recipes/foods", FoodListResponse.fromJson,
        queryParams: queryParameters);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<FoodSearchListResponse> searchFoods(
    String query, {
    int page = 1,
    int? pageSize = 50,
    List<String>? languages,
  }) async {
    final queryParameters = {
      "q": query,
      "page": page.toString(),
      if (pageSize != null) 'page_size': pageSize.toString(),
      if (languages != null && languages.isNotEmpty) 'languages': languages,
    };

    final response = await client.get<FoodSearchListResponse>(
        "/recipes/foods/search", FoodSearchListResponse.fromJson,
        queryParams: queryParameters);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<UnitListResponse> getRecipeUnits({int page = 1, int? pageSize}) async {
    final queryParameters = {
      "page": page.toString(),
      if (pageSize != null) 'page_size': pageSize.toString(),
    };
    final response = await client.get<UnitListResponse>(
        "/recipes/units", UnitListResponse.fromJson,
        queryParams: queryParameters);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }

  Future<MultilingualData> getMultilingualData() async {
    final response = await client.get<MultilingualData>(
        "/recipes/multilingual", MultilingualData.fromJson);

    if (response.isSuccess) {
      return response.dataOrNull!;
    } else {
      throw response.errorOrNull!;
    }
  }
}

@Riverpod(keepAlive: true)
APIService apiService(Ref ref) => APIService(
      ref: ref,
      client: ref.watch(apiClientProvider),
    );

// //////////////////////////////////////////////////////////////////////////////
// /// GITHUB REQUESTS
// //////////////////////////////////////////////////////////////////////////////

class GithubService {
  final Client client;
  final Ref ref;

  GithubService({required this.ref, required this.client});

  Future<String?> getLatestVersion({bool withoutLeadingV = true}) async {
    const url = "https://api.github.com/repos/dbadrian/zest/releases/latest";
    const headers = {
      "Accept": "application/vnd.github.v3+json",
      "X-GitHub-Api-Version": "2022-11-28",
    };

    // final ret = await client.get(Uri.parse(url), headers: headers);
    try {
      return genericResponseHandler(
        requestCallback: () async =>
            client.get(Uri.parse(url), headers: headers),
        create: (json) {
          // check if tag_name is in the json
          if (json.containsKey("tag_name")) {
            if (withoutLeadingV) {
              return json["tag_name"].toString().substring(1);
            }
            return json["tag_name"].toString();
          }
          return null;
        },
      );

      // on AuthException {
      //   developer.log("Triggered an auth exception",
      //       name: 'APIservice.updateRecipeRemote');
      //   // Get.offNamed(Get.currentRoute);
      //   throw AuthException();
      // } on ResourceNotFoundException catch (e) {
      //   developer.log("ResourceNotFound: ${e.message}");
      //   return null;
    } on Exception {
      // developer.log("BadRequest: ${e.message}");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getLatestAssetList(
      {bool withoutLeadingV = true}) async {
    const url = "https://api.github.com/repos/dbadrian/zest/releases/latest";
    const headers = {
      "Accept": "application/vnd.github.v3+json",
      "X-GitHub-Api-Version": "2022-11-28",
    };

    // final ret = await client.get(Uri.parse(url), headers: headers);
    try {
      return genericResponseHandler(
        requestCallback: () async =>
            client.get(Uri.parse(url), headers: headers),
        create: (json) {
          // check if tag_name is in the json
          if (json.containsKey("assets")) {
            final ret = (json["assets"] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
            return ret;
          }
          return null;
        },
      );
    } on Exception {
      // developer.log("BadRequest: ${e.message}");
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
GithubService githubService(Ref ref) => GithubService(
      ref: ref,
      client: http.Client(),
    );
