import 'package:flutter_test/flutter_test.dart';
import 'package:assignment/main.dart';

void main() {
  testWidgets('AdminDashboardScreen smoke test', (WidgetTester tester) async {
    // Build app và kích hoạt frame đầu tiên
    await tester.pumpWidget(const MyApp());

    // Xác nhận màn hình AdminDashboard hiển thị tiêu đề Quản trị hệ thống
    expect(find.text('Quản trị hệ thống'), findsOneWidget);
  });
}
