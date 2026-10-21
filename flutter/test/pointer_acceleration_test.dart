import 'package:flutter_hbb/models/pointer_acceleration.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends [steps] equal moves of [step] spaced [intervalMs] apart and returns
/// the summed cursor movement.
Offset _stroke(PointerAcceleration a, Offset step, int steps, int intervalMs) {
  a.reset();
  var total = Offset.zero;
  for (var i = 0; i < steps; i++) {
    total += a.apply(step, Duration(milliseconds: i * intervalMs));
  }
  return total;
}

void main() {
  group('PointerAcceleration', () {
    test('disabled at default speed passes deltas through unchanged', () {
      final a = PointerAcceleration();
      const deltas = [
        Offset(0.3, -0.7),
        Offset(120.5, 3.25),
        Offset(-48, 96),
        Offset.zero,
      ];
      for (var i = 0; i < deltas.length; i++) {
        expect(a.apply(deltas[i], Duration(milliseconds: i)), deltas[i]);
      }
      expect(a.apply(const Offset(5, 5)), const Offset(5, 5));
    });

    test('speed scales movement linearly when acceleration is off', () {
      final a = PointerAcceleration()..speed = 2.0;
      expect(_stroke(a, const Offset(10, -4), 10, 1), const Offset(200, -80));
    });

    test('speed is clamped to the supported range', () {
      final a = PointerAcceleration();
      a.speed = 10;
      expect(a.speed, PointerAcceleration.kMaxSpeed);
      a.speed = 0;
      expect(a.speed, PointerAcceleration.kMinSpeed);
      a.speed = double.nan;
      expect(a.speed, PointerAcceleration.kDefaultSpeed);
    });

    test('slow swipes are not accelerated', () {
      final a = PointerAcceleration()..enabled = true;
      // 1 px every 16 ms ~= 0.06 px/ms, well below the threshold.
      final total = _stroke(a, const Offset(1, 0), 60, 16);
      expect(total.dx, closeTo(60, 1e-9));
    });

    test('fast swipes travel further than the same distance swiped slowly', () {
      final slow = _stroke(
          PointerAcceleration()..enabled = true, const Offset(2, 0), 100, 16);
      // Same 200 px of finger travel in 8 px steps every 4 ms (2 px/ms).
      final fast = _stroke(
          PointerAcceleration()..enabled = true, const Offset(8, 0), 25, 4);
      expect(slow.dx, closeTo(200, 1e-9));
      expect(fast.dx, greaterThan(2.5 * slow.dx));
      expect(fast.dx,
          lessThanOrEqualTo(PointerAcceleration.kDefaultStrength * 200));
    });

    test('gain is monotonic and capped', () {
      final a = PointerAcceleration();
      var prev = 0.0;
      for (var v = 0.0; v <= 5.0; v += 0.05) {
        final g = a.gainForVelocity(v);
        expect(g, greaterThanOrEqualTo(prev));
        expect(g, inInclusiveRange(1.0, PointerAcceleration.kDefaultStrength));
        prev = g;
      }
    });

    test('strength sets the gain of fast movements only', () {
      final weak = PointerAcceleration()..strength = 2.0;
      final strong = PointerAcceleration()..strength = 8.0;
      expect(weak.gainForVelocity(0.2), 1.0);
      expect(strong.gainForVelocity(0.2), 1.0);
      expect(weak.gainForVelocity(3.0), 2.0);
      expect(strong.gainForVelocity(3.0), 8.0);
      expect(
          strong.gainForVelocity(1.4), greaterThan(weak.gainForVelocity(1.4)));
    });

    test('strength is clamped', () {
      final a = PointerAcceleration();
      a.strength = 0.5;
      expect(a.strength, PointerAcceleration.kMinStrength);
      a.strength = 100;
      expect(a.strength, PointerAcceleration.kMaxStrength);
      a.strength = double.nan;
      expect(a.strength, PointerAcceleration.kDefaultStrength);
    });

    test('first move of a stroke and moves after a pause are not boosted', () {
      final a = PointerAcceleration()..enabled = true;
      expect(a.apply(const Offset(50, 0), Duration.zero), const Offset(50, 0));
      a.apply(const Offset(50, 0), const Duration(milliseconds: 4));
      // A long pause starts a new stroke.
      expect(a.apply(const Offset(50, 0), const Duration(seconds: 1)),
          const Offset(50, 0));
    });

    test('near-identical timestamps do not cause spikes', () {
      final a = PointerAcceleration()..enabled = true;
      a.apply(const Offset(1, 0), Duration.zero);
      final out = a.apply(const Offset(1, 0), const Duration(microseconds: 1));
      expect(out.dx, lessThan(1.1));
    });
  });
}
