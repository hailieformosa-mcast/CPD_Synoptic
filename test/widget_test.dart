import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_list_app/main.dart';

void main() {
  testWidgets('Shopping list starts empty and has an Add button', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ShoppingListApp());

    // Verify that the app starts with an empty shopping list.
    expect(find.text('Your shopping list is empty. Add items to get started!'), findsOneWidget);

    // Verify that the "Add" button is present.
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
