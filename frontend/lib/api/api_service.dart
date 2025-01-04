import 'dart:async';
import 'dart:developer' as developer;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zest/recipes/models/recipe_favorite.dart';

import 'package:zest/utils/networking.dart';

import '../authentication/auth_service.dart';

import '../recipes/models/models.dart';
import '../settings/settings_provider.dart';
import 'api_utils.dart';
import 'responses/responses.dart';

part 'api_service.g.dart';

class APIService {
  final InterceptedClient client;
  final Ref ref;

  APIService({required this.ref, required this.client});

  //////////////////////////////////////////////////////////////////////////////
  /// RECIPES REQUESTS
  //////////////////////////////////////////////////////////////////////////////

  Future<RecipeListResponse> getRecipes({
    int page = 1,
    int? pageSize,
    String? search,
    String? user,
    List<String>? searchFields,
    List<String>? ordering,
    bool? favoritesOnly,
    List<int>? categories,
    String? language,
    List<String>? lcFilter,
  }) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': language ?? settings.current.language,
      if (lcFilter != null) 'lc_filter': lcFilter.join(','),
      if (search != null && search.isNotEmpty) 'search': search,
      if (user != null) "user": user,
      "page": page.toString(),
      if (pageSize != null) 'page_size': pageSize.toString(),
      if (searchFields != null) 'search_fields': searchFields.join(','),
      if (categories != null && categories.isNotEmpty)
        'categories': categories.join(','),
      if (favoritesOnly != null && favoritesOnly == true) 'favorites': "True",
      if (ordering != null) 'ordering': ordering.join(',')
    };

    final url =
        getAPIUrl(settings, "/recipes/", queryParameters: queryParameters);

    return genericResponseHandler(
      requestCallback: () async => client.get(url),
      create: (json) => RecipeListResponse.fromJson(json),
    );
  }

  Future<Recipe> getRecipe(String recipeId,
      {String? servings,
      List<String>? lcFilter,
      bool? toMetric,
      String? language}) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': language ?? settings.current.language,
      if (servings != null) 'servings': servings,
      if (lcFilter != null) 'lc_filter': lcFilter.join(','),
      if (toMetric != null && toMetric) 'to_metric': "",
    };

    final url = getAPIUrl(settings, "/recipes/$recipeId/",
        queryParameters: queryParameters);

    return genericResponseHandler(
      requestCallback: () async => client.get(url),
      create: (json) => Recipe.fromJson(json),
    );
  }

  Future<Recipe?> createRecipeRemote(String recipe, {String? lang}) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': lang ?? settings.current.language,
    };

    final url =
        getAPIUrl(settings, "/recipes/", queryParameters: queryParameters);

    try {
      final ret = await genericResponseHandler(
        requestCallback: () async =>
            postWithRedirects(client, url, body: recipe),
        create: (json) => Recipe.fromJson(json),
      );
      return getRecipe(ret.recipeId);
    } on AuthException {
      throw AuthException(); // TODO: FIXME
      // print("Auth Extension")
      // return null;
      // developer.log("Triggered an auth exception",
      //     name: 'APIservice.createRecipeRemote');
      // Get.offNamed(Get.currentRoute);
    } on ResourceNotFoundException {
      return null; // TODO: Communicate actual problem!?
    } on BadRequestException {
      return null; // TODO: Communicate actual problem!?
    }
  }

  Future<Recipe?> updateRecipeRemote(String recipeId, String recipe) async {
    final SettingsState settings = ref.read(settingsProvider);
    final url = getAPIUrl(settings, "/recipes/$recipeId/");
    try {
      return genericResponseHandler(
        requestCallback: () async => client.put(url, body: recipe),
        create: (json) => Recipe.fromJson(json),
      );
      // return ret;
    } on AuthException {
      developer.log("Triggered an auth exception",
          name: 'APIservice.updateRecipeRemote');
      // Get.offNamed(Get.currentRoute);
      throw AuthException();
    } on ResourceNotFoundException catch (e) {
      developer.log("ResourceNotFound: ${e.message}");
      return null;
    } on BadRequestException catch (e) {
      developer.log("BadRequest: ${e.message}");
      return null;
    }
  }

  Future<bool> deleteRecipeRemote({required String recipeId}) async {
    final SettingsState settings = ref.read(settingsProvider);

    final url = getAPIUrl(settings, "/recipes/$recipeId/");
    try {
      await client.delete(url);
      return true;
    } on AuthException {
      return false;
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// RECIPE CATEGORIES REQUESTS
  //////////////////////////////////////////////////////////////////////////////
  Future<List<RecipeCategory>> getRecipeCategories({
    int? pageSize,
    String? language,
  }) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': language ?? settings.current.language,
      if (pageSize != null) 'page_size': pageSize.toString(),
    };

    final url = getAPIUrl(settings, "/recipe_categories/",
        queryParameters: queryParameters);

    return genericResponseHandler(
      requestCallback: () async => client.get(url),
      create: (json) => RecipeCategoryListResponse.fromJson(json).categories,
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  /// RECIPE CATEGORIES REQUESTS
  //////////////////////////////////////////////////////////////////////////////
  Future<RecipeFavorite?> addRecipeToFavorites(
      {required String recipeId}) async {
    final SettingsState settings = ref.read(settingsProvider);

    final url = getAPIUrl(
      settings,
      "/recipes/$recipeId/add_to_favorites",
    );
    try {
      final ret = await genericResponseHandler(
        requestCallback: () async => postWithRedirects(client, url),
        create: (json) => RecipeFavorite.fromJson(json),
      );
      return ret;
    } on AuthException {
      throw AuthException();
    } on ResourceNotFoundException {
      return null; // TODO: Communicate actual problem!?
    } on BadRequestException {
      return null; // TODO: Communicate actual problem!?
    }
  }

  Future<void> deleteRecipeFromFavorites({required String recipeId}) async {
    final SettingsState settings = ref.read(settingsProvider);

    final url = getAPIUrl(
      settings,
      "/recipes/$recipeId/remove_from_favorites",
    );
    try {
      final ret = await genericResponseHandler(
        requestCallback: () async => client.delete(url),
        create: (json) => null,
      );
      return ret;
    } on AuthException {
      throw AuthException();
    } on ResourceNotFoundException {
      return; // TODO: Communicate actual problem!?
    } on BadRequestException {
      return; // TODO: Communicate actual problem!?
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  /// UNIT REQUESTS
  //////////////////////////////////////////////////////////////////////////////
  Future<List<Unit>> getUnits({
    int? pageSize,
    String? search,
    String? language,
  }) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': language ?? settings.current.language,
      if (search != null && search.isNotEmpty) 'search': search,
      if (pageSize != null) 'page_size': pageSize.toString(),
    };

    final url =
        getAPIUrl(settings, "/units/", queryParameters: queryParameters);

    return genericResponseHandler(
      requestCallback: () async => client.get(url),
      create: (json) => UnitListResponse.fromJson(json).units,
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  /// FOOD REQUESTS
  //////////////////////////////////////////////////////////////////////////////

  Future<List<Food>> getFoods({
    int? pageSize,
    String? search,
    String? language,
    List<String>? pks,
  }) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': language ?? settings.current.language,
      if (search != null && search.isNotEmpty) 'search': search,
      if (pageSize != null) 'page_size': pageSize.toString(),
      if (pks != null) 'pks': pks.join(','),
    };

    final url = getAPIUrl(settings, "/foods/", // ?similarity=0.5
        queryParameters: queryParameters);
    return genericResponseHandler(
      requestCallback: () async => client.get(url),
      create: (json) => FoodListResponse.fromJson(json).foods,
    );
  }

  Future<Food?> createFood(String foodJson, {String? language}) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': language ?? settings.current.language,
    };
    final url =
        getAPIUrl(settings, "/foods/", queryParameters: queryParameters);
    return genericResponseHandler(
      requestCallback: () async =>
          postWithRedirects(client, url, body: foodJson),
      create: (json) => Food.fromJson(json),
    );
  }

  Future<FoodListResponse> getFoodsPagination({
    int page = 1,
    int? pageSize,
    String? search,
    String? language,
    List<String>? pks,
  }) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': language ?? settings.current.language,
      if (search != null && search.isNotEmpty) 'search': search,
      if (pageSize != null) 'page_size': pageSize.toString(),
      if (pks != null) 'pks': pks.join(','),
      'page': page.toString()
    };

    final url = getAPIUrl(settings, "/foods/", // ?similarity=0.5
        queryParameters: queryParameters);
    return genericResponseHandler(
      requestCallback: () async => client.get(url),
      create: (json) => FoodListResponse.fromJson(json),
    );
  }

  Future<Food?> updateFood(String foodId, String foodJson,
      {String? language}) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': language ?? settings.current.language,
    };

    final url = getAPIUrl(settings, "/foods/$foodId/",
        queryParameters: queryParameters);

    return genericResponseHandler(
      requestCallback: () async => client.put(url, body: foodJson),
      create: (json) => Food.fromJson(json),
    );
  }

  Future<List<FoodSynonym>> getFoodSynonyms({
    int? pageSize,
    String? search,
    List<String>? lcFilter,
  }) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      if (lcFilter != null) 'lc_filter': lcFilter.join(','),
      if (search != null && search.isNotEmpty) 'search': search,
      if (pageSize != null) 'page_size': pageSize.toString(),
    };

    final url = getAPIUrl(settings, "/food_synonyms/",
        queryParameters: queryParameters);

    return genericResponseHandler(
      requestCallback: () async => client.get(url),
      create: (json) => FoodSynonymsListResponse.fromJson(json).foodSynonyms,
    );
  }

  Future<FoodSynonymsListResponse> getFoodSynonymsPagination({
    int page = 1,
    int? pageSize,
    String? search,
    List<String>? lcFilter,
  }) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      if (lcFilter != null) 'lc_filter': lcFilter.join(','),
      if (search != null && search.isNotEmpty) 'search': search,
      if (pageSize != null) 'page_size': pageSize.toString(),
      "page": page.toString()
    };

    final url = getAPIUrl(settings, "/food_synonyms/",
        queryParameters: queryParameters);

    return genericResponseHandler(
      requestCallback: () async => client.get(url),
      create: (json) => FoodSynonymsListResponse.fromJson(json),
    );
  }

  // //////////////////////////////////////////////////////////////////////////////
  // /// TAG REQUESTS
  // //////////////////////////////////////////////////////////////////////////////
  Future<List<Tag>> getTags({
    int? pageSize,
    String? search,
    String? language,
  }) async {
    final SettingsState settings = ref.read(settingsProvider);

    final queryParameters = {
      'lang': language ?? settings.current.language,
      if (search != null && search.isNotEmpty) 'search': search,
      if (pageSize != null) 'page_size': pageSize.toString(),
    };

    final url = getAPIUrl(settings, "/tags/", queryParameters: queryParameters);
    return genericResponseHandler(
      requestCallback: () async => client.get(url),
      create: (json) => TagListResponse.fromJson(json).tags,
    );
  }

  Future<Tag> createTag(String tagJson, {String? language}) async {
    final SettingsState settings = ref.read(settingsProvider);
    final queryParameters = {
      'lang': language ?? settings.current.language,
    };

    final url = getAPIUrl(settings, "/tags/", queryParameters: queryParameters);
    return genericResponseHandler(
      requestCallback: () async =>
          postWithRedirects(client, url, body: tagJson),
      create: (json) => Tag.fromJson(json),
    );
  }
}

@Riverpod(keepAlive: true)
APIService apiService(Ref ref) => APIService(
      ref: ref,
      client: ref.read(
        httpJSONClientProvider(withAuthenticationInterceptor: true),
      ),
    );

// //////////////////////////////////////////////////////////////////////////////
// /// GITHUB REQUESTS
// //////////////////////////////////////////////////////////////////////////////

class GithubService {
  final InterceptedClient client;
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
    } on AuthException {
      developer.log("Triggered an auth exception",
          name: 'APIservice.updateRecipeRemote');
      // Get.offNamed(Get.currentRoute);
      throw AuthException();
    } on ResourceNotFoundException catch (e) {
      developer.log("ResourceNotFound: ${e.message}");
      return null;
    } on BadRequestException catch (e) {
      developer.log("BadRequest: ${e.message}");
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
    } on AuthException {
      developer.log("Triggered an auth exception",
          name: 'APIservice.updateRecipeRemote');
      // Get.offNamed(Get.currentRoute);
      throw AuthException();
    } on ResourceNotFoundException catch (e) {
      developer.log("ResourceNotFound: ${e.message}");
      return null;
    } on BadRequestException catch (e) {
      developer.log("BadRequest: ${e.message}");
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
GithubService githubService(GithubServiceRef ref) => GithubService(
      ref: ref,
      client: ref.read(
        httpJSONClientProvider(withAuthenticationInterceptor: false),
      ),
    );
