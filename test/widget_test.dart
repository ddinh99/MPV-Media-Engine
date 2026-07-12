// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_sound_engine/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MvpSoundEngineApp());
    expect(find.text('MPV Media Engine'), findsOneWidget);
  });
}
