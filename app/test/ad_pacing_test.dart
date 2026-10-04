import 'package:flutter_test/flutter_test.dart';
import 'package:quick_convert/services/ad_pacing.dart';

void main() {
  late DateTime now;
  AdPacing pacing() => AdPacing(clock: () => now);

  setUp(() => now = DateTime(2026, 10, 4, 12));

  test('la première conversion ne montre pas de publicité', () {
    expect(pacing().registerConversion(), isFalse);
  });

  test('une conversion sur deux en montre une', () {
    final p = pacing();
    final shown = <bool>[];
    for (var i = 0; i < 6; i++) {
      final show = p.registerConversion();
      shown.add(show);
      if (show) p.markShown();
      now = now.add(const Duration(minutes: 5));
    }
    expect(shown, [false, true, false, true, false, true]);
  });

  test('jamais deux publicités à moins de 90 secondes', () {
    final p = pacing();
    p.registerConversion();
    expect(p.registerConversion(), isTrue);
    p.markShown();

    now = now.add(const Duration(seconds: 30));
    p.registerConversion();
    expect(p.registerConversion(), isFalse, reason: 'trop tôt');

    now = now.add(const Duration(seconds: 61));
    expect(p.registerConversion(), isTrue, reason: 'la publicité due passe');
  });

  test('une publicité qui ne s\'est pas affichée ne repousse pas la suivante', () {
    final p = pacing();
    p.registerConversion();
    expect(p.registerConversion(), isTrue);
    // Pas de markShown : l'annonce n'avait pas chargé.
    expect(p.registerConversion(), isTrue);
  });
}
