import 'package:flutter_test/flutter_test.dart';
import 'package:admin_dashboard_web/main.dart';

void main() {
  testWidgets('Admin app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const AdminApp(
        hasSession: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('MediData'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsOneWidget);
  });
}