import 'package:flutter_test/flutter_test.dart';

import 'package:q_less_prototype/main.dart';

void main() {
  testWidgets('Login screen renders and navigates to register',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QLessApp());

    expect(find.text('Q-LESS'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('Crear una cuenta'), findsOneWidget);

    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Crear Cuenta'), findsWidgets);
    expect(find.text('Volver al Login'), findsOneWidget);
  });
}
