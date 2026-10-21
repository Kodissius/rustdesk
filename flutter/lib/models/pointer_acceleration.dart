import 'dart:ui';

/// Client-side pointer speed and acceleration for touch-driven cursor
/// movement on mobile ("Mouse mode" and relative mouse mode).
///
/// [speed] scales every movement. When [enabled] is true, fast swipes are
/// additionally multiplied by a gain that grows with finger velocity, so slow
/// movements stay precise while fast ones cover long distances. [strength] is
/// the gain reached at high finger velocity.
///
/// With [enabled] false and [speed] at [kDefaultSpeed], [apply] returns the
/// input delta unchanged.
class PointerAcceleration {
  static const double kMinSpeed = 0.5;
  static const double kMaxSpeed = 3.0;
  static const double kDefaultSpeed = 1.0;

  // Finger velocity (logical pixels per millisecond) up to which no
  // acceleration is applied.
  static const double kLowVelocity = 0.3;
  // Finger velocity at which the maximum gain is reached.
  static const double kHighVelocity = 2.5;
  static const double kMinStrength = 2.0;
  static const double kMaxStrength = 8.0;
  static const double kDefaultStrength = 4.0;
  // A pause longer than this between two events starts a new stroke.
  static const int _strokeGapUs = 100000;
  // Lower bound for the event interval, so batched events with nearly equal
  // timestamps do not produce velocity spikes.
  static const int _minIntervalUs = 4000;
  // Weight of the newest sample in the smoothed velocity.
  static const double _smoothing = 0.5;

  bool enabled = false;
  double _speed = kDefaultSpeed;
  double _strength = kDefaultStrength;

  Duration? _lastTimestamp;
  double _velocity = 0.0;
  final Stopwatch _clock = Stopwatch()..start();

  double get speed => _speed;
  set speed(double v) => _speed = clampSpeed(v);

  static double clampSpeed(double v) {
    if (v.isNaN) return kDefaultSpeed;
    return v.clamp(kMinSpeed, kMaxSpeed).toDouble();
  }

  double get strength => _strength;
  set strength(double v) => _strength = clampStrength(v);

  static double clampStrength(double v) {
    if (v.isNaN) return kDefaultStrength;
    return v.clamp(kMinStrength, kMaxStrength).toDouble();
  }

  /// Forget the previous movement. Call at the start and end of a stroke.
  void reset() {
    _lastTimestamp = null;
    _velocity = 0.0;
  }

  /// Gain for a smoothed finger [velocity] in logical pixels per millisecond.
  double gainForVelocity(double velocity) {
    if (velocity <= kLowVelocity) return 1.0;
    if (velocity >= kHighVelocity) return _strength;
    final t = (velocity - kLowVelocity) / (kHighVelocity - kLowVelocity);
    return 1.0 + (_strength - 1.0) * t;
  }

  /// Returns the cursor movement for a synthetic movement of [delta] at a
  /// known [velocity], e.g. pointer inertia after the finger is lifted.
  Offset applyAtVelocity(Offset delta, double velocity) {
    final gain = enabled ? gainForVelocity(velocity) : 1.0;
    return delta * (_speed * gain);
  }

  /// Returns the cursor movement for a finger movement of [delta].
  ///
  /// [timestamp] should be the event time (e.g.
  /// `DragUpdateDetails.sourceTimeStamp`); if null, an internal clock is used.
  Offset apply(Offset delta, [Duration? timestamp]) {
    if (!enabled) {
      return _speed == kDefaultSpeed ? delta : delta * _speed;
    }
    final now = timestamp ?? _clock.elapsed;
    final last = _lastTimestamp;
    _lastTimestamp = now;
    final intervalUs = last == null ? -1 : (now - last).inMicroseconds;
    if (intervalUs < 0 || intervalUs > _strokeGapUs) {
      // First event of a stroke: no velocity information yet.
      _velocity = 0.0;
      return delta * _speed;
    }
    final ms =
        (intervalUs < _minIntervalUs ? _minIntervalUs : intervalUs) / 1000.0;
    final instant = delta.distance / ms;
    _velocity = _smoothing * instant + (1.0 - _smoothing) * _velocity;
    return delta * (_speed * gainForVelocity(_velocity));
  }
}
