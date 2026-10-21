import 'dart:math' as math;
import 'dart:ui';

/// Pointer inertia ("glide") for touch-driven cursor movement on mobile.
///
/// After a flick in "Mouse mode" the cursor keeps moving in the direction of
/// the flick and slows down on its own: the velocity halves every
/// [halfLifeMs] milliseconds until it drops below [kStopVelocity].
///
/// Velocities are finger velocities in logical pixels per millisecond, before
/// pointer speed / acceleration is applied.
class PointerInertia {
  static const double kMinHalfLifeMs = 80;
  static const double kMaxHalfLifeMs = 300;
  static const double kDefaultHalfLifeMs = 150;

  // Slower releases are treated as a normal lift, not a flick.
  static const double kMinStartVelocity = 0.5;
  static const double kMaxStartVelocity = 8.0;
  static const double kStopVelocity = 0.05;
  static const double kMaxDurationMs = 1500;

  bool enabled = false;
  double _halfLifeMs = kDefaultHalfLifeMs;

  Offset _velocity = Offset.zero;
  double _elapsedMs = 0;
  bool _active = false;

  bool get active => _active;

  /// Current glide speed in logical pixels per millisecond.
  double get velocity => _velocity.distance;

  double get halfLifeMs => _halfLifeMs;
  set halfLifeMs(double v) => _halfLifeMs = clampHalfLife(v);

  static double clampHalfLife(double v) {
    if (v.isNaN) return kDefaultHalfLifeMs;
    return v.clamp(kMinHalfLifeMs, kMaxHalfLifeMs).toDouble();
  }

  /// Starts gliding with the finger [velocity] at release.
  /// Returns whether a glide was started.
  bool start(Offset velocity) {
    stop();
    if (!enabled) return false;
    final speed = velocity.distance;
    if (!(speed >= kMinStartVelocity)) return false;
    _velocity = speed > kMaxStartVelocity
        ? velocity * (kMaxStartVelocity / speed)
        : velocity;
    _elapsedMs = 0;
    _active = true;
    return true;
  }

  void stop() {
    _active = false;
    _velocity = Offset.zero;
  }

  /// Advances the glide by [dtMs] milliseconds and returns the distance
  /// travelled in that time.
  Offset step(double dtMs) {
    if (!_active || !(dtMs > 0)) return Offset.zero;
    final decay = math.pow(0.5, dtMs / _halfLifeMs).toDouble();
    // Exact integral of v0 * 0.5^(t / H) over [0, dt], so the total distance
    // does not depend on the frame rate.
    final distance = _velocity * (_halfLifeMs / math.ln2 * (1 - decay));
    _velocity = _velocity * decay;
    _elapsedMs += dtMs;
    if (_velocity.distance < kStopVelocity || _elapsedMs >= kMaxDurationMs) {
      stop();
    }
    return distance;
  }
}
