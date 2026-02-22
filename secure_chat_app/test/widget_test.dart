import 'package:flutter_test/flutter_test.dart';
import 'package:secure_chat_app/main.dart';

void main() {
  testWidgets('App loads and shows Secure Chat', (WidgetTester tester) async {
    await tester.pumpWidget(const SecureChatApp());
    await tester.pumpAndSettle();
    expect(find.text('Secure Chat'), findsWidgets);
  });
}
