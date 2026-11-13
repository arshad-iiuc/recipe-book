import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_book/services/recipe_service.dart';

void main() {
  test('delete sends DELETE to the recipe URL', () async {
    late http.Request seen;
    final service = RecipeService(
      client: MockClient((req) async {
        seen = req;
        return http.Response('{}', 200);
      }),
    );
    await service.deleteRecipe(7);
    expect(seen.method, 'DELETE');
    expect(seen.url.path, '/recipes/7');
  });

  test('a server error becomes ApiException', () async {
    final service = RecipeService(
      client: MockClient((_) async => http.Response('x', 404)),
    );
    await expectLater(service.deleteRecipe(7), throwsA(isA<ApiException>()));
  });

  test('no connection becomes ApiException', () async {
    final service = RecipeService(
      client: MockClient((_) async => throw Exception('offline')),
    );
    await expectLater(service.deleteRecipe(7), throwsA(isA<ApiException>()));
  });
}
