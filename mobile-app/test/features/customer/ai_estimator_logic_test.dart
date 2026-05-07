import 'package:flutter_test/flutter_test.dart';
import 'package:servio_mobile_app/src/features/customer/ai_finishing_estimator_screen.dart';

void main() {
  group('calcCosts', () {
    test('living room economy 10 sqm', () {
      final r = calcCosts(
        roomType: 'living-room',
        finishLevel: 'economy',
        floorArea: 10.0,
      );
      // labor     = 10 * 12 * 1.0  = 120.0
      // materials = 10 *  8 * 1.0  =  80.0
      // logistics = 10 *  5 * 1.0  =  50.0
      // total = 250.0 ; variance = 250 * 0.08 = 20.0
      expect(r.labor,     closeTo(120.0, 0.01));
      expect(r.materials, closeTo(80.0, 0.01));
      expect(r.logistics, closeTo(50.0, 0.01));
      expect(r.total,     closeTo(250.0, 0.01));
      expect(r.low,  230);
      expect(r.high, 270);
    });

    test('bathroom premium 5 sqm', () {
      final r = calcCosts(
        roomType: 'bathroom',
        finishLevel: 'premium',
        floorArea: 5.0,
      );
      // mult = 1.55
      // labor     = 5 * 55 * 1.55 = 426.25
      // materials = 5 * 38 * 1.55 = 294.5
      // logistics = 5 * 17 * 1.55 = 131.75
      // total = 852.5 ; variance = 852.5 * 0.12 = 102.3
      expect(r.labor,     closeTo(426.25, 0.01));
      expect(r.materials, closeTo(294.50, 0.01));
      expect(r.logistics, closeTo(131.75, 0.01));
      expect(r.total,     closeTo(852.50, 0.01));
      expect(r.low,  750);   // 852.5 - 102.3 = 750.2 → 750
      expect(r.high, 955);   // 852.5 + 102.3 = 954.8 → 955
    });

    test('kitchen standard 20 sqm', () {
      final r = calcCosts(
        roomType: 'kitchen',
        finishLevel: 'standard',
        floorArea: 20.0,
      );
      // mult = 1.35
      // labor     = 20 * 28 * 1.35 = 756.0
      // materials = 20 * 18 * 1.35 = 486.0
      // logistics = 20 *  9 * 1.35 = 243.0
      // total = 1485.0 ; variance = 1485 * 0.10 = 148.5
      expect(r.total, closeTo(1485.0, 0.01));
      expect(r.low,  1337);
      expect(r.high, 1634);  // 1485 + 148.5 = 1633.5 → 1634
    });

    test('unknown roomType defaults multiplier to 1.0', () {
      final r = calcCosts(
        roomType: 'unknown-room',
        finishLevel: 'economy',
        floorArea: 10.0,
      );
      expect(r.total, closeTo(250.0, 0.01));
    });
  });

  group('calcMaterials', () {
    test('kitchen 10 sqm floor, 40 sqm wall — has wall tiles', () {
      final m = calcMaterials(
        roomType: 'kitchen',
        floorArea: 10.0,
        wallArea: 40.0,
      );
      expect(m.floorTiles,   closeTo(11.0,  0.01));  // 10 * 1.1
      expect(m.wallTiles,    closeTo(44.0,  0.01));  // 40 * 1.1
      expect(m.paintLiters,  closeTo(8.0,   0.01));  // 40/10*2
      expect(m.primerLiters, closeTo(3.33,  0.01));  // 40/12
      expect(m.groutKg,      closeTo(5.0,   0.01));  // 10*0.5
      expect(m.adhesiveKg,   closeTo(50.0,  0.01));  // 10*5
    });

    test('bathroom has wall tiles', () {
      final m = calcMaterials(
        roomType: 'bathroom',
        floorArea: 5.0,
        wallArea: 25.0,
      );
      expect(m.wallTiles, closeTo(27.5, 0.01));  // 25 * 1.1
    });

    test('bedroom has no wall tiles', () {
      final m = calcMaterials(
        roomType: 'bedroom',
        floorArea: 20.0,
        wallArea: 60.0,
      );
      expect(m.wallTiles, 0.0);
    });

    test('living room has no wall tiles', () {
      final m = calcMaterials(
        roomType: 'living-room',
        floorArea: 15.0,
        wallArea: 50.0,
      );
      expect(m.wallTiles, 0.0);
    });
  });
}
