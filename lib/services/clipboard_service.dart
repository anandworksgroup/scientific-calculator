import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Clipboard and sharing helpers. Pasted text is sanitized before it ever
/// reaches the parser (§73, §104).
abstract final class ClipboardService {
  static const maxPasteLength = 2000;

  static Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));

  static Future<String?> pasteSanitized() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return null;
    final s = sanitize(text);
    return s.isEmpty ? null : s;
  }

  static final _grouped = RegExp(r'^-?\d{1,3}(,\d{3})+(\.\d+)?$');
  static final _allowed = RegExp(r'[0-9A-Za-z_.,;+\-*/^!%()\[\]=<>|@ πφℯ∞√∛×÷·−–∠°ʳᵍ≤≥≠⁰¹²³⁴⁵⁶⁷⁸⁹⁻ᴇθλμσαβγδωτρ]');

  /// Keeps only characters the expression language understands, maps
  /// common look-alikes, and removes invisible/control characters.
  static String sanitize(String input) {
    var s = input.length > maxPasteLength ? input.substring(0, maxPasteLength) : input;
    s = s
        .replaceAll(RegExp(r'[​-‍﻿­]'), '')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll('−', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('×', '*')
        .replaceAll('⋅', '*')
        .replaceAll('∗', '*')
        .replaceAll('÷', '/')
        .replaceAll('⁄', '/')
        .replaceAll('**', '^')
        .trim();
    // "1,234,567.8" copied from a document: drop grouping commas.
    if (_grouped.hasMatch(s)) s = s.replaceAll(',', '');
    final b = StringBuffer();
    for (final ch in s.runes.map(String.fromCharCode)) {
      if (_allowed.hasMatch(ch)) b.write(ch);
    }
    return b.toString().replaceAll(RegExp(r' {2,}'), ' ').trim();
  }

  static Future<void> share(String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));
}
