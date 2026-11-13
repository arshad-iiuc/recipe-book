import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_book/services/recipe_service.dart';

import 'recipe_test.dart' show sample;

String body() => jsonEncode({
      'recipes': [sample()],
      'total': 50,
      'skip': 0,
      'limit': 10,
    });

void main() {
  test('plain list builds the right URL and parses the page', () async {
    late Uri seen;
    final service = RecipeService(
      client: MockClient((req) async {
        seen = req.url;
        return http.Response(body(), 200);
      }),
    );
    final page = await service.fetch(skip: 10);
    expect(seen.path, '/recipes');
    expect(seen.queryParameters['skip'], '10');
    expect(page.recipes.single.name, 'Classic Margherita Pizza');
    expect(page.total, 50);
  });

  test('search beats mealType, and mealType is lowercased', () async {
    final urls = <String>[];
    final service = RecipeService(
      client: MockClient((req) async {
        urls.add(req.url.toString());
        return http.Response(body(), 200);
      }),
    );
    await service.fetch(query: 'pizza', mealType: 'Dinner');
    await service.fetch(mealType: 'Dinner');
    expect(urls[0], contains('/recipes/search'));
    expect(urls[0], contains('q=pizza'));
    expect(urls[1], contains('/recipes/meal-type/dinner'));
  });

  test('server error and network failure become ApiException', () async {
    final bad = RecipeService(
      client: MockClient((_) async => http.Response('x', 500)),
    );
    await expectLater(bad.fetch(), throwsA(isA<ApiException>()));

    final offline = RecipeService(
      client: MockClient((_) async => throw Exception('offline')),
    );
    await expectLater(offline.fetch(), throwsA(isA<ApiException>()));
  });
}
