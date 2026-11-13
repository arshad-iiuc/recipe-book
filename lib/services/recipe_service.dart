import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recipe.dart';
import 'recipe_cache.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class RecipePage {
  final List<Recipe> recipes;
  final int total;
  const RecipePage(this.recipes, this.total);
}

class RecipeService {
  RecipeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Every request goes through here, so timeouts and connection failures
  // become readable messages in one place.
  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ApiException('The request timed out. Please try again.');
    } catch (_) {
      // ponytail: every network failure is reported as "no internet";
      // upgrade path is separate messages per exception type.
      throw const ApiException('No internet connection.');
    }
  }

  // A search query wins over mealType; with neither, everything is listed.
  Future<RecipePage> fetch({
    int skip = 0,
    int limit = 10,
    String query = '',
    String? mealType,
  }) async {
    final params = {'limit': '$limit', 'skip': '$skip'};
    var path = '/recipes';
    if (query.trim().isNotEmpty) {
      path = '/recipes/search';
      params['q'] = query.trim();
    } else if (mealType != null) {
      path = '/recipes/meal-type/${mealType.toLowerCase()}';
    }
    final res = await _send(_client.get(Uri.https('dummyjson.com', path, params)));

    if (res.statusCode != 200) {
      throw ApiException('Server error (${res.statusCode}).');
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final recipes = (data['recipes'] as List)
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
          .toList();
      return RecipePage(recipes, data['total'] as int);
    } catch (_) {
      throw const ApiException('Received unexpected data from the server.');
    }
  }

  // DummyJSON only simulates updating too, so the edit is also saved on the
  // device, see RecipeCache.saveEdit.
  Future<void> updateRecipe(Recipe recipe) async {
    if (recipe.id >= firstLocalId) return; // made on this device
    final res = await _send(
      _client.put(
        Uri.https('dummyjson.com', '/recipes/${recipe.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(recipe.toJson()),
      ),
    );
    if (res.statusCode != 200) {
      throw ApiException('Server error (${res.statusCode}).');
    }
  }

  // DummyJSON only echoes the recipe back and does not store it, so the app
  // keeps its own copy afterwards, see RecipeCache.addLocal.
  Future<void> addRecipe(Recipe recipe) async {
    final res = await _send(
      _client.post(
        Uri.https('dummyjson.com', '/recipes/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(recipe.toJson()),
      ),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException('Server error (${res.statusCode}).');
    }
  }

  // DummyJSON only simulates deleting (the recipe stays on the server), so
  // the app also remembers the deletion itself, see RecipeCache.delete.
  Future<void> deleteRecipe(int id) async {
    if (id >= firstLocalId) return; // made on this device, the server never had it
    final res = await _send(
      _client.delete(Uri.https('dummyjson.com', '/recipes/$id')),
    );
    if (res.statusCode != 200) {
      throw ApiException('Server error (${res.statusCode}).');
    }
  }
}
