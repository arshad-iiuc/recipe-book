import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipe_book/screens/home_screen.dart';
import 'package:recipe_book/services/recipe_service.dart';

import 'recipe_test.dart' show sample;

Future<void> show(WidgetTester tester, http.Client client) async {
  await tester.pumpWidget(
    MaterialApp(home: HomeScreen(service: RecipeService(client: client))),
  );
}

String page(int count, int total, int skip) => jsonEncode({
      'recipes': List.generate(count, (_) => sample()),
      'total': total,
      'skip': skip,
      'limit': 10,
    });

void main() {
  testWidgets('spinner, then recipe cards', (tester) async {
    await show(tester, MockClient((_) async => http.Response(page(1, 1, 0), 200)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Classic Margherita Pizza'), findsOneWidget);
  });

  testWidgets('server error shows message and Retry', (tester) async {
    await show(tester, MockClient((_) async => http.Response('x', 500)));
    await tester.pumpAndSettle();
    expect(find.text('Server error (500).'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('typing searches after a pause', (tester) async {
    final urls = <Uri>[];
    await show(tester, MockClient((req) async {
      urls.add(req.url);
      return http.Response(page(1, 1, 0), 200);
    }));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(urls.last.path, '/recipes/search');
    expect(urls.last.queryParameters['q'], 'pizza');
  });

  testWidgets('meal-type chip filters', (tester) async {
    final urls = <Uri>[];
    await show(tester, MockClient((req) async {
      urls.add(req.url);
      return http.Response(page(1, 1, 0), 200);
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(urls.last.path, '/recipes/meal-type/dinner');
  });

  testWidgets('scrolling to the bottom loads the next page', (tester) async {
    final skips = <String?>[];
    await show(tester, MockClient((req) async {
      final skip = int.parse(req.url.queryParameters['skip']!);
      skips.add(req.url.queryParameters['skip']);
      return http.Response(page(skip == 0 ? 10 : 5, 15, skip), 200);
    }));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GridView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(skips, contains('10'));
  });
}
