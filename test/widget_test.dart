import 'package:flutter_test/flutter_test.dart';
import 'package:admin_dashboard_web/admin/screens/admin_login_screen.dart';
import 'package:admin_dashboard_web/main.dart';

void main() {
  testWidgets('Admin app shows login when user is not an admin',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const AdminApp(isAdmin: false),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AdminLoginScreen), findsOneWidget);
  });
}
