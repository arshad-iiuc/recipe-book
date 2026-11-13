import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_book/models/recipe.dart';
import 'package:recipe_book/services/recipe_cache.dart';
import 'package:recipe_book/services/recipe_service.dart';

import 'recipe_test.dart' show sample;

Recipe withId(int id, String name) =>
    Recipe.fromJson({...sample(), 'id': id, 'name': name});

void main() {
  group('edited recipes in the cache', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_edit');
      Hive.init(dir.path);
      await Hive.openBox<String>(recipeBoxName);
      await Hive.openBox<bool>(deletedBoxName);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('a download does not overwrite an edit', () async {
      final cache = RecipeCache();
      await cache.save([withId(5, 'Original')]);
      await cache.saveEdit(withId(5, 'Mine'));
      await cache.save([withId(5, 'Original')]);
      expect(cache.search().map((r) => r.name), ['Mine']);
    });

    test('withEdits swaps only edited recipes', () async {
      final cache = RecipeCache();
      await cache.saveEdit(withId(5, 'Mine'));
      expect(cache.withEdits(withId(5, 'Original')).name, 'Mine');
      expect(cache.withEdits(withId(6, 'Other')).name, 'Other');
    });
  });

  group('updateRecipe in the service', () {
    test('sends a PUT to the recipe id', () async {
      late http.Request seen;
      final service = RecipeService(
        client: MockClient((req) async {
          seen = req;
          return http.Response('{}', 200);
        }),
      );
      await service.updateRecipe(withId(5, 'Mine'));
      expect(seen.method, 'PUT');
      expect(seen.url.path, '/recipes/5');
      expect(jsonDecode(seen.body)['name'], 'Mine');
    });

    test('a local recipe sends no request', () async {
      var calls = 0;
      final service = RecipeService(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
      );
      await service.updateRecipe(withId(1000, 'Mine'));
      expect(calls, 0);
    });
  });
}
