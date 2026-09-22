import 'dart:convert';

import '../core/errors.dart';
import '../numbers/num.dart';
import 'values.dart';

/// Lossless JSON encoding of engine values for persistence and backups.
///
/// Exact rationals stay exact and high-precision decimals keep every digit
/// (and their significance), unlike re-parsing a formatted string.
abstract final class ValueCodec {
  static String encode(Value v) => jsonEncode(toJson(v));

  static Value decode(String s) {
    final Object? j;
    try {
      j = jsonDecode(s);
    } on FormatException {
      throw const MathError(MathErrorCode.invalidExpression, {'detail': 'stored value is corrupted'});
    }
    return fromJson(j);
  }

  static Object toJson(Value v) => switch (v) {
        NumberValue(:final n) => numToJson(n),
        MatrixValue(:final rows) => {'t': 'mat', 'rows': [for (final r in rows) [for (final c in r) numToJson(c)]]},
        VectorValue(:final items) => {'t': 'vec', 'items': [for (final c in items) numToJson(c)]},
        ListValue(:final items) => {'t': 'list', 'items': [for (final c in items) toJson(c)]},
        BoolValue(:final value) => {'t': 'bool', 'v': value},
        InfinityValue(:final sign) => {'t': 'inf', 's': sign},
        FactorizationValue(:final number) => numToJson(Rat(number)),
        SolutionsValue(:final solutions) => {'t': 'list', 'items': [for (final s in solutions) numToJson(s)]},
      };

  static Object numToJson(Num n) => switch (n) {
        Rat r => {'t': 'rat', 'n': r.n.toString(), 'd': r.d.toString()},
        Dec d => {'t': 'dec', 'm': d.m.toString(), 'e': d.e, if (d.sig < (1 << 20)) 's': d.sig},
        Cpx c => {'t': 'cpx', 're': numToJson(c.re), 'im': numToJson(c.im)},
      };

  static const _limits = MathError(MathErrorCode.invalidExpression, {'detail': 'stored value is invalid'});

  static Value fromJson(Object? j) {
    if (j is! Map) throw _limits;
    switch (j['t']) {
      case 'rat' || 'dec' || 'cpx':
        return NumberValue(numFromJson(j));
      case 'mat':
        final rows = j['rows'];
        if (rows is! List || rows.isEmpty || rows.length > 50) throw _limits;
        final parsed = [
          for (final r in rows)
            if (r is List && r.isNotEmpty && r.length <= 50) [for (final c in r) numFromJson(c)] else throw _limits
        ];
        if (parsed.any((r) => r.length != parsed.first.length)) throw _limits;
        return MatrixValue(parsed);
      case 'vec':
        final items = j['items'];
        if (items is! List || items.isEmpty || items.length > 1000) throw _limits;
        return VectorValue([for (final c in items) numFromJson(c)]);
      case 'list':
        final items = j['items'];
        if (items is! List || items.length > 100000) throw _limits;
        return ListValue([for (final c in items) fromJson(c)]);
      case 'bool':
        return BoolValue(j['v'] == true);
      case 'inf':
        return InfinityValue(j['s'] == -1 ? -1 : 1);
    }
    throw _limits;
  }

  static Num numFromJson(Object? j) {
    if (j is! Map) throw _limits;
    switch (j['t']) {
      case 'rat':
        final n = BigInt.tryParse('${j['n']}'), d = BigInt.tryParse('${j['d']}');
        if (n == null || d == null || d <= BigInt.zero || n.bitLength > 500000 || d.bitLength > 100000) throw _limits;
        return Rat(n, d);
      case 'dec':
        final m = BigInt.tryParse('${j['m']}');
        final e = j['e'];
        if (m == null || e is! int || m.bitLength > 2000 || e.abs() > maxDecimalExponent) throw _limits;
        final s = j['s'];
        return Dec(m, e, s is int && s > 0 ? s : 1 << 20);
      case 'cpx':
        final re = numFromJson(j['re']), im = numFromJson(j['im']);
        if (re is Cpx || im is Cpx) throw _limits;
        return Cpx.of(re, im);
    }
    throw _limits;
  }
}
