import 'package:flutter_test/flutter_test.dart';
import 'package:mozzy_print_service/main.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const MozzyPrintApp());
    expect(find.text('Mozzy Print Service'), findsOneWidget);
  });
}
