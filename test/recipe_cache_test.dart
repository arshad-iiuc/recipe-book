import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:recipe_book/models/recipe.dart';
import 'package:recipe_book/services/recipe_cache.dart';

import 'recipe_test.dart' show sample;

void main() {
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('recipe_cache_test');
    Hive.init(dir.path);
    await Hive.openBox<String>(recipeBoxName);
    await Hive.openBox<bool>(deletedBoxName);
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  final pizza = Recipe.fromJson(sample());
  final soup = Recipe.fromJson({
    ...sample(),
    'id': 2,
    'name': 'Tomato Soup',
    'mealType': ['Lunch'],
  });

  test('saved recipes come back, filtered by name and meal type', () async {
    final cache = RecipeCache();
    await cache.save([pizza, soup]);

    expect(cache.search().map((r) => r.id), [1, 2]);
    expect(cache.search(query: 'SOUP').single.id, 2);
    expect(cache.search(mealType: 'dinner').single.id, 1);
    expect(cache.search(query: 'soup', mealType: 'dinner').single.id, 2);
    expect(cache.search().first.ingredients, pizza.ingredients);
  });

  test('a damaged entry is skipped, not fatal', () async {
    final cache = RecipeCache();
    await cache.save([pizza]);
    await Hive.box<String>(recipeBoxName).put(99, 'not json');
    expect(cache.search().single.id, 1);
  });

  test('a deleted recipe is gone and later downloads cannot bring it back',
      () async {
    final cache = RecipeCache();
    await cache.save([pizza, soup]);
    await cache.delete(1);

    expect(cache.isDeleted(1), isTrue);
    expect(cache.isDeleted(2), isFalse);
    expect(cache.search().map((r) => r.id), [2]);

    await cache.save([pizza, soup]); // the server still returns it
    expect(cache.search().map((r) => r.id), [2]);
  });

  test('deleted ids survive closing and reopening storage', () async {
    await RecipeCache().delete(1);
    await Hive.close();

    Hive.init(dir.path);
    await Hive.openBox<bool>(deletedBoxName);
    expect(RecipeCache().isDeleted(1), isTrue);
  });
}
