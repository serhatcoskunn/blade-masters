import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_blade_client/main.dart';
import 'package:orbit_blade_client/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    await tester.pumpWidget(const OrbitBladeApp());
    expect(find.byType(OrbitBladeApp), findsOneWidget);
  });
}
