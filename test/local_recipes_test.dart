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
  group('local recipes in the cache', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_local');
      Hive.init(dir.path);
      await Hive.openBox<String>(recipeBoxName);
      await Hive.openBox<bool>(deletedBoxName);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('first local id is 1000, then it counts up', () async {
      final cache = RecipeCache();
      expect(cache.nextLocalId(), 1000);
      await cache.addLocal(withId(1000, 'A'));
      expect(cache.nextLocalId(), 1001);
    });

    test('local() lists only local recipes, newest first', () async {
      final cache = RecipeCache();
      await cache.save([withId(5, 'Downloaded')]);
      await cache.addLocal(withId(1000, 'Old'));
      await cache.addLocal(withId(1001, 'New'));
      expect(cache.local().map((r) => r.name), ['New', 'Old']);
    });

    test('a deleted local id is never reused', () async {
      final cache = RecipeCache();
      await cache.addLocal(withId(1000, 'A'));
      await cache.addLocal(withId(1001, 'B'));
      await cache.delete(1001);
      expect(cache.nextLocalId(), 1002);
      expect(cache.local().map((r) => r.id), [1000]);
    });
  });

  group('addRecipe in the service', () {
    test('sends a POST with the recipe as JSON', () async {
      late http.Request seen;
      final service = RecipeService(
        client: MockClient((req) async {
          seen = req;
          return http.Response('{"id":51}', 201);
        }),
      );
      await service.addRecipe(withId(1000, 'Mine'));
      expect(seen.method, 'POST');
      expect(seen.url.path, '/recipes/add');
      expect(jsonDecode(seen.body)['name'], 'Mine');
    });

    test('a server error becomes an ApiException', () async {
      final service = RecipeService(
        client: MockClient((_) async => http.Response('', 500)),
      );
      expect(
        () => service.addRecipe(withId(1000, 'Mine')),
        throwsA(isA<ApiException>()),
      );
    });

    test('deleting a local recipe sends no request', () async {
      var calls = 0;
      final service = RecipeService(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
      );
      await service.deleteRecipe(1000);
      expect(calls, 0);
    });
  });
}
