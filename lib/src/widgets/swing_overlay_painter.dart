import 'package:flutter/material.dart';

import '../models.dart';

class SwingOverlayPainter extends CustomPainter {
  const SwingOverlayPainter({
    required this.overlay,
    required this.segments,
    this.showSkeleton = true,
    this.showSpine = true,
    this.showGuides = true,
    this.showFaultReference = true,
  });

  final Map<String, dynamic> overlay;
  final List<dynamic> segments;
  final bool showSkeleton;
  final bool showSpine;
  final bool showGuides;
  final bool showFaultReference;

  @override
  void paint(Canvas canvas, Size size) {
    final points = _mapValue(overlay['points']);
    if (points == null) return;

    final skeletonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final jointPaint = Paint()..color = Colors.white;
    final guidePaint = Paint()
      ..color = const Color(0xFFB9FF66).withValues(alpha: 0.92)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final faultPaint = Paint()
      ..color = const Color(0xFFFFC857).withValues(alpha: 0.95)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    if (showSkeleton) {
      for (final segment in segments) {
        final start = _pointOffset(points, _segmentFrom(segment), size);
        final end = _pointOffset(points, _segmentTo(segment), size);
        if (start != null && end != null) {
          canvas.drawLine(start, end, skeletonPaint);
        }
      }
    }

    for (final line in _mapList(overlay['guide_lines'])) {
      final style = line['style'];
      if (style == 'spine' && !showSpine) continue;
      if ((style == 'shoulder' || style == 'hip') && !showGuides) continue;
      if (style == 'fault_reference' && !showFaultReference) continue;

      final paint = style == 'fault_reference' ? faultPaint : guidePaint;
      final start = _pointOffset(points, line['from'], size);
      final end = _pointOffset(points, line['to'], size);
      if (start != null && end != null) {
        canvas.drawLine(start, end, paint);
        continue;
      }
      final x = line['x'];
      if (x is num) {
        final y1 = (line['y1'] as num? ?? 0).clamp(0, 1).toDouble();
        final y2 = (line['y2'] as num? ?? 1).clamp(0, 1).toDouble();
        final dx = x.clamp(0, 1).toDouble() * size.width;
        canvas.drawLine(
          Offset(dx, y1 * size.height),
          Offset(dx, y2 * size.height),
          paint,
        );
      }
    }

    if (!showSkeleton) return;
    for (final value in points.values) {
      final point = _pointOffsetFromMap(value, size);
      if (point != null) {
        canvas.drawCircle(
          point,
          5.8,
          Paint()..color = Colors.black.withValues(alpha: 0.28),
        );
        canvas.drawCircle(point, 3.4, jointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SwingOverlayPainter oldDelegate) {
    return oldDelegate.overlay != overlay ||
        oldDelegate.segments != segments ||
        oldDelegate.showSkeleton != showSkeleton ||
        oldDelegate.showSpine != showSpine ||
        oldDelegate.showGuides != showGuides ||
        oldDelegate.showFaultReference != showFaultReference;
  }
}

String? _segmentFrom(Object? segment) {
  if (segment is OverlaySegment) return segment.from;
  if (segment is Map) return segment['from'] as String?;
  return null;
}

String? _segmentTo(Object? segment) {
  if (segment is OverlaySegment) return segment.to;
  if (segment is Map) return segment['to'] as String?;
  return null;
}

Map<String, dynamic>? _mapValue(Object? value) {
  if (value == null) return null;
  return Map<String, dynamic>.from(value as Map);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value == null) return const [];
  return (value as List<dynamic>)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}

Offset? _pointOffset(Map<String, dynamic> points, Object? name, Size size) {
  if (name is! String) return null;
  return _pointOffsetFromMap(points[name], size);
}

Offset? _pointOffsetFromMap(Object? rawPoint, Size size) {
  if (rawPoint is! Map) return null;
  final x = rawPoint['x'];
  final y = rawPoint['y'];
  if (x is! num || y is! num) return null;
  return Offset(
    x.clamp(0, 1).toDouble() * size.width,
    y.clamp(0, 1).toDouble() * size.height,
  );
}
