import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Print MPV Path Preference', () async {
    SharedPreferences.setMockInitialValues({}); // This mocks it, so we can't read the real system preferences from mock.
  });
}
