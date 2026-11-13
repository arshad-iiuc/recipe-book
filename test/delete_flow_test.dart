import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/models/recipe.dart';
import 'package:recipe_book/screens/home_screen.dart';
import 'package:recipe_book/services/recipe_cache.dart';
import 'package:recipe_book/services/recipe_service.dart';

import 'recipe_test.dart' show sample;

Recipe recipe(int id, String name) =>
    Recipe.fromJson({...sample(), 'id': id, 'name': name});

class FakeService extends RecipeService {
  FakeService({required this.total});

  final int total;
  final skips = <int>[];
  final deleted = <int>[];

  @override
  Future<RecipePage> fetch({
    int skip = 0,
    int limit = 10,
    String query = '',
    String? mealType,
  }) async {
    skips.add(skip);
    final count = min(limit, total - skip);
    return RecipePage([
      for (var i = 1; i <= count; i++) recipe(skip + i, 'Recipe ${skip + i}'),
    ], total);
  }

  @override
  Future<void> deleteRecipe(int id) async => deleted.add(id);
}

class FakeCache extends RecipeCache {
  FakeCache({this.hidden = const {}});

  final Set<int> hidden; // ids the "database" already knows as deleted
  final deleted = <int>[];

  @override
  Future<void> save(List<Recipe> recipes) async {}

  @override
  List<Recipe> search({String query = '', String? mealType}) => [];

  @override
  bool isDeleted(int id) => hidden.contains(id) || deleted.contains(id);

  @override
  Future<void> delete(int id) async => deleted.add(id);
}

void main() {
  testWidgets('a deleted recipe disappears from the list', (tester) async {
    final service = FakeService(total: 3);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(service: service, cache: FakeCache())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recipe 2'), findsOneWidget);

    await tester.tap(find.text('Recipe 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(service.deleted, [2]);
    expect(find.text('Recipe 2'), findsNothing);
    expect(find.text('Recipe 1'), findsOneWidget);
  });

  testWidgets('skip counts server items, not the ones hidden as deleted',
      (tester) async {
    final service = FakeService(total: 15);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(service: service, cache: FakeCache(hidden: {3})),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recipe 3'), findsNothing); // hidden

    await tester.drag(find.byType(GridView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(service.skips, contains(10)); // not 9
    expect(service.skips, isNot(contains(9)));
  });
}
