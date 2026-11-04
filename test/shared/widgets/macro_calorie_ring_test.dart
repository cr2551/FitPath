import 'dart:math' as math;

import 'package:fitpath/shared/widgets/macro_calorie_ring.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const protein = Color(0xFFFF0000);
const carbs = Color(0xFF00FF00);
const fat = Color(0xFFFFFF00);
const unknown = Color(0xFF999999);
const track = Color(0xFFDDDDDD);
const full = 2 * math.pi;

/// The design example: P 110 g (440 kcal), C 180 g (720), F 53 g (477).
const day = [
  RingSegment(color: protein, kcal: 440),
  RingSegment(color: carbs, kcal: 720),
  RingSegment(color: fat, kcal: 477),
];

List<RingArc> arcs({
  double eaten = 1640,
  double? goal = 2100,
  List<RingSegment> segments = day,
  double gap = 0,
}) => computeRingArcs(
  eatenKcal: eaten,
  goalKcal: goal,
  segments: segments,
  trackColor: track,
  gap: gap,
);

void main() {
  test('on track: colored part = eaten / goal, split by macro', () {
    final a = arcs();
    expect(a.map((x) => x.color), [protein, carbs, fat, track]);
    final colored = a.where((x) => !x.isTrack).fold(0.0, (s, x) => s + x.sweep);
    expect(colored / full, closeTo(1640 / 2100, 1e-9));
    expect(a[0].sweep / colored, closeTo(440 / 1637, 1e-9));
    expect(a[1].sweep / colored, closeTo(720 / 1637, 1e-9));
    expect(a.last.start + a.last.sweep, closeTo(full, 1e-9));
  });

  test('segments run clockwise from 12 o\'clock without overlap', () {
    final a = arcs();
    expect(a.first.start, 0);
    for (var i = 1; i < a.length; i++) {
      expect(a[i].start, closeTo(a[i - 1].start + a[i - 1].sweep, 1e-9));
    }
  });

  test('gaps sit at every boundary and keep proportions', () {
    const gap = 0.1;
    final a = arcs(gap: gap);
    final plain = arcs();
    for (var i = 0; i < a.length; i++) {
      expect(a[i].start, closeTo(plain[i].start + gap / 2, 1e-9));
      expect(a[i].sweep, closeTo(plain[i].sweep - gap, 1e-9));
    }
  });

  test('over target: a full circle, never more than 360 degrees', () {
    final a = arcs(eaten: 2220);
    expect(a.any((x) => x.isTrack), isFalse);
    expect(a.fold(0.0, (s, x) => s + x.sweep), closeTo(full, 1e-9));
  });

  test('nothing logged: only the track, no gaps', () {
    final a = arcs(eaten: 0, segments: const [], gap: 0.1);
    expect(a, hasLength(1));
    expect(a.single.isTrack, isTrue);
    expect(a.single.sweep, full);
  });

  test('no calorie goal: a full circle split by macro', () {
    final a = arcs(goal: null);
    expect(a.map((x) => x.color), [protein, carbs, fat]);
    expect(a.fold(0.0, (s, x) => s + x.sweep), closeTo(full, 1e-9));
  });

  test('unknown macros become their own segment', () {
    final a = arcs(
      segments: const [
        ...day,
        RingSegment(color: unknown, kcal: 210),
      ],
    );
    expect(a.map((x) => x.color), [protein, carbs, fat, unknown, track]);
  });

  test('a single full-circle arc has no gap', () {
    final a = arcs(
      eaten: 500,
      goal: 400,
      segments: const [RingSegment(color: protein, kcal: 500)],
      gap: 0.1,
    );
    expect(a.single.sweep, full);
  });

  test('arcs smaller than the gap are dropped', () {
    final a = arcs(
      segments: const [
        RingSegment(color: protein, kcal: 1),
        RingSegment(color: carbs, kcal: 1636),
      ],
      gap: 0.1,
    );
    expect(a.map((x) => x.color), [carbs, track]);
  });
}
