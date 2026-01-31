import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/detected_class.dart';

class TimetableOCRService {
  /// MAIN ENTRY
  static Future<List<DetectedClass>> extractClasses(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(imageFile);

    try {
      final RecognizedText text =
      await recognizer.processImage(inputImage);

      // ─────────────────────────────────────────────
      // 1. Collect ALL lines with positions
      // ─────────────────────────────────────────────
      final List<_OCRLine> lines = [];

      for (final block in text.blocks) {
        for (final line in block.lines) {
          final rect = line.boundingBox;
          lines.add(
            _OCRLine(
              text: line.text.trim(),
              rect: rect,
            ),
          );
        }
      }

      debugPrint("OCR lines found: ${lines.length}");

      // ─────────────────────────────────────────────
      // 2. Detect TIME COLUMNS from TOP row
      // ─────────────────────────────────────────────
      final timeColumns = _extractTimeColumns(lines);

      if (timeColumns.isEmpty) {
        debugPrint("❌ No time columns detected");
        return [];
      }

      // ─────────────────────────────────────────────
      // 3. Detect DAY ROWS from LEFT column
      // ─────────────────────────────────────────────
      final dayRows = _extractDayRows(lines);

      if (dayRows.isEmpty) {
        debugPrint("❌ No day rows detected");
        return [];
      }

      // ─────────────────────────────────────────────
      // 4. Assign lines into GRID CELLS
      // ─────────────────────────────────────────────
      final results = <DetectedClass>[];

      for (final day in dayRows) {
        for (final time in timeColumns) {
          final cellLines = lines.where((l) {
            return l.rect.left > time.left &&
                l.rect.right < time.right &&
                l.rect.top > day.top &&
                l.rect.bottom < day.bottom;
          }).toList();

          final subjectLine =
          _pickBestSubject(cellLines);

          if (subjectLine == null) continue;

          final confidence =
          _computeConfidence(subjectLine, cellLines);

          results.add(
            DetectedClass(
              weekday: day.weekday,
              startTime: time.start,
              endTime: time.end,
              subject: subjectLine.text.toUpperCase(),
              confidence: confidence,
            ),
          );
        }
      }

      debugPrint("✅ Final extracted classes: ${results.length}");
      return results;
    } finally {
      recognizer.close();
    }
  }

  // ─────────────────────────────────────────────
  // TIME COLUMN DETECTION
  // ─────────────────────────────────────────────

  static List<_TimeColumn> _extractTimeColumns(
      List<_OCRLine> lines) {
    final timeRegex =
    RegExp(r'\d{1,2}[:.]\d{2}\s*-\s*\d{1,2}[:.]\d{2}');

    final headers = lines
        .where((l) => timeRegex.hasMatch(l.text))
        .toList();

    headers.sort((a, b) => a.rect.left.compareTo(b.rect.left));

    return headers.map((h) {
      final match = timeRegex.firstMatch(h.text)!;
      final parts = match.group(0)!.split('-');

      return _TimeColumn(
        start: parts[0].trim(),
        end: parts[1].trim(),
        left: h.rect.left - 10,
        right: h.rect.right + 10,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────
  // DAY ROW DETECTION
  // ─────────────────────────────────────────────

  static List<_DayRow> _extractDayRows(List<_OCRLine> lines) {
    final dayMap = {
      'mo': 1,
      'tu': 2,
      'we': 3,
      'th': 4,
      'fr': 5,
    };

    final rows = <_DayRow>[];

    for (final l in lines) {
      final key = l.text.toLowerCase().substring(0, min(2, l.text.length));
      if (dayMap.containsKey(key)) {
        rows.add(
          _DayRow(
            weekday: dayMap[key]!,
            top: l.rect.top - 10,
            bottom: l.rect.bottom + 80,
          ),
        );
      }
    }

    return rows;
  }

  // ─────────────────────────────────────────────
  // SUBJECT FILTERING (CRITICAL)
  // ─────────────────────────────────────────────

  static _OCRLine? _pickBestSubject(List<_OCRLine> lines) {
    final filtered = lines.where((l) {
      final t = l.text;

      // Reject obvious noise
      if (t.length < 2 || t.length > 18) return false;
      if (RegExp(r'\d').hasMatch(t)) return false;
      if (t.contains('BT') || t.contains('CSEA')) return false;
      if (t.contains('LAB')) return false;
      if (t.contains('DR') || t.contains('K ')) return false;
      if (t.contains('A22') || t.contains('AG')) return false;

      return true;
    }).toList();

    if (filtered.isEmpty) return null;

    filtered.sort(
            (a, b) => b.text.length.compareTo(a.text.length));

    return filtered.first;
  }

  // ─────────────────────────────────────────────
  // CONFIDENCE SCORING
  // ─────────────────────────────────────────────

  static double _computeConfidence(
      _OCRLine subject, List<_OCRLine> cellLines) {
    double score = 0;

    // Text quality
    if (subject.text.length >= 4) {
      score += 0.3;
    }
    if (subject.text == subject.text.toUpperCase()) {
      score += 0.2;
    }

    // Cell isolation
    if (cellLines.length <= 3) {
      score += 0.2;
    }

    // Position stability
    if (subject.rect.height < 40) {
      score += 0.2;
    }

    return score.clamp(0.0, 1.0);
  }
}

// ─────────────────────────────────────────────
// INTERNAL MODELS
// ─────────────────────────────────────────────

class _OCRLine {
  final String text;
  final Rect rect;
  _OCRLine({required this.text, required this.rect});
}

class _TimeColumn {
  final String start;
  final String end;
  final double left;
  final double right;

  _TimeColumn({
    required this.start,
    required this.end,
    required this.left,
    required this.right,
  });
}

class _DayRow {
  final int weekday;
  final double top;
  final double bottom;

  _DayRow({
    required this.weekday,
    required this.top,
    required this.bottom,
  });
}
