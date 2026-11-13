import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_book/models/recipe.dart';
import 'package:recipe_book/screens/home_screen.dart';
import 'package:recipe_book/services/recipe_cache.dart';
import 'package:recipe_book/services/recipe_service.dart';

import 'recipe_test.dart' show sample;

class FakeCache extends RecipeCache {
  FakeCache([this.stored = const []]);

  final List<Recipe> stored;
  final saved = <Recipe>[];

  @override
  Future<void> save(List<Recipe> recipes) async => saved.addAll(recipes);

  @override
  List<Recipe> search({String query = '', String? mealType}) => stored;
}

Future<void> show(
  WidgetTester tester,
  http.Client client,
  FakeCache cache,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(service: RecipeService(client: client), cache: cache),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final offline = MockClient((_) async => throw Exception('offline'));

  testWidgets('offline: shows saved recipes and a banner', (tester) async {
    await show(tester, offline, FakeCache([Recipe.fromJson(sample())]));
    expect(find.text('Classic Margherita Pizza'), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('offline with nothing saved: error and Retry', (tester) async {
    await show(tester, offline, FakeCache());
    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('online: downloaded recipes are saved', (tester) async {
    final cache = FakeCache();
    final body = jsonEncode({
      'recipes': [sample()],
      'total': 1,
      'skip': 0,
      'limit': 10,
    });
    await show(tester, MockClient((_) async => http.Response(body, 200)), cache);
    expect(cache.saved.length, 1);
    expect(find.textContaining('Offline'), findsNothing);
  });
}
