import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/screens/splash_screen.dart';

void main() {
  testWidgets('splash shows the title, then opens the next screen',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(next: Text('NEXT SCREEN'))),
    );
    expect(find.text('Recipe Book'), findsOneWidget);
    expect(find.text('NEXT SCREEN'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('NEXT SCREEN'), findsOneWidget);
    expect(find.text('Recipe Book'), findsNothing);
  });
}
