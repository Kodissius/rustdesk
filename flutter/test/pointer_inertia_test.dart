import 'dart:math' as math;

import 'package:flutter_hbb/models/pointer_acceleration.dart';
import 'package:flutter_hbb/models/pointer_inertia.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs a glide to completion at a fixed frame interval and returns the
/// total distance and the number of frames.
(Offset, int) _glide(PointerInertia inertia, double frameMs) {
  var total = Offset.zero;
  var frames = 0;
  while (inertia.active) {
    total += inertia.step(frameMs);
    frames++;
  }
  return (total, frames);
}

void main() {
  test('disabled never glides', () {
    final inertia = PointerInertia();
    expect(inertia.start(const Offset(3, 0)), isFalse);
    expect(inertia.active, isFalse);
    expect(inertia.step(16), Offset.zero);
  });

  test('slow release does not glide', () {
    final inertia = PointerInertia()..enabled = true;
    expect(inertia.start(const Offset(0.3, 0.2)), isFalse);
    expect(inertia.start(const Offset(double.nan, 0)), isFalse);
  });

  test('glides in the release direction and slows down', () {
    final inertia = PointerInertia()..enabled = true;
    expect(inertia.start(const Offset(2, -1)), isTrue);
    final first = inertia.step(16);
    final second = inertia.step(16);
    expect(first.dx, greaterThan(0));
    expect(first.dy, lessThan(0));
    expect(first.dx / first.dy, closeTo(-2, 1e-9));
    expect(second.distance, lessThan(first.distance));
  });

  test('velocity halves every half-life', () {
    final inertia = PointerInertia()
      ..enabled = true
      ..halfLifeMs = 150;
    inertia.start(const Offset(4, 0));
    inertia.step(150);
    expect(inertia.velocity, closeTo(2, 1e-9));
  });

  test('total distance does not depend on frame rate', () {
    PointerInertia make() => PointerInertia()
      ..enabled = true
      ..halfLifeMs = 150;
    final at60 = make()..start(const Offset(2, 0));
    final at120 = make()..start(const Offset(2, 0));
    final (d60, _) = _glide(at60, 1000 / 60);
    final (d120, _) = _glide(at120, 1000 / 120);
    expect(d60.dx, closeTo(d120.dx, 2));
    // The analytic total (v0 - vStop) * H / ln2: the glide is cut off once
    // it is slower than kStopVelocity.
    expect(d60.dx,
        closeTo((2 - PointerInertia.kStopVelocity) * 150 / math.ln2, 2));
  });

  test('longer half-life glides further', () {
    double distance(double halfLife) {
      final inertia = PointerInertia()
        ..enabled = true
        ..halfLifeMs = halfLife;
      inertia.start(const Offset(2, 0));
      return _glide(inertia, 16).$1.dx;
    }

    expect(distance(PointerInertia.kMaxHalfLifeMs),
        greaterThan(distance(PointerInertia.kMinHalfLifeMs) * 2));
  });

  test('glide ends and is time-capped', () {
    final inertia = PointerInertia()
      ..enabled = true
      ..halfLifeMs = PointerInertia.kMaxHalfLifeMs;
    inertia.start(const Offset(100, 0));
    final (total, frames) = _glide(inertia, 16);
    expect(frames * 16, lessThanOrEqualTo(PointerInertia.kMaxDurationMs + 16));
    // Release speed is capped.
    expect(total.dx,
        lessThanOrEqualTo(PointerInertia.kMaxStartVelocity * 300 / math.ln2));
  });

  test('stop ends the glide immediately', () {
    final inertia = PointerInertia()..enabled = true;
    inertia.start(const Offset(3, 0));
    inertia.step(16);
    inertia.stop();
    expect(inertia.active, isFalse);
    expect(inertia.step(16), Offset.zero);
  });

  test('half-life is clamped', () {
    final inertia = PointerInertia();
    inertia.halfLifeMs = 1;
    expect(inertia.halfLifeMs, PointerInertia.kMinHalfLifeMs);
    inertia.halfLifeMs = 10000;
    expect(inertia.halfLifeMs, PointerInertia.kMaxHalfLifeMs);
    inertia.halfLifeMs = double.nan;
    expect(inertia.halfLifeMs, PointerInertia.kDefaultHalfLifeMs);
  });

  test('glide movement uses speed and acceleration of its velocity', () {
    final accel = PointerAcceleration()..speed = 2.0;
    const d = Offset(10, 0);
    expect(accel.applyAtVelocity(d, 2.0), const Offset(20, 0));
    accel.enabled = true;
    expect(accel.applyAtVelocity(d, 0.1), const Offset(20, 0));
    expect(accel.applyAtVelocity(d, 2.5),
        Offset(20 * PointerAcceleration.kDefaultStrength, 0));
  });
}
