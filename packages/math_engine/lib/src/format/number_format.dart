import 'dart:math' as math;

import '../eval/evaluator.dart' show AngleMode;
import '../numbers/num.dart';

enum NumberNotation { normal, scientific, engineering }

enum FractionMode { auto, decimal, fraction, mixed }

enum ComplexFormat { rectangular, polar }

class FormatOptions {
  const FormatOptions({
    this.digits = 10,
    this.notation = NumberNotation.normal,
    this.fraction = FractionMode.auto,
    this.thousandsSeparator = false,
    this.groupSeparator = ',',
    this.decimalSeparator = '.',
    this.engineeringSymbols = false,
    this.complexFormat = ComplexFormat.rectangular,
    this.angleMode = AngleMode.deg,
  });

  /// Maximum significant digits displayed.
  final int digits;
  final NumberNotation notation;
  final FractionMode fraction;
  final bool thousandsSeparator;
  final String groupSeparator;
  final String decimalSeparator;

  /// Show engineering results with SI prefixes (1.2M instead of 1.2×10⁶).
  final bool engineeringSymbols;
  final ComplexFormat complexFormat;
  final AngleMode angleMode;

  FormatOptions copyWith({
    int? digits,
    NumberNotation? notation,
    FractionMode? fraction,
    bool? thousandsSeparator,
    String? groupSeparator,
    String? decimalSeparator,
    bool? engineeringSymbols,
    ComplexFormat? complexFormat,
    AngleMode? angleMode,
  }) =>
      FormatOptions(
        digits: digits ?? this.digits,
        notation: notation ?? this.notation,
        fraction: fraction ?? this.fraction,
        thousandsSeparator: thousandsSeparator ?? this.thousandsSeparator,
        groupSeparator: groupSeparator ?? this.groupSeparator,
        decimalSeparator: decimalSeparator ?? this.decimalSeparator,
        engineeringSymbols: engineeringSymbols ?? this.engineeringSymbols,
        complexFormat: complexFormat ?? this.complexFormat,
        angleMode: angleMode ?? this.angleMode,
      );
}

/// A number rendered three ways.
class FormattedNumber {
  const FormattedNumber({required this.plain, required this.display, required this.latex});

  /// Re-parseable text using `E` notation, e.g. `1.23E8`, `5/4`.
  final String plain;

  /// Human-readable Unicode, e.g. `1.23×10⁸`.
  final String display;

  /// LaTeX for textbook rendering.
  final String latex;
}

const _superscripts = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵',
  '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻',
};

String superscript(String s) => s.split('').map((c) => _superscripts[c] ?? c).join();

const _siPrefixes = {
  -15: 'f', -12: 'p', -9: 'n', -6: 'µ', -3: 'm', 3: 'k', 6: 'M', 9: 'G', 12: 'T', 15: 'P',
};

/// Formats real, complex and rational numbers according to [FormatOptions].
class NumberFormatter {
  const NumberFormatter(this.o);
  final FormatOptions o;

  /// Formats [n]. [preferDecimal] applies to [FractionMode.auto].
  FormattedNumber format(Num n, {bool preferDecimal = false}) {
    if (n is Cpx) return _complex(n, preferDecimal);
    return _real(n, preferDecimal);
  }

  FormattedNumber _real(Num n, bool preferDecimal) {
    if (n is Rat && !n.isInteger) {
      final mode = o.fraction;
      final useFraction = mode == FractionMode.fraction ||
          mode == FractionMode.mixed ||
          (mode == FractionMode.auto && !preferDecimal);
      if (useFraction && _digitsOf(n.n) + _digitsOf(n.d) <= 30) {
        return mode == FractionMode.mixed ? _mixed(n) : _fraction(n);
      }
    }
    return _decimal(n);
  }

  int _digitsOf(BigInt v) => digitCount(v);

  FormattedNumber _fraction(Rat r) {
    final neg = r.isNegative ? '-' : '';
    final n = r.n.abs(), d = r.d;
    return FormattedNumber(
      plain: '$neg$n/$d',
      display: '${neg.isEmpty ? '' : '−'}${_group(n.toString())}/${_group(d.toString())}',
      latex: '$neg\\frac{${_groupLatex(n.toString())}}{${_groupLatex(d.toString())}}',
    );
  }

  FormattedNumber _mixed(Rat r) {
    final neg = r.isNegative;
    final a = r.abs();
    final whole = a.n ~/ a.d;
    final rem = a.n - whole * a.d;
    if (whole == BigInt.zero) return _fraction(r);
    final s = neg ? '-' : '';
    return FormattedNumber(
      plain: '$s($whole+$rem/${a.d})',
      display: '${neg ? '−' : ''}${_group(whole.toString())} ${_group(rem.toString())}/${_group(a.d.toString())}',
      latex: '$s${_groupLatex(whole.toString())}\\tfrac{${_groupLatex(rem.toString())}}{${_groupLatex(a.d.toString())}}',
    );
  }

  /// Integer digit string with thousands grouping for display.
  String _group(String digits) {
    if (!o.thousandsSeparator || digits.length <= 3) return digits;
    final b = StringBuffer();
    final first = digits.length % 3;
    if (first > 0) b.write(digits.substring(0, first));
    for (var k = first; k < digits.length; k += 3) {
      if (b.isNotEmpty) b.write(o.groupSeparator);
      b.write(digits.substring(k, k + 3));
    }
    return b.toString();
  }

  String _groupLatex(String digits) {
    final g = _group(digits);
    return g.replaceAll(o.groupSeparator, o.groupSeparator == ',' ? '{,}' : (o.groupSeparator == '.' ? '{.}' : '\\,'));
  }

  FormattedNumber _decimal(Num n) {
    // Exact integers that fit are shown in full.
    if (n is Rat && n.isInteger && o.notation == NumberNotation.normal) {
      final s = n.n.abs().toString();
      if (s.length <= math.max(o.digits, 15)) {
        final neg = n.isNegative;
        return FormattedNumber(
          plain: '${neg ? '-' : ''}$s',
          display: '${neg ? '−' : ''}${_group(s)}',
          latex: '${neg ? '-' : ''}${_groupLatex(s)}',
        );
      }
    }
    var digits = o.digits;
    Dec d;
    if (n is Rat) {
      d = Dec.fromRat(n, digits + 2);
    } else {
      d = n as Dec;
      digits = math.min(digits, math.max(1, d.sig));
    }
    d = d.round(digits);
    if (d.isZero) return const FormattedNumber(plain: '0', display: '0', latex: '0');
    final neg = d.isNegative;
    final mant = d.m.abs().toString(); // significant digits (trailing zeros stripped)
    final mag = d.magnitude;
    switch (o.notation) {
      case NumberNotation.normal:
        if (mag >= -5 && mag < math.max(digits, 10)) {
          return _plain(neg, mant, mag);
        }
        return _sci(neg, mant, mag);
      case NumberNotation.scientific:
        return _sci(neg, mant, mag);
      case NumberNotation.engineering:
        return _eng(neg, mant, mag);
    }
  }

  /// Positional notation of digits `mant` with leading digit at 10^mag.
  FormattedNumber _plain(bool neg, String mant, int mag) {
    String intPart, fracPart;
    if (mag < 0) {
      intPart = '0';
      fracPart = '${'0' * (-mag - 1)}$mant';
    } else if (mant.length <= mag + 1) {
      intPart = mant + '0' * (mag + 1 - mant.length);
      fracPart = '';
    } else {
      intPart = mant.substring(0, mag + 1);
      fracPart = mant.substring(mag + 1);
    }
    final sign = neg ? '-' : '';
    final plain = '$sign$intPart${fracPart.isEmpty ? '' : '.$fracPart'}';
    final disp = '${neg ? '−' : ''}${_group(intPart)}${fracPart.isEmpty ? '' : '${o.decimalSeparator}$fracPart'}';
    final latexSep = o.decimalSeparator == ',' ? '{,}' : '.';
    final latex = '$sign${_groupLatex(intPart)}${fracPart.isEmpty ? '' : '$latexSep$fracPart'}';
    return FormattedNumber(plain: plain, display: disp, latex: latex);
  }

  FormattedNumber _mantissaExp(bool neg, String mant, int intDigits, int exp, {String? prefix}) {
    final m = _plain(neg, mant, intDigits - 1);
    if (prefix != null) {
      return FormattedNumber(
        plain: '${m.plain}E$exp',
        display: '${m.display}$prefix',
        latex: '${m.latex}\\,\\mathrm{$prefix}',
      );
    }
    if (exp == 0) return m;
    return FormattedNumber(
      plain: '${m.plain}E$exp',
      display: '${m.display}×10${superscript('$exp')}',
      latex: '${m.latex}\\times10^{$exp}',
    );
  }

  FormattedNumber _sci(bool neg, String mant, int mag) => _mantissaExp(neg, mant, 1, mag);

  FormattedNumber _eng(bool neg, String mant, int mag) {
    final exp = (mag / 3).floor() * 3;
    final intDigits = mag - exp + 1;
    final padded = mant.length < intDigits ? mant + '0' * (intDigits - mant.length) : mant;
    final prefix = o.engineeringSymbols && exp != 0 ? _siPrefixes[exp] : null;
    return _mantissaExp(neg, padded, intDigits, exp, prefix: prefix);
  }

  // ---------------------------------------------------------------- complex

  FormattedNumber _complex(Cpx z, bool preferDecimal) {
    final a = Arith(precision: o.digits + 5, allowComplex: true);
    // Drop parts that are negligible relative to the other part.
    var re = z.re, im = z.im;
    final rd = re.toDouble().abs(), id = im.toDouble().abs();
    final tiny = math.pow(10, -(o.digits + 1)).toDouble();
    if (re is Dec && rd <= id * tiny) re = Rat.zero;
    if (im is Dec && id <= rd * tiny) im = Rat.zero;
    if (im.isZero) return _real(re, preferDecimal);
    if (o.complexFormat == ComplexFormat.polar) {
      final r = a.abs(Cpx.of(re, im));
      var theta = a.atan2(im, re);
      theta = switch (o.angleMode) {
        AngleMode.rad => theta,
        AngleMode.deg => a.div(a.mul(theta, Rat.int(180)), a.pi()),
        AngleMode.grad => a.div(a.mul(theta, Rat.int(200)), a.pi()),
      };
      final rf = _real(r, true), tf = _real(theta, true);
      final unit = switch (o.angleMode) { AngleMode.deg => '°', AngleMode.rad => '', AngleMode.grad => 'ᵍ' };
      final unitLatex = switch (o.angleMode) { AngleMode.deg => '^{\\circ}', AngleMode.rad => '', AngleMode.grad => '^{g}' };
      return FormattedNumber(
        plain: '${rf.plain}∠${tf.plain}$unit',
        display: '${rf.display}∠${tf.display}$unit',
        latex: '${rf.latex}\\angle {${tf.latex}}$unitLatex',
      );
    }
    final imNeg = (im is Rat && im.isNegative) || (im is Dec && im.isNegative);
    final imAbs = a.abs(im);
    final isOne = imAbs is Rat && imAbs.isOne;
    final imf = _real(imAbs, preferDecimal);
    final imPlain = isOne ? 'i' : '${_wrapFraction(imf.plain)}i';
    final imDisp = isOne ? 'i' : '${imf.display}i';
    final imLatex = isOne ? 'i' : '${imf.latex}i';
    if (re.isZero) {
      return FormattedNumber(
        plain: '${imNeg ? '-' : ''}$imPlain',
        display: '${imNeg ? '−' : ''}$imDisp',
        latex: '${imNeg ? '-' : ''}$imLatex',
      );
    }
    final rf = _real(re, preferDecimal);
    return FormattedNumber(
      plain: '${rf.plain}${imNeg ? '-' : '+'}$imPlain',
      display: '${rf.display} ${imNeg ? '−' : '+'} $imDisp',
      latex: '${rf.latex}${imNeg ? '-' : '+'}$imLatex',
    );
  }

  String _wrapFraction(String s) => s.contains('/') ? '($s)' : s;
}
