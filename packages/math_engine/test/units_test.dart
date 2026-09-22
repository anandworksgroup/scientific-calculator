import 'dart:math' as math;

import 'package:math_engine/src/core/errors.dart';
import 'package:math_engine/src/numbers/num.dart';
import 'package:math_engine/src/units/units.dart';
import 'package:test/test.dart';

void main() {
  final arith = Arith(precision: 15);
  final conv = UnitConverter(arith);

  UnitDef u(String id) {
    final d = unitById(id);
    if (d == null) fail('unknown unit $id');
    return d;
  }

  Rat r(String s) => Rat.parseDecimal(s);
  Num c(String v, String from, String to) => conv.convert(r(v), u(from), u(to));

  void close(Num actual, double expected, [double rel = 1e-12]) {
    final a = actual.toDouble();
    final tol = rel * math.max(1.0, expected.abs());
    expect((a - expected).abs() <= tol, isTrue, reason: 'got $a, expected $expected');
  }

  group('catalog', () {
    test('has all 18 categories', () {
      expect(unitCategories.map((c) => c.id).toSet(), UnitCategoryId.values.toSet());
      expect(unitCategories.length, 18);
    });

    test('ids unique across all categories', () {
      final ids = <String>{};
      for (final c in unitCategories) {
        for (final d in c.units) {
          expect(ids.add(d.id), isTrue, reason: 'duplicate id ${d.id}');
        }
      }
    });

    test('units belong to their category; base unit exists and is identity', () {
      for (final c in unitCategories) {
        expect(c.units.length, greaterThanOrEqualTo(8), reason: c.name);
        for (final d in c.units) {
          expect(d.category, c.id, reason: d.id);
        }
        final base = c.units.where((d) => d.id == c.baseUnitId).toList();
        expect(base, hasLength(1), reason: c.name);
        expect(parseUnitFactor(base.single.factor), Rat.one);
        expect(parseUnitFactor(base.single.offset), Rat.zero);
        expect(base.single.kind, UnitKind.linear);
        expect(base.single.piScaled, isFalse);
        expect(unitById(c.baseUnitId), same(base.single));
      }
    });

    test('every factor and offset parses to a nonzero exact rational', () {
      for (final c in unitCategories) {
        for (final d in c.units) {
          expect(parseUnitFactor(d.factor).isZero, isFalse, reason: d.id);
          parseUnitFactor(d.offset);
          expect(d.name, isNotEmpty);
          expect(d.symbol, isNotEmpty);
        }
      }
    });

    test('pi-scaled units are only radian-based', () {
      final pi = [
        for (final c in unitCategories)
          for (final d in c.units)
            if (d.piScaled) d.id,
      ];
      expect(pi.toSet(), {'angle.rad', 'angle.mrad', 'frequency.radps'});
    });

    test('factor parser', () {
      expect(parseUnitFactor('1/3.6'), Rat.frac(5, 18));
      expect(parseUnitFactor('0.45359237*9.80665/0.3048').toDouble(), closeTo(14.593902937206364, 1e-12));
      expect(parseUnitFactor('4.4482216152605/0.00064516').toDouble(), closeTo(6894.757293168361, 1e-9));
      expect(parseUnitFactor('1e-3'), Rat.frac(1, 1000));
    });

    test('unitById unknown returns null', () {
      expect(unitById('nope.nope'), isNull);
    });
  });

  group('round trips', () {
    for (final cat in unitCategories) {
      test('all pairs in ${cat.name}', () {
        final x = r('3.7');
        for (final a in cat.units) {
          for (final b in cat.units) {
            final there = conv.convert(x, a, b);
            final back = conv.convert(there, b, a);
            if (a.piScaled || b.piScaled) {
              close(back, 3.7);
            } else {
              expect(there, isA<Rat>(), reason: '${a.id}->${b.id}');
              expect(back, x, reason: '${a.id}->${b.id}->${a.id}');
            }
          }
        }
      });
    }

    test('toBase / fromBase are inverse', () {
      for (final cat in unitCategories) {
        for (final d in cat.units) {
          if (d.piScaled) continue;
          expect(conv.fromBase(conv.toBase(r('12.5'), d), d), r('12.5'), reason: d.id);
        }
      }
    });
  });

  group('spot checks', () {
    test('length', () {
      expect(c('1', 'length.km', 'length.m'), Rat.int(1000));
      expect(c('1', 'length.mi', 'length.km'), r('1.609344'));
      expect(c('1', 'length.ft', 'length.m'), r('0.3048'));
      expect(c('12', 'length.in', 'length.ft'), Rat.one);
      expect(c('1', 'length.nmi', 'length.m'), Rat.int(1852));
      expect(c('72', 'length.pt', 'length.in'), Rat.one);
    });

    test('temperature', () {
      expect(c('100', 'temperature.c', 'temperature.f'), Rat.int(212));
      expect(c('0', 'temperature.c', 'temperature.k'), r('273.15'));
      expect(c('-40', 'temperature.c', 'temperature.f'), Rat.int(-40));
      expect(c('32', 'temperature.f', 'temperature.c'), Rat.zero);
      expect(c('0', 'temperature.k', 'temperature.r'), Rat.zero);
      expect(c('0', 'temperature.f', 'temperature.r'), r('459.67'));
      expect(c('100', 'temperature.c', 'temperature.de'), Rat.zero);
      expect(c('0', 'temperature.c', 'temperature.de'), Rat.int(150));
      expect(c('100', 'temperature.c', 'temperature.re'), Rat.int(80));
      expect(c('100', 'temperature.c', 'temperature.n'), Rat.int(33));
      expect(c('100', 'temperature.c', 'temperature.ro'), Rat.int(60));
      expect(c('0', 'temperature.c', 'temperature.ro'), r('7.5'));
      expect(c('-273.15', 'temperature.c', 'temperature.k'), Rat.zero);
    });

    test('below absolute zero throws domainError', () {
      Matcher domain = throwsA(isA<MathError>().having((e) => e.code, 'code', MathErrorCode.domainError));
      expect(() => c('-300', 'temperature.c', 'temperature.f'), domain);
      expect(() => c('-1', 'temperature.k', 'temperature.c'), domain);
      expect(() => c('-500', 'temperature.f', 'temperature.k'), domain);
      expect(() => c('-1', 'temperature.r', 'temperature.r'), domain);
      expect(() => c('600', 'temperature.de', 'temperature.c'), domain);
      expect(() => conv.fromBase(r('-0.5'), u('temperature.c')), domain);
    });

    test('fuel economy', () {
      close(c('1', 'fuel.l100km', 'fuel.mpg_us'), 235.2145833333333, 1e-12);
      close(c('10', 'fuel.l100km', 'fuel.mpg_imp'), 28.248093633182, 1e-10);
      expect(c('5', 'fuel.l100km', 'fuel.kmpl'), Rat.int(20));
      expect(c('20', 'fuel.kmpl', 'fuel.l100km'), Rat.int(5));
      expect(c('1', 'fuel.mpl', 'fuel.kmpl'), r('1.609344'));
      close(c('25', 'fuel.mpg_us', 'fuel.gal100mi_us'), 4.0);
    });

    test('reciprocal of zero throws divisionByZero', () {
      Matcher dz = throwsA(isA<MathError>().having((e) => e.code, 'code', MathErrorCode.divisionByZero));
      expect(() => c('0', 'fuel.l100km', 'fuel.kmpl'), dz);
      expect(() => c('0', 'fuel.kmpl', 'fuel.l100km'), dz);
      expect(() => c('0', 'fuel.mpg_us', 'fuel.gal100mi_us'), dz);
    });

    test('data', () {
      expect(c('1', 'data.kib', 'data.bit'), Rat.int(8192));
      expect(c('1', 'data.gib', 'data.mib'), Rat.int(1024));
      expect(c('1', 'data.gb', 'data.mb'), Rat.int(1000));
      expect(c('1', 'data.byte', 'data.nibble'), Rat.int(2));
      expect(c('1', 'data.pib', 'data.tib'), Rat.int(1024));
      expect(c('1', 'data.eib', 'data.pib'), Rat.int(1024));
    });

    test('angle', () {
      close(c('180', 'angle.deg', 'angle.rad'), math.pi);
      close(c('1', 'angle.rad', 'angle.deg'), 180 / math.pi);
      close(c('1000', 'angle.mrad', 'angle.rad'), 1.0);
      expect(c('1', 'angle.deg', 'angle.arcsec'), Rat.int(3600));
      expect(c('90', 'angle.deg', 'angle.grad'), Rat.int(100));
      expect(c('1', 'angle.turn', 'angle.deg'), Rat.int(360));
      expect(c('1', 'angle.turn', 'angle.mil'), Rat.int(6400));
      close(c('1', 'angle.turn', 'angle.rad'), 2 * math.pi);
    });

    test('frequency', () {
      expect(c('60', 'frequency.rpm', 'frequency.hz'), Rat.one);
      close(c('1', 'frequency.hz', 'frequency.radps'), 2 * math.pi);
      expect(c('1', 'frequency.ghz', 'frequency.mhz'), Rat.int(1000));
    });

    test('time', () {
      expect(c('1', 'time.yr', 'time.d'), r('365.2425'));
      expect(c('1', 'time.yr_julian', 'time.d'), r('365.25'));
      expect(c('1', 'time.mo', 'time.d'), r('30.436875'));
      expect(c('12', 'time.mo', 'time.yr'), Rat.one);
      expect(c('1', 'time.fortnight', 'time.h'), Rat.int(336));
      expect(c('1', 'time.century', 'time.decade'), Rat.int(10));
    });

    test('energy and power', () {
      expect(c('1', 'energy.kwh', 'energy.j'), Rat.int(3600000));
      expect(c('1', 'energy.ev', 'energy.j'), r('1.602176634e-19'));
      expect(c('1', 'energy.kcal', 'energy.cal'), Rat.int(1000));
      expect(c('1', 'energy.btu', 'energy.j'), r('1055.05585262'));
      expect(c('1', 'energy.therm', 'energy.btu').toDouble(), closeTo(99976.1, 0.1));
      expect(c('1', 'power.hp', 'power.w'), r('745.69987158227022'));
      expect(c('1', 'power.ps', 'power.w'), r('735.49875'));
      close(c('1', 'power.tr', 'power.w'), 3516.8528420667, 1e-12);
    });

    test('pressure', () {
      expect(c('1', 'pressure.atm', 'pressure.torr'), Rat.int(760));
      close(c('1', 'pressure.atm', 'pressure.mmhg'), 760, 1e-6);
      close(c('1', 'pressure.psi', 'pressure.pa'), 6894.757293168361);
      expect(c('1', 'pressure.bar', 'pressure.kpa'), Rat.int(100));
      close(c('1', 'pressure.inhg', 'pressure.pa'), 3386.388640341);
      expect(c('1', 'pressure.ksi', 'pressure.psi'), Rat.int(1000));
    });

    test('mass, force, torque, density, misc', () {
      expect(c('1', 'mass.lb', 'mass.kg'), r('0.45359237'));
      expect(c('16', 'mass.oz', 'mass.lb'), Rat.one);
      expect(c('14', 'mass.lb', 'mass.st'), Rat.one);
      expect(c('2000', 'mass.lb', 'mass.ton_us'), Rat.one);
      expect(c('2240', 'mass.lb', 'mass.ton_imp'), Rat.one);
      expect(c('7000', 'mass.gr', 'mass.lb'), Rat.one);
      close(c('1', 'mass.slug', 'mass.kg'), 14.593902937206364);
      expect(c('1', 'force.lbf', 'force.n'), r('4.4482216152605'));
      expect(c('1', 'force.kip', 'force.lbf'), Rat.int(1000));
      expect(c('1', 'force.kgf', 'force.dyn'), r('980665'));
      expect(c('12', 'torque.lbfin', 'torque.lbfft'), Rat.one);
      close(c('1', 'torque.lbfft', 'torque.nm'), 1.3558179483314004);
      expect(c('1', 'density.gcm3', 'density.kgm3'), Rat.int(1000));
      close(c('1', 'density.lbft3', 'density.kgm3'), 16.018463373960138);
      expect(c('1', 'acceleration.g0', 'acceleration.mps2'), r('9.80665'));
      expect(c('1', 'acceleration.gal', 'acceleration.cmps2'), Rat.one);
      expect(c('1', 'area.acre', 'area.m2'), r('4046.8564224'));
      expect(c('640', 'area.acre', 'area.mi2'), Rat.one);
      expect(c('1', 'area.ha', 'area.m2'), Rat.int(10000));
      expect(c('1', 'volume.gal_us', 'volume.l'), r('3.785411784'));
      expect(c('1', 'volume.gal_imp', 'volume.l'), r('4.54609'));
      expect(c('1', 'volume.bbl', 'volume.gal_us'), Rat.int(42));
      expect(c('128', 'volume.floz_us', 'volume.gal_us'), Rat.one);
      expect(c('160', 'volume.floz_imp', 'volume.gal_imp'), Rat.one);
      expect(c('3', 'volume.tsp_us', 'volume.tbsp_us'), Rat.one);
      expect(c('1', 'volume.ft3', 'volume.in3'), Rat.int(1728));
      expect(c('36', 'speed.kmh', 'speed.mps'), Rat.int(10));
      expect(c('1', 'speed.kn', 'speed.kmh'), r('1.852'));
      expect(c('1', 'speed.mph', 'speed.kmh'), r('1.609344'));
    });

    test('decimal (Dec) inputs work', () {
      final v = conv.convert(arith.fromDouble(2.5), u('length.km'), u('length.m'));
      expect(v.toDouble(), closeTo(2500, 1e-9));
    });

    test('cross-category conversion is rejected', () {
      expect(() => conv.convert(Rat.one, u('length.m'), u('mass.kg')), throwsA(isA<MathError>()));
    });
  });

  group('search', () {
    test('kilo finds km, kg and others', () {
      final ids = searchUnits('kilo').map((d) => d.id).toSet();
      expect(ids, containsAll(['length.km', 'mass.kg', 'energy.kwh', 'power.kw', 'data.kb']));
    });

    test('case-insensitive, symbol and alias matching', () {
      expect(searchUnits('KM').map((d) => d.id), contains('length.km'));
      expect(searchUnits('metre').map((d) => d.id), contains('length.m'));
      expect(searchUnits('micro').map((d) => d.id), containsAll(['length.um', 'mass.ug', 'time.us']));
      expect(searchUnits('µ').map((d) => d.id), contains('length.um'));
      expect(searchUnits('mpg').map((d) => d.id), containsAll(['fuel.mpg_us', 'fuel.mpg_imp']));
    });

    test('category filter and empty query', () {
      final res = searchUnits('kilo', category: UnitCategoryId.mass);
      expect(res, isNotEmpty);
      expect(res.every((d) => d.category == UnitCategoryId.mass), isTrue);
      expect(searchUnits('', category: UnitCategoryId.angle).length,
          unitCategories.firstWhere((c) => c.id == UnitCategoryId.angle).units.length);
      expect(searchUnits('zzzz-no-such-unit'), isEmpty);
    });
  });
}
