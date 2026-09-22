/// Offline unit conversion over the engine's exact number tower.
///
/// Every unit is defined relative to its category's base unit by an exact
/// decimal (or `a*b/c*d` product/quotient of exact decimals) so conversions
/// between rational inputs stay exact. The only irrational factor is 2π for
/// radian-based units ([UnitDef.piScaled]), computed with [Arith.pi].
library;

import '../core/errors.dart';
import '../numbers/num.dart';

enum UnitCategoryId {
  length,
  area,
  volume,
  mass,
  time,
  temperature,
  speed,
  acceleration,
  pressure,
  energy,
  power,
  force,
  angle,
  frequency,
  data,
  fuelEconomy,
  density,
  torque,
}

/// How a unit maps to its category's base unit.
enum UnitKind {
  /// `base = value * factor`
  linear,

  /// `base = value * factor + offset` (temperature scales)
  affine,

  /// `base = factor / value` (e.g. L/100 km against km/L)
  reciprocal,
}

class UnitDef {
  const UnitDef({
    required this.id,
    required this.name,
    required this.symbol,
    required this.category,
    required this.factor,
    this.offset = '0',
    this.kind = UnitKind.linear,
    this.aliases = const [],
    this.system,
    this.piScaled = false,
  });

  /// Stable id, unique across all categories, e.g. `length.km`.
  final String id;
  final String name;
  final String symbol;
  final UnitCategoryId category;

  /// Exact decimal, or `a/b` where each side is a `*`-separated product of
  /// exact decimals. Linear/affine: `base = value*factor + offset`.
  /// Reciprocal: `base = factor / value`.
  final String factor;
  final String offset;
  final UnitKind kind;

  /// Extra search terms.
  final List<String> aliases;

  /// 'SI', 'Imperial', 'US customary', 'approx', ... (informational).
  final String? system;

  /// When true, the effective factor is additionally divided by 2π
  /// (radian-based units against a turn / hertz base).
  final bool piScaled;

  @override
  String toString() => 'UnitDef($id)';
}

class UnitCategory {
  const UnitCategory(this.id, this.name, this.baseUnitId, this.units);
  final UnitCategoryId id;
  final String name;
  final String baseUnitId;
  final List<UnitDef> units;
}

// ---------------------------------------------------------------- helpers

final Map<String, Rat> _ratCache = {};

/// Parses `1.5`, `1e-3`, `a/b`, `a*b/c*d` exactly.
Rat parseUnitFactor(String s) => _ratCache.putIfAbsent(s, () {
      final parts = s.split('/');
      if (parts.length > 2) {
        throw FormatException('Too many "/" in unit factor', s);
      }
      Rat product(String p) {
        var r = Rat.one;
        for (final f in p.split('*')) {
          r = r * Rat.parseDecimal(f.trim());
        }
        return r;
      }

      final top = product(parts[0]);
      if (parts.length == 1) return top;
      final den = product(parts[1]);
      if (den.isZero) throw FormatException('Zero denominator in unit factor', s);
      return top / den;
    });

Map<String, UnitDef>? _byId;

UnitDef? unitById(String id) {
  _byId ??= {
    for (final c in unitCategories)
      for (final u in c.units) u.id: u,
  };
  return _byId![id];
}

UnitCategory categoryOf(UnitCategoryId id) => unitCategories.firstWhere((c) => c.id == id);

/// Case-insensitive substring search over name, symbol and aliases.
/// An empty query returns every unit (of [category], if given).
List<UnitDef> searchUnits(String query, {UnitCategoryId? category}) {
  final q = query.trim().toLowerCase();
  final out = <UnitDef>[];
  for (final c in unitCategories) {
    if (category != null && c.id != category) continue;
    for (final u in c.units) {
      if (q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.symbol.toLowerCase().contains(q) ||
          u.aliases.any((a) => a.toLowerCase().contains(q))) {
        out.add(u);
      }
    }
  }
  return out;
}

// -------------------------------------------------------------- converter

class UnitConverter {
  UnitConverter(this.a);
  final Arith a;

  Num? _twoPi;
  Num get _tau => _twoPi ??= a.mul(Rat.two, a.pi());

  Num convert(Num value, UnitDef from, UnitDef to) {
    if (from.category != to.category) {
      throw MathError(MathErrorCode.dimensionMismatch,
          {'detail': 'Cannot convert ${from.symbol} to ${to.symbol}.'});
    }
    if (from.id == to.id) {
      _checkTemperature(toBase(value, from), from);
      return value;
    }
    return fromBase(toBase(value, from), to);
  }

  Num toBase(Num value, UnitDef u) {
    final f = parseUnitFactor(u.factor);
    Num base;
    switch (u.kind) {
      case UnitKind.linear:
      case UnitKind.affine:
        base = a.mul(value, f);
        if (u.piScaled) base = a.div(base, _tau);
        final o = parseUnitFactor(u.offset);
        if (!o.isZero) base = a.add(base, o);
      case UnitKind.reciprocal:
        Num k = f;
        if (u.piScaled) k = a.div(k, _tau);
        base = a.div(k, value); // throws divisionByZero for 0
    }
    _checkTemperature(base, u);
    return base;
  }

  Num fromBase(Num base, UnitDef u) {
    _checkTemperature(base, u);
    final f = parseUnitFactor(u.factor);
    switch (u.kind) {
      case UnitKind.linear:
      case UnitKind.affine:
        final o = parseUnitFactor(u.offset);
        var v = o.isZero ? base : a.sub(base, o);
        if (u.piScaled) v = a.mul(v, _tau);
        return a.div(v, f);
      case UnitKind.reciprocal:
        Num k = f;
        if (u.piScaled) k = a.div(k, _tau);
        return a.div(k, base);
    }
  }

  void _checkTemperature(Num base, UnitDef u) {
    if (u.category != UnitCategoryId.temperature || !Arith.isReal(base)) return;
    if (a.signOf(base) < 0) {
      throw MathError(MathErrorCode.domainError, {
        'function': 'temperature',
        'value': 'below absolute zero',
      });
    }
  }
}

// ------------------------------------------------------------ unit tables

// Shared exact building blocks (documented here, inlined below):
//   inch = 0.0254 m, foot = 0.3048 m, pound = 0.45359237 kg,
//   g0 = 9.80665 m/s², lbf = 4.4482216152605 N, US gal = 3.785411784 L,
//   imp gal = 4.54609 L, BTU(IT) = 1055.05585262 J.

const _l = UnitCategoryId.length;
const _lengthUnits = <UnitDef>[
  UnitDef(id: 'length.m', name: 'Meter', symbol: 'm', category: _l, factor: '1', aliases: ['metre', 'meters', 'metres'], system: 'SI'),
  UnitDef(id: 'length.km', name: 'Kilometer', symbol: 'km', category: _l, factor: '1000', aliases: ['kilometre', 'kilometers', 'kilometres'], system: 'SI'),
  UnitDef(id: 'length.dm', name: 'Decimeter', symbol: 'dm', category: _l, factor: '0.1', aliases: ['decimetre'], system: 'SI'),
  UnitDef(id: 'length.cm', name: 'Centimeter', symbol: 'cm', category: _l, factor: '0.01', aliases: ['centimetre', 'centimeters'], system: 'SI'),
  UnitDef(id: 'length.mm', name: 'Millimeter', symbol: 'mm', category: _l, factor: '0.001', aliases: ['millimetre', 'millimeters'], system: 'SI'),
  UnitDef(id: 'length.um', name: 'Micrometer', symbol: 'µm', category: _l, factor: '1e-6', aliases: ['um', 'micron', 'micrometre', 'micro'], system: 'SI'),
  UnitDef(id: 'length.nm', name: 'Nanometer', symbol: 'nm', category: _l, factor: '1e-9', aliases: ['nanometre'], system: 'SI'),
  UnitDef(id: 'length.pm', name: 'Picometer', symbol: 'pm', category: _l, factor: '1e-12', aliases: ['picometre'], system: 'SI'),
  UnitDef(id: 'length.angstrom', name: 'Ångström', symbol: 'Å', category: _l, factor: '1e-10', aliases: ['angstrom', 'A'], system: 'Metric'),
  UnitDef(id: 'length.in', name: 'Inch', symbol: 'in', category: _l, factor: '0.0254', aliases: ['inches', '"'], system: 'Imperial/US'),
  UnitDef(id: 'length.ft', name: 'Foot', symbol: 'ft', category: _l, factor: '0.3048', aliases: ['feet', "'"], system: 'Imperial/US'),
  UnitDef(id: 'length.yd', name: 'Yard', symbol: 'yd', category: _l, factor: '0.9144', aliases: ['yards'], system: 'Imperial/US'),
  UnitDef(id: 'length.mi', name: 'Mile', symbol: 'mi', category: _l, factor: '1609.344', aliases: ['miles', 'statute mile'], system: 'Imperial/US'),
  UnitDef(id: 'length.nmi', name: 'Nautical mile', symbol: 'nmi', category: _l, factor: '1852', aliases: ['NM', 'nautical miles'], system: 'Nautical'),
  UnitDef(id: 'length.mil', name: 'Mil (thou)', symbol: 'mil', category: _l, factor: '0.0000254', aliases: ['thou', 'thousandth of an inch'], system: 'Imperial/US'),
  UnitDef(id: 'length.pt', name: 'Point (typographic)', symbol: 'pt', category: _l, factor: '0.0254/72', aliases: ['point', 'DTP point'], system: 'Typography'),
  UnitDef(id: 'length.hand', name: 'Hand', symbol: 'hh', category: _l, factor: '0.1016', aliases: ['hands'], system: 'Imperial'),
  UnitDef(id: 'length.fathom', name: 'Fathom', symbol: 'ftm', category: _l, factor: '1.8288', aliases: ['fathoms'], system: 'Imperial/US'),
  UnitDef(id: 'length.rod', name: 'Rod', symbol: 'rd', category: _l, factor: '5.0292', aliases: ['pole', 'perch'], system: 'Imperial/US'),
  UnitDef(id: 'length.chain', name: 'Chain', symbol: 'ch', category: _l, factor: '20.1168', aliases: ['chains'], system: 'Imperial/US'),
  UnitDef(id: 'length.furlong', name: 'Furlong', symbol: 'fur', category: _l, factor: '201.168', aliases: ['furlongs'], system: 'Imperial/US'),
  UnitDef(id: 'length.league', name: 'League', symbol: 'lea', category: _l, factor: '4828.032', aliases: ['leagues'], system: 'Imperial/US'),
  UnitDef(id: 'length.ftus', name: 'US survey foot', symbol: 'ft (US)', category: _l, factor: '1200/3937', aliases: ['survey foot'], system: 'US customary'),
  UnitDef(id: 'length.au', name: 'Astronomical unit', symbol: 'au', category: _l, factor: '149597870700', aliases: ['AU'], system: 'Astronomical'),
  UnitDef(id: 'length.ly', name: 'Light-year', symbol: 'ly', category: _l, factor: '9460730472580800', aliases: ['light year', 'lightyear'], system: 'Astronomical'),
  UnitDef(id: 'length.pc', name: 'Parsec', symbol: 'pc', category: _l, factor: '30856775814913673', aliases: ['parsecs'], system: 'approx'),
];

const _ar = UnitCategoryId.area;
const _areaUnits = <UnitDef>[
  UnitDef(id: 'area.m2', name: 'Square meter', symbol: 'm²', category: _ar, factor: '1', aliases: ['m2', 'sq m', 'square metre'], system: 'SI'),
  UnitDef(id: 'area.km2', name: 'Square kilometer', symbol: 'km²', category: _ar, factor: '1e6', aliases: ['km2', 'sq km', 'square kilometre'], system: 'SI'),
  UnitDef(id: 'area.cm2', name: 'Square centimeter', symbol: 'cm²', category: _ar, factor: '1e-4', aliases: ['cm2', 'sq cm'], system: 'SI'),
  UnitDef(id: 'area.mm2', name: 'Square millimeter', symbol: 'mm²', category: _ar, factor: '1e-6', aliases: ['mm2', 'sq mm'], system: 'SI'),
  UnitDef(id: 'area.um2', name: 'Square micrometer', symbol: 'µm²', category: _ar, factor: '1e-12', aliases: ['um2', 'micro'], system: 'SI'),
  UnitDef(id: 'area.ha', name: 'Hectare', symbol: 'ha', category: _ar, factor: '10000', aliases: ['hectares'], system: 'Metric'),
  UnitDef(id: 'area.are', name: 'Are', symbol: 'a', category: _ar, factor: '100', aliases: ['ares'], system: 'Metric'),
  UnitDef(id: 'area.dunam', name: 'Dunam', symbol: 'dunam', category: _ar, factor: '1000', aliases: ['dönüm', 'metric dunam'], system: 'Metric'),
  UnitDef(id: 'area.in2', name: 'Square inch', symbol: 'in²', category: _ar, factor: '0.00064516', aliases: ['in2', 'sq in'], system: 'Imperial/US'),
  UnitDef(id: 'area.ft2', name: 'Square foot', symbol: 'ft²', category: _ar, factor: '0.09290304', aliases: ['ft2', 'sq ft', 'square feet'], system: 'Imperial/US'),
  UnitDef(id: 'area.yd2', name: 'Square yard', symbol: 'yd²', category: _ar, factor: '0.83612736', aliases: ['yd2', 'sq yd'], system: 'Imperial/US'),
  UnitDef(id: 'area.mi2', name: 'Square mile', symbol: 'mi²', category: _ar, factor: '2589988.110336', aliases: ['mi2', 'sq mi'], system: 'Imperial/US'),
  UnitDef(id: 'area.acre', name: 'Acre', symbol: 'ac', category: _ar, factor: '4046.8564224', aliases: ['acres'], system: 'Imperial/US'),
  UnitDef(id: 'area.rood', name: 'Rood', symbol: 'ro', category: _ar, factor: '1011.7141056', aliases: ['roods'], system: 'Imperial'),
  UnitDef(id: 'area.barn', name: 'Barn', symbol: 'b', category: _ar, factor: '1e-28', aliases: ['barns'], system: 'Physics'),
];

const _v = UnitCategoryId.volume;
const _volumeUnits = <UnitDef>[
  UnitDef(id: 'volume.m3', name: 'Cubic meter', symbol: 'm³', category: _v, factor: '1', aliases: ['m3', 'cubic metre'], system: 'SI'),
  UnitDef(id: 'volume.km3', name: 'Cubic kilometer', symbol: 'km³', category: _v, factor: '1e9', aliases: ['km3'], system: 'SI'),
  UnitDef(id: 'volume.cm3', name: 'Cubic centimeter', symbol: 'cm³', category: _v, factor: '1e-6', aliases: ['cm3', 'cc', 'ccm'], system: 'SI'),
  UnitDef(id: 'volume.mm3', name: 'Cubic millimeter', symbol: 'mm³', category: _v, factor: '1e-9', aliases: ['mm3'], system: 'SI'),
  UnitDef(id: 'volume.l', name: 'Liter', symbol: 'L', category: _v, factor: '0.001', aliases: ['litre', 'liters', 'litres', 'l'], system: 'Metric'),
  UnitDef(id: 'volume.hl', name: 'Hectoliter', symbol: 'hL', category: _v, factor: '0.1', aliases: ['hectolitre'], system: 'Metric'),
  UnitDef(id: 'volume.dl', name: 'Deciliter', symbol: 'dL', category: _v, factor: '0.0001', aliases: ['decilitre'], system: 'Metric'),
  UnitDef(id: 'volume.cl', name: 'Centiliter', symbol: 'cL', category: _v, factor: '0.00001', aliases: ['centilitre'], system: 'Metric'),
  UnitDef(id: 'volume.ml', name: 'Milliliter', symbol: 'mL', category: _v, factor: '0.000001', aliases: ['millilitre', 'ml'], system: 'Metric'),
  UnitDef(id: 'volume.ul', name: 'Microliter', symbol: 'µL', category: _v, factor: '1e-9', aliases: ['uL', 'microlitre', 'micro'], system: 'Metric'),
  UnitDef(id: 'volume.cup_metric', name: 'Metric cup', symbol: 'cup (metric)', category: _v, factor: '0.00025', aliases: ['cup'], system: 'Metric'),
  UnitDef(id: 'volume.gal_us', name: 'US gallon', symbol: 'gal (US)', category: _v, factor: '0.003785411784', aliases: ['gallon', 'gallons', 'gal'], system: 'US customary'),
  UnitDef(id: 'volume.qt_us', name: 'US quart', symbol: 'qt (US)', category: _v, factor: '0.000946352946', aliases: ['quart', 'qt'], system: 'US customary'),
  UnitDef(id: 'volume.pt_us', name: 'US pint', symbol: 'pt (US)', category: _v, factor: '0.000473176473', aliases: ['pint', 'pt'], system: 'US customary'),
  UnitDef(id: 'volume.cup_us', name: 'US cup', symbol: 'cup (US)', category: _v, factor: '0.0002365882365', aliases: ['cup', 'cups'], system: 'US customary'),
  UnitDef(id: 'volume.floz_us', name: 'US fluid ounce', symbol: 'fl oz (US)', category: _v, factor: '0.0000295735295625', aliases: ['fluid ounce', 'floz', 'oz'], system: 'US customary'),
  UnitDef(id: 'volume.tbsp_us', name: 'US tablespoon', symbol: 'tbsp', category: _v, factor: '0.00001478676478125', aliases: ['tablespoon', 'tbs'], system: 'US customary'),
  UnitDef(id: 'volume.tsp_us', name: 'US teaspoon', symbol: 'tsp', category: _v, factor: '0.00000492892159375', aliases: ['teaspoon'], system: 'US customary'),
  UnitDef(id: 'volume.gal_imp', name: 'Imperial gallon', symbol: 'gal (imp)', category: _v, factor: '0.00454609', aliases: ['gallon', 'uk gallon', 'gal'], system: 'Imperial'),
  UnitDef(id: 'volume.qt_imp', name: 'Imperial quart', symbol: 'qt (imp)', category: _v, factor: '0.0011365225', aliases: ['quart', 'uk quart'], system: 'Imperial'),
  UnitDef(id: 'volume.pt_imp', name: 'Imperial pint', symbol: 'pt (imp)', category: _v, factor: '0.00056826125', aliases: ['pint', 'uk pint'], system: 'Imperial'),
  UnitDef(id: 'volume.floz_imp', name: 'Imperial fluid ounce', symbol: 'fl oz (imp)', category: _v, factor: '0.0000284130625', aliases: ['fluid ounce', 'uk fl oz'], system: 'Imperial'),
  UnitDef(id: 'volume.in3', name: 'Cubic inch', symbol: 'in³', category: _v, factor: '0.000016387064', aliases: ['in3', 'cu in'], system: 'Imperial/US'),
  UnitDef(id: 'volume.ft3', name: 'Cubic foot', symbol: 'ft³', category: _v, factor: '0.028316846592', aliases: ['ft3', 'cu ft', 'cubic feet'], system: 'Imperial/US'),
  UnitDef(id: 'volume.yd3', name: 'Cubic yard', symbol: 'yd³', category: _v, factor: '0.764554857984', aliases: ['yd3', 'cu yd'], system: 'Imperial/US'),
  UnitDef(id: 'volume.bbl', name: 'Barrel (oil)', symbol: 'bbl', category: _v, factor: '0.158987294928', aliases: ['barrel', 'oil barrel'], system: 'US customary'),
  UnitDef(id: 'volume.acre_ft', name: 'Acre-foot', symbol: 'ac·ft', category: _v, factor: '1233.48183754752', aliases: ['acre foot', 'acre-ft'], system: 'US customary'),
];

const _m = UnitCategoryId.mass;
const _massUnits = <UnitDef>[
  UnitDef(id: 'mass.kg', name: 'Kilogram', symbol: 'kg', category: _m, factor: '1', aliases: ['kilogramme', 'kilograms', 'kilo'], system: 'SI'),
  UnitDef(id: 'mass.g', name: 'Gram', symbol: 'g', category: _m, factor: '0.001', aliases: ['gramme', 'grams'], system: 'SI'),
  UnitDef(id: 'mass.mg', name: 'Milligram', symbol: 'mg', category: _m, factor: '0.000001', aliases: ['milligramme'], system: 'SI'),
  UnitDef(id: 'mass.ug', name: 'Microgram', symbol: 'µg', category: _m, factor: '1e-9', aliases: ['ug', 'mcg', 'microgramme', 'micro'], system: 'SI'),
  UnitDef(id: 'mass.ng', name: 'Nanogram', symbol: 'ng', category: _m, factor: '1e-12', aliases: ['nanogramme'], system: 'SI'),
  UnitDef(id: 'mass.t', name: 'Tonne', symbol: 't', category: _m, factor: '1000', aliases: ['metric ton', 'tonnes'], system: 'Metric'),
  UnitDef(id: 'mass.q', name: 'Quintal', symbol: 'q', category: _m, factor: '100', aliases: ['quintals'], system: 'Metric'),
  UnitDef(id: 'mass.ct', name: 'Carat', symbol: 'ct', category: _m, factor: '0.0002', aliases: ['carats', 'metric carat'], system: 'Metric'),
  UnitDef(id: 'mass.lb', name: 'Pound', symbol: 'lb', category: _m, factor: '0.45359237', aliases: ['pounds', 'lbs'], system: 'Imperial/US'),
  UnitDef(id: 'mass.oz', name: 'Ounce', symbol: 'oz', category: _m, factor: '0.028349523125', aliases: ['ounces'], system: 'Imperial/US'),
  UnitDef(id: 'mass.dr', name: 'Dram (avoirdupois)', symbol: 'dr', category: _m, factor: '0.45359237/256', aliases: ['dram', 'drachm'], system: 'Imperial/US'),
  UnitDef(id: 'mass.gr', name: 'Grain', symbol: 'gr', category: _m, factor: '0.00006479891', aliases: ['grains'], system: 'Imperial/US'),
  UnitDef(id: 'mass.st', name: 'Stone', symbol: 'st', category: _m, factor: '6.35029318', aliases: ['stones'], system: 'Imperial'),
  UnitDef(id: 'mass.cwt_us', name: 'Short hundredweight', symbol: 'cwt (US)', category: _m, factor: '45.359237', aliases: ['hundredweight', 'cental'], system: 'US customary'),
  UnitDef(id: 'mass.cwt_imp', name: 'Long hundredweight', symbol: 'cwt (UK)', category: _m, factor: '50.80234544', aliases: ['hundredweight'], system: 'Imperial'),
  UnitDef(id: 'mass.ton_us', name: 'Short ton', symbol: 'ton (US)', category: _m, factor: '907.18474', aliases: ['ton', 'us ton'], system: 'US customary'),
  UnitDef(id: 'mass.ton_imp', name: 'Long ton', symbol: 'ton (UK)', category: _m, factor: '1016.0469088', aliases: ['ton', 'imperial ton'], system: 'Imperial'),
  UnitDef(id: 'mass.ozt', name: 'Troy ounce', symbol: 'oz t', category: _m, factor: '0.0311034768', aliases: ['troy oz', 'ozt'], system: 'Troy'),
  UnitDef(id: 'mass.lbt', name: 'Troy pound', symbol: 'lb t', category: _m, factor: '0.3732417216', aliases: ['troy lb'], system: 'Troy'),
  UnitDef(id: 'mass.dwt', name: 'Pennyweight', symbol: 'dwt', category: _m, factor: '0.00155517384', aliases: ['pennyweights'], system: 'Troy'),
  UnitDef(id: 'mass.tola', name: 'Tola', symbol: 'tola', category: _m, factor: '0.0116638038', aliases: ['tolas'], system: 'South Asian'),
  UnitDef(id: 'mass.slug', name: 'Slug', symbol: 'slug', category: _m, factor: '0.45359237*9.80665/0.3048', aliases: ['slugs'], system: 'Imperial/US'),
  UnitDef(id: 'mass.u', name: 'Atomic mass unit', symbol: 'u', category: _m, factor: '1.66053906660e-27', aliases: ['amu', 'dalton', 'Da'], system: 'CODATA 2018'),
];

const _t = UnitCategoryId.time;
const _timeUnits = <UnitDef>[
  UnitDef(id: 'time.s', name: 'Second', symbol: 's', category: _t, factor: '1', aliases: ['sec', 'seconds'], system: 'SI'),
  UnitDef(id: 'time.ps', name: 'Picosecond', symbol: 'ps', category: _t, factor: '1e-12', aliases: ['picoseconds'], system: 'SI'),
  UnitDef(id: 'time.ns', name: 'Nanosecond', symbol: 'ns', category: _t, factor: '1e-9', aliases: ['nanoseconds'], system: 'SI'),
  UnitDef(id: 'time.us', name: 'Microsecond', symbol: 'µs', category: _t, factor: '1e-6', aliases: ['us', 'microseconds', 'micro'], system: 'SI'),
  UnitDef(id: 'time.ms', name: 'Millisecond', symbol: 'ms', category: _t, factor: '0.001', aliases: ['milliseconds'], system: 'SI'),
  UnitDef(id: 'time.min', name: 'Minute', symbol: 'min', category: _t, factor: '60', aliases: ['minutes'], system: 'SI-accepted'),
  UnitDef(id: 'time.h', name: 'Hour', symbol: 'h', category: _t, factor: '3600', aliases: ['hr', 'hours'], system: 'SI-accepted'),
  UnitDef(id: 'time.d', name: 'Day', symbol: 'd', category: _t, factor: '86400', aliases: ['days'], system: 'SI-accepted'),
  UnitDef(id: 'time.wk', name: 'Week', symbol: 'wk', category: _t, factor: '604800', aliases: ['weeks'], system: 'Calendar'),
  UnitDef(id: 'time.fortnight', name: 'Fortnight', symbol: 'fn', category: _t, factor: '1209600', aliases: ['fortnights'], system: 'Calendar'),
  UnitDef(id: 'time.mo', name: 'Month (average)', symbol: 'mo', category: _t, factor: '2629746', aliases: ['month', 'months'], system: 'Gregorian'),
  UnitDef(id: 'time.yr', name: 'Year (Gregorian)', symbol: 'yr', category: _t, factor: '31556952', aliases: ['year', 'years', 'a'], system: 'Gregorian'),
  UnitDef(id: 'time.yr_julian', name: 'Julian year', symbol: 'a (Julian)', category: _t, factor: '31557600', aliases: ['julian year', 'year'], system: 'Astronomical'),
  UnitDef(id: 'time.decade', name: 'Decade', symbol: 'dec', category: _t, factor: '315569520', aliases: ['decades'], system: 'Gregorian'),
  UnitDef(id: 'time.century', name: 'Century', symbol: 'c', category: _t, factor: '3155695200', aliases: ['centuries'], system: 'Gregorian'),
  UnitDef(id: 'time.millennium', name: 'Millennium', symbol: 'ka', category: _t, factor: '31556952000', aliases: ['millennia'], system: 'Gregorian'),
];

const _tp = UnitCategoryId.temperature;
const _temperatureUnits = <UnitDef>[
  UnitDef(id: 'temperature.k', name: 'Kelvin', symbol: 'K', category: _tp, factor: '1', aliases: ['kelvins'], system: 'SI'),
  UnitDef(id: 'temperature.c', name: 'Celsius', symbol: '°C', category: _tp, factor: '1', offset: '273.15', kind: UnitKind.affine, aliases: ['C', 'degC', 'centigrade', 'degrees celsius'], system: 'Metric'),
  UnitDef(id: 'temperature.f', name: 'Fahrenheit', symbol: '°F', category: _tp, factor: '5/9', offset: '45967/180', kind: UnitKind.affine, aliases: ['F', 'degF', 'degrees fahrenheit'], system: 'US customary'),
  UnitDef(id: 'temperature.r', name: 'Rankine', symbol: '°R', category: _tp, factor: '5/9', aliases: ['R', 'degR', 'rankine'], system: 'US customary'),
  UnitDef(id: 'temperature.de', name: 'Delisle', symbol: '°De', category: _tp, factor: '-2/3', offset: '373.15', kind: UnitKind.affine, aliases: ['De', 'delisle'], system: 'Historical'),
  UnitDef(id: 'temperature.re', name: 'Réaumur', symbol: '°Ré', category: _tp, factor: '5/4', offset: '273.15', kind: UnitKind.affine, aliases: ['Re', 'reaumur'], system: 'Historical'),
  UnitDef(id: 'temperature.n', name: 'Newton', symbol: '°N', category: _tp, factor: '100/33', offset: '273.15', kind: UnitKind.affine, aliases: ['newton scale'], system: 'Historical'),
  UnitDef(id: 'temperature.ro', name: 'Rømer', symbol: '°Rø', category: _tp, factor: '40/21', offset: '181205/700', kind: UnitKind.affine, aliases: ['romer', 'roemer'], system: 'Historical'),
];

const _sp = UnitCategoryId.speed;
const _speedUnits = <UnitDef>[
  UnitDef(id: 'speed.mps', name: 'Meter per second', symbol: 'm/s', category: _sp, factor: '1', aliases: ['metre per second', 'mps'], system: 'SI'),
  UnitDef(id: 'speed.kmh', name: 'Kilometer per hour', symbol: 'km/h', category: _sp, factor: '1/3.6', aliases: ['kph', 'kmph', 'kilometre per hour'], system: 'Metric'),
  UnitDef(id: 'speed.kms', name: 'Kilometer per second', symbol: 'km/s', category: _sp, factor: '1000', aliases: ['kilometre per second'], system: 'Metric'),
  UnitDef(id: 'speed.mpm', name: 'Meter per minute', symbol: 'm/min', category: _sp, factor: '1/60', aliases: ['metre per minute'], system: 'Metric'),
  UnitDef(id: 'speed.cms', name: 'Centimeter per second', symbol: 'cm/s', category: _sp, factor: '0.01', aliases: ['centimetre per second'], system: 'Metric'),
  UnitDef(id: 'speed.mms', name: 'Millimeter per second', symbol: 'mm/s', category: _sp, factor: '0.001', aliases: ['millimetre per second'], system: 'Metric'),
  UnitDef(id: 'speed.mph', name: 'Mile per hour', symbol: 'mph', category: _sp, factor: '0.44704', aliases: ['mi/h', 'miles per hour'], system: 'Imperial/US'),
  UnitDef(id: 'speed.fps', name: 'Foot per second', symbol: 'ft/s', category: _sp, factor: '0.3048', aliases: ['fps', 'feet per second'], system: 'Imperial/US'),
  UnitDef(id: 'speed.fpm', name: 'Foot per minute', symbol: 'ft/min', category: _sp, factor: '0.00508', aliases: ['fpm', 'feet per minute'], system: 'Imperial/US'),
  UnitDef(id: 'speed.ips', name: 'Inch per second', symbol: 'in/s', category: _sp, factor: '0.0254', aliases: ['ips', 'inches per second'], system: 'Imperial/US'),
  UnitDef(id: 'speed.kn', name: 'Knot', symbol: 'kn', category: _sp, factor: '1852/3600', aliases: ['knots', 'kt', 'nautical miles per hour'], system: 'Nautical'),
  UnitDef(id: 'speed.mach', name: 'Mach (sea level)', symbol: 'Ma', category: _sp, factor: '340.3', aliases: ['mach', 'speed of sound'], system: 'approx'),
  UnitDef(id: 'speed.c', name: 'Speed of light', symbol: 'c', category: _sp, factor: '299792458', aliases: ['light speed', 'lightspeed'], system: 'SI'),
];

const _ac = UnitCategoryId.acceleration;
const _accelerationUnits = <UnitDef>[
  UnitDef(id: 'acceleration.mps2', name: 'Meter per second squared', symbol: 'm/s²', category: _ac, factor: '1', aliases: ['m/s2', 'metre per second squared'], system: 'SI'),
  UnitDef(id: 'acceleration.g0', name: 'Standard gravity', symbol: 'g₀', category: _ac, factor: '9.80665', aliases: ['g', 'g0', 'gee', 'g-force'], system: 'Standard'),
  UnitDef(id: 'acceleration.cmps2', name: 'Centimeter per second squared', symbol: 'cm/s²', category: _ac, factor: '0.01', aliases: ['cm/s2'], system: 'CGS'),
  UnitDef(id: 'acceleration.gal', name: 'Gal', symbol: 'Gal', category: _ac, factor: '0.01', aliases: ['galileo'], system: 'CGS'),
  UnitDef(id: 'acceleration.mgal', name: 'Milligal', symbol: 'mGal', category: _ac, factor: '0.00001', aliases: ['milligal'], system: 'CGS'),
  UnitDef(id: 'acceleration.fps2', name: 'Foot per second squared', symbol: 'ft/s²', category: _ac, factor: '0.3048', aliases: ['ft/s2'], system: 'Imperial/US'),
  UnitDef(id: 'acceleration.ips2', name: 'Inch per second squared', symbol: 'in/s²', category: _ac, factor: '0.0254', aliases: ['in/s2'], system: 'Imperial/US'),
  UnitDef(id: 'acceleration.kmhps', name: 'Kilometer per hour per second', symbol: 'km/(h·s)', category: _ac, factor: '1/3.6', aliases: ['km/h/s', 'kph/s'], system: 'Metric'),
  UnitDef(id: 'acceleration.mphps', name: 'Mile per hour per second', symbol: 'mph/s', category: _ac, factor: '0.44704', aliases: ['mi/h/s'], system: 'Imperial/US'),
  UnitDef(id: 'acceleration.knps', name: 'Knot per second', symbol: 'kn/s', category: _ac, factor: '1852/3600', aliases: ['knots per second'], system: 'Nautical'),
];

const _p = UnitCategoryId.pressure;
const _pressureUnits = <UnitDef>[
  UnitDef(id: 'pressure.pa', name: 'Pascal', symbol: 'Pa', category: _p, factor: '1', aliases: ['pascals', 'N/m²', 'N/m2'], system: 'SI'),
  UnitDef(id: 'pressure.hpa', name: 'Hectopascal', symbol: 'hPa', category: _p, factor: '100', aliases: ['hectopascals'], system: 'SI'),
  UnitDef(id: 'pressure.kpa', name: 'Kilopascal', symbol: 'kPa', category: _p, factor: '1000', aliases: ['kilopascals'], system: 'SI'),
  UnitDef(id: 'pressure.mpa', name: 'Megapascal', symbol: 'MPa', category: _p, factor: '1e6', aliases: ['megapascals', 'N/mm²'], system: 'SI'),
  UnitDef(id: 'pressure.gpa', name: 'Gigapascal', symbol: 'GPa', category: _p, factor: '1e9', aliases: ['gigapascals'], system: 'SI'),
  UnitDef(id: 'pressure.bar', name: 'Bar', symbol: 'bar', category: _p, factor: '100000', aliases: ['bars'], system: 'Metric'),
  UnitDef(id: 'pressure.mbar', name: 'Millibar', symbol: 'mbar', category: _p, factor: '100', aliases: ['millibars', 'mb'], system: 'Metric'),
  UnitDef(id: 'pressure.atm', name: 'Standard atmosphere', symbol: 'atm', category: _p, factor: '101325', aliases: ['atmosphere', 'atmospheres'], system: 'Standard'),
  UnitDef(id: 'pressure.at', name: 'Technical atmosphere', symbol: 'at', category: _p, factor: '98066.5', aliases: ['kgf/cm²', 'kgf/cm2'], system: 'Metric'),
  UnitDef(id: 'pressure.torr', name: 'Torr', symbol: 'Torr', category: _p, factor: '101325/760', aliases: ['torr'], system: 'Standard'),
  UnitDef(id: 'pressure.mmhg', name: 'Millimeter of mercury', symbol: 'mmHg', category: _p, factor: '133.322387415', aliases: ['mm Hg', 'millimetre of mercury'], system: 'Conventional'),
  UnitDef(id: 'pressure.inhg', name: 'Inch of mercury', symbol: 'inHg', category: _p, factor: '25.4*133.322387415', aliases: ['in Hg', 'inches of mercury'], system: 'Conventional'),
  UnitDef(id: 'pressure.mmh2o', name: 'Millimeter of water', symbol: 'mmH₂O', category: _p, factor: '9.80665', aliases: ['mmH2O', 'mm water'], system: 'Conventional'),
  UnitDef(id: 'pressure.cmh2o', name: 'Centimeter of water', symbol: 'cmH₂O', category: _p, factor: '98.0665', aliases: ['cmH2O', 'cm water'], system: 'Conventional'),
  UnitDef(id: 'pressure.inh2o', name: 'Inch of water', symbol: 'inH₂O', category: _p, factor: '249.08891', aliases: ['inH2O', 'in water', 'inches of water'], system: 'Conventional'),
  UnitDef(id: 'pressure.psi', name: 'Pound per square inch', symbol: 'psi', category: _p, factor: '4.4482216152605/0.00064516', aliases: ['lbf/in²', 'lbf/in2', 'pounds per square inch'], system: 'Imperial/US'),
  UnitDef(id: 'pressure.ksi', name: 'Kilopound per square inch', symbol: 'ksi', category: _p, factor: '4448.2216152605/0.00064516', aliases: ['kip/in²'], system: 'Imperial/US'),
  UnitDef(id: 'pressure.psf', name: 'Pound per square foot', symbol: 'psf', category: _p, factor: '4.4482216152605/0.09290304', aliases: ['lbf/ft²', 'lbf/ft2'], system: 'Imperial/US'),
  UnitDef(id: 'pressure.ba', name: 'Barye', symbol: 'Ba', category: _p, factor: '0.1', aliases: ['dyn/cm²', 'dyn/cm2', 'barye'], system: 'CGS'),
];

const _e = UnitCategoryId.energy;
const _energyUnits = <UnitDef>[
  UnitDef(id: 'energy.j', name: 'Joule', symbol: 'J', category: _e, factor: '1', aliases: ['joules', 'N·m', 'W·s'], system: 'SI'),
  UnitDef(id: 'energy.mj_milli', name: 'Millijoule', symbol: 'mJ', category: _e, factor: '0.001', aliases: ['millijoules'], system: 'SI'),
  UnitDef(id: 'energy.kj', name: 'Kilojoule', symbol: 'kJ', category: _e, factor: '1000', aliases: ['kilojoules'], system: 'SI'),
  UnitDef(id: 'energy.mj', name: 'Megajoule', symbol: 'MJ', category: _e, factor: '1e6', aliases: ['megajoules'], system: 'SI'),
  UnitDef(id: 'energy.gj', name: 'Gigajoule', symbol: 'GJ', category: _e, factor: '1e9', aliases: ['gigajoules'], system: 'SI'),
  UnitDef(id: 'energy.wh', name: 'Watt-hour', symbol: 'Wh', category: _e, factor: '3600', aliases: ['watt hour'], system: 'Metric'),
  UnitDef(id: 'energy.kwh', name: 'Kilowatt-hour', symbol: 'kWh', category: _e, factor: '3.6e6', aliases: ['kilowatt hour', 'unit'], system: 'Metric'),
  UnitDef(id: 'energy.mwh', name: 'Megawatt-hour', symbol: 'MWh', category: _e, factor: '3.6e9', aliases: ['megawatt hour'], system: 'Metric'),
  UnitDef(id: 'energy.cal', name: 'Calorie (thermochemical)', symbol: 'cal', category: _e, factor: '4.184', aliases: ['calorie', 'small calorie', 'cal_th'], system: 'Thermochemical'),
  UnitDef(id: 'energy.kcal', name: 'Kilocalorie', symbol: 'kcal', category: _e, factor: '4184', aliases: ['food calorie', 'Calorie', 'Cal'], system: 'Thermochemical'),
  UnitDef(id: 'energy.cal_it', name: 'Calorie (IT)', symbol: 'cal (IT)', category: _e, factor: '4.1868', aliases: ['calorie', 'international table calorie'], system: 'IT'),
  UnitDef(id: 'energy.ev', name: 'Electronvolt', symbol: 'eV', category: _e, factor: '1.602176634e-19', aliases: ['electron volt'], system: 'SI-accepted'),
  UnitDef(id: 'energy.kev', name: 'Kiloelectronvolt', symbol: 'keV', category: _e, factor: '1.602176634e-16', aliases: ['kilo electron volt'], system: 'SI-accepted'),
  UnitDef(id: 'energy.mev', name: 'Megaelectronvolt', symbol: 'MeV', category: _e, factor: '1.602176634e-13', aliases: ['mega electron volt'], system: 'SI-accepted'),
  UnitDef(id: 'energy.btu', name: 'British thermal unit', symbol: 'BTU', category: _e, factor: '1055.05585262', aliases: ['btu', 'Btu (IT)'], system: 'IT'),
  UnitDef(id: 'energy.therm', name: 'Therm (US)', symbol: 'thm', category: _e, factor: '105480400', aliases: ['therm', 'therms'], system: 'US customary'),
  UnitDef(id: 'energy.quad', name: 'Quad', symbol: 'quad', category: _e, factor: '1.05505585262e18', aliases: ['quadrillion btu'], system: 'US customary'),
  UnitDef(id: 'energy.ftlbf', name: 'Foot-pound', symbol: 'ft·lbf', category: _e, factor: '0.3048*4.4482216152605', aliases: ['ft-lbf', 'foot pound', 'ft lb'], system: 'Imperial/US'),
  UnitDef(id: 'energy.inlbf', name: 'Inch-pound', symbol: 'in·lbf', category: _e, factor: '0.0254*4.4482216152605', aliases: ['in-lbf', 'inch pound'], system: 'Imperial/US'),
  UnitDef(id: 'energy.erg', name: 'Erg', symbol: 'erg', category: _e, factor: '1e-7', aliases: ['ergs'], system: 'CGS'),
  UnitDef(id: 'energy.tnt', name: 'Ton of TNT', symbol: 'tTNT', category: _e, factor: '4.184e9', aliases: ['ton tnt', 'tonne of tnt'], system: 'Conventional'),
];

const _pw = UnitCategoryId.power;
const _powerUnits = <UnitDef>[
  UnitDef(id: 'power.w', name: 'Watt', symbol: 'W', category: _pw, factor: '1', aliases: ['watts', 'J/s'], system: 'SI'),
  UnitDef(id: 'power.mw_milli', name: 'Milliwatt', symbol: 'mW', category: _pw, factor: '0.001', aliases: ['milliwatts'], system: 'SI'),
  UnitDef(id: 'power.kw', name: 'Kilowatt', symbol: 'kW', category: _pw, factor: '1000', aliases: ['kilowatts'], system: 'SI'),
  UnitDef(id: 'power.mw', name: 'Megawatt', symbol: 'MW', category: _pw, factor: '1e6', aliases: ['megawatts'], system: 'SI'),
  UnitDef(id: 'power.gw', name: 'Gigawatt', symbol: 'GW', category: _pw, factor: '1e9', aliases: ['gigawatts'], system: 'SI'),
  UnitDef(id: 'power.hp', name: 'Horsepower (mechanical)', symbol: 'hp', category: _pw, factor: '550*0.3048*4.4482216152605', aliases: ['horsepower', 'imperial horsepower', 'bhp'], system: 'Imperial/US'),
  UnitDef(id: 'power.ps', name: 'Horsepower (metric)', symbol: 'PS', category: _pw, factor: '735.49875', aliases: ['metric horsepower', 'cv', 'pk'], system: 'Metric'),
  UnitDef(id: 'power.hp_e', name: 'Horsepower (electric)', symbol: 'hp(E)', category: _pw, factor: '746', aliases: ['electrical horsepower'], system: 'Conventional'),
  UnitDef(id: 'power.btuh', name: 'BTU per hour', symbol: 'BTU/h', category: _pw, factor: '1055.05585262/3600', aliases: ['btu/hr', 'btuh'], system: 'IT'),
  UnitDef(id: 'power.kcalh', name: 'Kilocalorie per hour', symbol: 'kcal/h', category: _pw, factor: '4184/3600', aliases: ['kcal per hour'], system: 'Thermochemical'),
  UnitDef(id: 'power.cals', name: 'Calorie per second', symbol: 'cal/s', category: _pw, factor: '4.184', aliases: ['calorie per second'], system: 'Thermochemical'),
  UnitDef(id: 'power.ftlbfs', name: 'Foot-pound per second', symbol: 'ft·lbf/s', category: _pw, factor: '0.3048*4.4482216152605', aliases: ['ft-lbf/s'], system: 'Imperial/US'),
  UnitDef(id: 'power.tr', name: 'Ton of refrigeration', symbol: 'TR', category: _pw, factor: '12000*1055.05585262/3600', aliases: ['refrigeration ton', 'RT'], system: 'US customary'),
  UnitDef(id: 'power.ergs', name: 'Erg per second', symbol: 'erg/s', category: _pw, factor: '1e-7', aliases: ['ergs per second'], system: 'CGS'),
];

const _fo = UnitCategoryId.force;
const _forceUnits = <UnitDef>[
  UnitDef(id: 'force.n', name: 'Newton', symbol: 'N', category: _fo, factor: '1', aliases: ['newtons'], system: 'SI'),
  UnitDef(id: 'force.mn_milli', name: 'Millinewton', symbol: 'mN', category: _fo, factor: '0.001', aliases: ['millinewtons'], system: 'SI'),
  UnitDef(id: 'force.kn', name: 'Kilonewton', symbol: 'kN', category: _fo, factor: '1000', aliases: ['kilonewtons'], system: 'SI'),
  UnitDef(id: 'force.mn', name: 'Meganewton', symbol: 'MN', category: _fo, factor: '1e6', aliases: ['meganewtons'], system: 'SI'),
  UnitDef(id: 'force.dyn', name: 'Dyne', symbol: 'dyn', category: _fo, factor: '0.00001', aliases: ['dynes'], system: 'CGS'),
  UnitDef(id: 'force.kgf', name: 'Kilogram-force', symbol: 'kgf', category: _fo, factor: '9.80665', aliases: ['kilopond', 'kp'], system: 'Gravitational metric'),
  UnitDef(id: 'force.gf', name: 'Gram-force', symbol: 'gf', category: _fo, factor: '0.00980665', aliases: ['pond'], system: 'Gravitational metric'),
  UnitDef(id: 'force.tf', name: 'Tonne-force', symbol: 'tf', category: _fo, factor: '9806.65', aliases: ['metric ton-force'], system: 'Gravitational metric'),
  UnitDef(id: 'force.lbf', name: 'Pound-force', symbol: 'lbf', category: _fo, factor: '4.4482216152605', aliases: ['pound force'], system: 'Imperial/US'),
  UnitDef(id: 'force.ozf', name: 'Ounce-force', symbol: 'ozf', category: _fo, factor: '4.4482216152605/16', aliases: ['ounce force'], system: 'Imperial/US'),
  UnitDef(id: 'force.kip', name: 'Kip', symbol: 'kip', category: _fo, factor: '4448.2216152605', aliases: ['kilopound-force', 'klbf'], system: 'US customary'),
  UnitDef(id: 'force.tonf_us', name: 'Short ton-force', symbol: 'tonf (US)', category: _fo, factor: '2000*4.4482216152605', aliases: ['ton-force'], system: 'US customary'),
  UnitDef(id: 'force.pdl', name: 'Poundal', symbol: 'pdl', category: _fo, factor: '0.45359237*0.3048', aliases: ['poundals'], system: 'Imperial'),
];

const _an = UnitCategoryId.angle;
const _angleUnits = <UnitDef>[
  UnitDef(id: 'angle.turn', name: 'Turn', symbol: 'tr', category: _an, factor: '1', aliases: ['revolution', 'rev', 'cycle', 'full circle'], system: 'Standard'),
  UnitDef(id: 'angle.rad', name: 'Radian', symbol: 'rad', category: _an, factor: '1', piScaled: true, aliases: ['radians'], system: 'SI'),
  UnitDef(id: 'angle.mrad', name: 'Milliradian', symbol: 'mrad', category: _an, factor: '0.001', piScaled: true, aliases: ['milliradians'], system: 'SI'),
  UnitDef(id: 'angle.deg', name: 'Degree', symbol: '°', category: _an, factor: '1/360', aliases: ['deg', 'degrees'], system: 'Standard'),
  UnitDef(id: 'angle.arcmin', name: 'Arcminute', symbol: '′', category: _an, factor: '1/21600', aliases: ['arcmin', 'minute of arc', "'"], system: 'Standard'),
  UnitDef(id: 'angle.arcsec', name: 'Arcsecond', symbol: '″', category: _an, factor: '1/1296000', aliases: ['arcsec', 'second of arc', '"'], system: 'Standard'),
  UnitDef(id: 'angle.mas', name: 'Milliarcsecond', symbol: 'mas', category: _an, factor: '1/1296000000', aliases: ['milliarcsec'], system: 'Astronomical'),
  UnitDef(id: 'angle.grad', name: 'Gradian', symbol: 'gon', category: _an, factor: '1/400', aliases: ['grad', 'grade', 'gradians'], system: 'Metric'),
  UnitDef(id: 'angle.mil', name: 'NATO mil', symbol: 'mil', category: _an, factor: '1/6400', aliases: ['angular mil'], system: 'NATO'),
  UnitDef(id: 'angle.quadrant', name: 'Quadrant', symbol: 'quad', category: _an, factor: '1/4', aliases: ['right angle'], system: 'Standard'),
  UnitDef(id: 'angle.sextant', name: 'Sextant', symbol: 'sxt', category: _an, factor: '1/6', aliases: ['sextants'], system: 'Standard'),
  UnitDef(id: 'angle.hour', name: 'Hour angle', symbol: 'h', category: _an, factor: '1/24', aliases: ['hour of arc'], system: 'Astronomical'),
  UnitDef(id: 'angle.point', name: 'Compass point', symbol: 'point', category: _an, factor: '1/32', aliases: ['point'], system: 'Nautical'),
];

const _fr = UnitCategoryId.frequency;
const _frequencyUnits = <UnitDef>[
  UnitDef(id: 'frequency.hz', name: 'Hertz', symbol: 'Hz', category: _fr, factor: '1', aliases: ['cycles per second', 'cps', '1/s'], system: 'SI'),
  UnitDef(id: 'frequency.mhz_milli', name: 'Millihertz', symbol: 'mHz', category: _fr, factor: '0.001', aliases: ['millihertz'], system: 'SI'),
  UnitDef(id: 'frequency.khz', name: 'Kilohertz', symbol: 'kHz', category: _fr, factor: '1000', aliases: ['kilohertz'], system: 'SI'),
  UnitDef(id: 'frequency.mhz', name: 'Megahertz', symbol: 'MHz', category: _fr, factor: '1e6', aliases: ['megahertz'], system: 'SI'),
  UnitDef(id: 'frequency.ghz', name: 'Gigahertz', symbol: 'GHz', category: _fr, factor: '1e9', aliases: ['gigahertz'], system: 'SI'),
  UnitDef(id: 'frequency.thz', name: 'Terahertz', symbol: 'THz', category: _fr, factor: '1e12', aliases: ['terahertz'], system: 'SI'),
  UnitDef(id: 'frequency.rpm', name: 'Revolutions per minute', symbol: 'rpm', category: _fr, factor: '1/60', aliases: ['rev/min', 'bpm', 'per minute'], system: 'Standard'),
  UnitDef(id: 'frequency.rph', name: 'Revolutions per hour', symbol: 'rph', category: _fr, factor: '1/3600', aliases: ['rev/h', 'per hour'], system: 'Standard'),
  UnitDef(id: 'frequency.degps', name: 'Degree per second', symbol: '°/s', category: _fr, factor: '1/360', aliases: ['deg/s'], system: 'Standard'),
  UnitDef(id: 'frequency.radps', name: 'Radian per second', symbol: 'rad/s', category: _fr, factor: '1', piScaled: true, aliases: ['angular frequency', 'omega'], system: 'SI'),
];

const _d = UnitCategoryId.data;
const _dataUnits = <UnitDef>[
  UnitDef(id: 'data.bit', name: 'Bit', symbol: 'bit', category: _d, factor: '1', aliases: ['bits', 'b'], system: 'Standard'),
  UnitDef(id: 'data.nibble', name: 'Nibble', symbol: 'nibble', category: _d, factor: '4', aliases: ['nybble'], system: 'Standard'),
  UnitDef(id: 'data.byte', name: 'Byte', symbol: 'B', category: _d, factor: '8', aliases: ['bytes', 'octet'], system: 'Standard'),
  UnitDef(id: 'data.kbit', name: 'Kilobit', symbol: 'kbit', category: _d, factor: '1000', aliases: ['kb', 'kilobits'], system: 'SI'),
  UnitDef(id: 'data.kibit', name: 'Kibibit', symbol: 'Kibit', category: _d, factor: '1024', aliases: ['kibibits'], system: 'IEC'),
  UnitDef(id: 'data.mbit', name: 'Megabit', symbol: 'Mbit', category: _d, factor: '1e6', aliases: ['Mb', 'megabits'], system: 'SI'),
  UnitDef(id: 'data.mibit', name: 'Mebibit', symbol: 'Mibit', category: _d, factor: '1048576', aliases: ['mebibits'], system: 'IEC'),
  UnitDef(id: 'data.gbit', name: 'Gigabit', symbol: 'Gbit', category: _d, factor: '1e9', aliases: ['Gb', 'gigabits'], system: 'SI'),
  UnitDef(id: 'data.tbit', name: 'Terabit', symbol: 'Tbit', category: _d, factor: '1e12', aliases: ['Tb', 'terabits'], system: 'SI'),
  UnitDef(id: 'data.kb', name: 'Kilobyte', symbol: 'kB', category: _d, factor: '8000', aliases: ['KB', 'kilobytes'], system: 'SI'),
  UnitDef(id: 'data.kib', name: 'Kibibyte', symbol: 'KiB', category: _d, factor: '8192', aliases: ['kibibytes'], system: 'IEC'),
  UnitDef(id: 'data.mb', name: 'Megabyte', symbol: 'MB', category: _d, factor: '8e6', aliases: ['megabytes'], system: 'SI'),
  UnitDef(id: 'data.mib', name: 'Mebibyte', symbol: 'MiB', category: _d, factor: '8388608', aliases: ['mebibytes'], system: 'IEC'),
  UnitDef(id: 'data.gb', name: 'Gigabyte', symbol: 'GB', category: _d, factor: '8e9', aliases: ['gigabytes'], system: 'SI'),
  UnitDef(id: 'data.gib', name: 'Gibibyte', symbol: 'GiB', category: _d, factor: '8589934592', aliases: ['gibibytes'], system: 'IEC'),
  UnitDef(id: 'data.tb', name: 'Terabyte', symbol: 'TB', category: _d, factor: '8e12', aliases: ['terabytes'], system: 'SI'),
  UnitDef(id: 'data.tib', name: 'Tebibyte', symbol: 'TiB', category: _d, factor: '8796093022208', aliases: ['tebibytes'], system: 'IEC'),
  UnitDef(id: 'data.pb', name: 'Petabyte', symbol: 'PB', category: _d, factor: '8e15', aliases: ['petabytes'], system: 'SI'),
  UnitDef(id: 'data.pib', name: 'Pebibyte', symbol: 'PiB', category: _d, factor: '9007199254740992', aliases: ['pebibytes'], system: 'IEC'),
  UnitDef(id: 'data.eb', name: 'Exabyte', symbol: 'EB', category: _d, factor: '8e18', aliases: ['exabytes'], system: 'SI'),
  UnitDef(id: 'data.eib', name: 'Exbibyte', symbol: 'EiB', category: _d, factor: '9223372036854775808', aliases: ['exbibytes'], system: 'IEC'),
];

const _fe = UnitCategoryId.fuelEconomy;
const _fuelUnits = <UnitDef>[
  UnitDef(id: 'fuel.kmpl', name: 'Kilometer per liter', symbol: 'km/L', category: _fe, factor: '1', aliases: ['kmpl', 'kilometre per litre'], system: 'Metric'),
  UnitDef(id: 'fuel.l100km', name: 'Liter per 100 kilometers', symbol: 'L/100 km', category: _fe, factor: '100', kind: UnitKind.reciprocal, aliases: ['l/100km', 'litres per 100 km'], system: 'Metric'),
  UnitDef(id: 'fuel.lpkm', name: 'Liter per kilometer', symbol: 'L/km', category: _fe, factor: '1', kind: UnitKind.reciprocal, aliases: ['litre per kilometre'], system: 'Metric'),
  UnitDef(id: 'fuel.mpl', name: 'Mile per liter', symbol: 'mi/L', category: _fe, factor: '1.609344', aliases: ['miles per litre', 'mpl'], system: 'Mixed'),
  UnitDef(id: 'fuel.mpg_us', name: 'Mile per gallon (US)', symbol: 'mpg (US)', category: _fe, factor: '1.609344/3.785411784', aliases: ['mpg', 'miles per gallon'], system: 'US customary'),
  UnitDef(id: 'fuel.mpg_imp', name: 'Mile per gallon (imperial)', symbol: 'mpg (imp)', category: _fe, factor: '1.609344/4.54609', aliases: ['mpg', 'uk mpg'], system: 'Imperial'),
  UnitDef(id: 'fuel.kmpgal_us', name: 'Kilometer per gallon (US)', symbol: 'km/gal (US)', category: _fe, factor: '1/3.785411784', aliases: ['km per gallon'], system: 'Mixed'),
  UnitDef(id: 'fuel.gal100mi_us', name: 'Gallon (US) per 100 miles', symbol: 'gal (US)/100 mi', category: _fe, factor: '160.9344/3.785411784', kind: UnitKind.reciprocal, aliases: ['gallons per 100 miles'], system: 'US customary'),
  UnitDef(id: 'fuel.gal100mi_imp', name: 'Gallon (imperial) per 100 miles', symbol: 'gal (imp)/100 mi', category: _fe, factor: '160.9344/4.54609', kind: UnitKind.reciprocal, aliases: ['gallons per 100 miles'], system: 'Imperial'),
];

const _de = UnitCategoryId.density;
const _densityUnits = <UnitDef>[
  UnitDef(id: 'density.kgm3', name: 'Kilogram per cubic meter', symbol: 'kg/m³', category: _de, factor: '1', aliases: ['kg/m3', 'kilogram per cubic metre'], system: 'SI'),
  UnitDef(id: 'density.gcm3', name: 'Gram per cubic centimeter', symbol: 'g/cm³', category: _de, factor: '1000', aliases: ['g/cm3', 'g/cc'], system: 'CGS'),
  UnitDef(id: 'density.gml', name: 'Gram per milliliter', symbol: 'g/mL', category: _de, factor: '1000', aliases: ['g/ml'], system: 'Metric'),
  UnitDef(id: 'density.kgl', name: 'Kilogram per liter', symbol: 'kg/L', category: _de, factor: '1000', aliases: ['kg/l', 'kilogram per litre'], system: 'Metric'),
  UnitDef(id: 'density.tm3', name: 'Tonne per cubic meter', symbol: 't/m³', category: _de, factor: '1000', aliases: ['t/m3'], system: 'Metric'),
  UnitDef(id: 'density.gl', name: 'Gram per liter', symbol: 'g/L', category: _de, factor: '1', aliases: ['g/l', 'gram per litre'], system: 'Metric'),
  UnitDef(id: 'density.mgl', name: 'Milligram per liter', symbol: 'mg/L', category: _de, factor: '0.001', aliases: ['mg/l', 'ppm (water)'], system: 'Metric'),
  UnitDef(id: 'density.gm3', name: 'Gram per cubic meter', symbol: 'g/m³', category: _de, factor: '0.001', aliases: ['g/m3'], system: 'Metric'),
  UnitDef(id: 'density.lbft3', name: 'Pound per cubic foot', symbol: 'lb/ft³', category: _de, factor: '0.45359237/0.028316846592', aliases: ['lb/ft3', 'pcf'], system: 'Imperial/US'),
  UnitDef(id: 'density.lbin3', name: 'Pound per cubic inch', symbol: 'lb/in³', category: _de, factor: '0.45359237/0.000016387064', aliases: ['lb/in3'], system: 'Imperial/US'),
  UnitDef(id: 'density.lbyd3', name: 'Pound per cubic yard', symbol: 'lb/yd³', category: _de, factor: '0.45359237/0.764554857984', aliases: ['lb/yd3'], system: 'Imperial/US'),
  UnitDef(id: 'density.ozin3', name: 'Ounce per cubic inch', symbol: 'oz/in³', category: _de, factor: '0.028349523125/0.000016387064', aliases: ['oz/in3'], system: 'Imperial/US'),
  UnitDef(id: 'density.lbgal_us', name: 'Pound per gallon (US)', symbol: 'lb/gal (US)', category: _de, factor: '0.45359237/0.003785411784', aliases: ['ppg', 'lb/gal'], system: 'US customary'),
  UnitDef(id: 'density.lbgal_imp', name: 'Pound per gallon (imperial)', symbol: 'lb/gal (imp)', category: _de, factor: '0.45359237/0.00454609', aliases: ['lb/gal'], system: 'Imperial'),
  UnitDef(id: 'density.ozgal_us', name: 'Ounce per gallon (US)', symbol: 'oz/gal (US)', category: _de, factor: '0.028349523125/0.003785411784', aliases: ['oz/gal'], system: 'US customary'),
  UnitDef(id: 'density.slugft3', name: 'Slug per cubic foot', symbol: 'slug/ft³', category: _de, factor: '0.45359237*9.80665/0.3048*0.028316846592', aliases: ['slug/ft3'], system: 'Imperial/US'),
];

const _tq = UnitCategoryId.torque;
const _torqueUnits = <UnitDef>[
  UnitDef(id: 'torque.nm', name: 'Newton meter', symbol: 'N·m', category: _tq, factor: '1', aliases: ['Nm', 'N-m', 'newton metre'], system: 'SI'),
  UnitDef(id: 'torque.knm', name: 'Kilonewton meter', symbol: 'kN·m', category: _tq, factor: '1000', aliases: ['kNm', 'kN-m'], system: 'SI'),
  UnitDef(id: 'torque.ncm', name: 'Newton centimeter', symbol: 'N·cm', category: _tq, factor: '0.01', aliases: ['Ncm', 'N-cm'], system: 'SI'),
  UnitDef(id: 'torque.nmm', name: 'Newton millimeter', symbol: 'N·mm', category: _tq, factor: '0.001', aliases: ['Nmm', 'N-mm'], system: 'SI'),
  UnitDef(id: 'torque.kgfm', name: 'Kilogram-force meter', symbol: 'kgf·m', category: _tq, factor: '9.80665', aliases: ['kgm', 'kgf-m', 'kilopond metre'], system: 'Gravitational metric'),
  UnitDef(id: 'torque.kgfcm', name: 'Kilogram-force centimeter', symbol: 'kgf·cm', category: _tq, factor: '0.0980665', aliases: ['kgf-cm', 'kg-cm'], system: 'Gravitational metric'),
  UnitDef(id: 'torque.gfcm', name: 'Gram-force centimeter', symbol: 'gf·cm', category: _tq, factor: '0.0000980665', aliases: ['gf-cm', 'g-cm'], system: 'Gravitational metric'),
  UnitDef(id: 'torque.dyncm', name: 'Dyne centimeter', symbol: 'dyn·cm', category: _tq, factor: '1e-7', aliases: ['dyn-cm'], system: 'CGS'),
  UnitDef(id: 'torque.lbfft', name: 'Pound-force foot', symbol: 'lbf·ft', category: _tq, factor: '4.4482216152605*0.3048', aliases: ['lb-ft', 'ft-lb', 'foot-pound'], system: 'Imperial/US'),
  UnitDef(id: 'torque.lbfin', name: 'Pound-force inch', symbol: 'lbf·in', category: _tq, factor: '4.4482216152605*0.0254', aliases: ['lb-in', 'in-lb', 'inch-pound'], system: 'Imperial/US'),
  UnitDef(id: 'torque.ozfin', name: 'Ounce-force inch', symbol: 'ozf·in', category: _tq, factor: '4.4482216152605*0.0254/16', aliases: ['oz-in', 'in-oz'], system: 'Imperial/US'),
  UnitDef(id: 'torque.pdlft', name: 'Poundal foot', symbol: 'pdl·ft', category: _tq, factor: '0.45359237*0.3048*0.3048', aliases: ['pdl-ft'], system: 'Imperial'),
];

const List<UnitCategory> unitCategories = [
  UnitCategory(UnitCategoryId.length, 'Length', 'length.m', _lengthUnits),
  UnitCategory(UnitCategoryId.area, 'Area', 'area.m2', _areaUnits),
  UnitCategory(UnitCategoryId.volume, 'Volume', 'volume.m3', _volumeUnits),
  UnitCategory(UnitCategoryId.mass, 'Mass', 'mass.kg', _massUnits),
  UnitCategory(UnitCategoryId.time, 'Time', 'time.s', _timeUnits),
  UnitCategory(UnitCategoryId.temperature, 'Temperature', 'temperature.k', _temperatureUnits),
  UnitCategory(UnitCategoryId.speed, 'Speed', 'speed.mps', _speedUnits),
  UnitCategory(UnitCategoryId.acceleration, 'Acceleration', 'acceleration.mps2', _accelerationUnits),
  UnitCategory(UnitCategoryId.pressure, 'Pressure', 'pressure.pa', _pressureUnits),
  UnitCategory(UnitCategoryId.energy, 'Energy', 'energy.j', _energyUnits),
  UnitCategory(UnitCategoryId.power, 'Power', 'power.w', _powerUnits),
  UnitCategory(UnitCategoryId.force, 'Force', 'force.n', _forceUnits),
  UnitCategory(UnitCategoryId.angle, 'Angle', 'angle.turn', _angleUnits),
  UnitCategory(UnitCategoryId.frequency, 'Frequency', 'frequency.hz', _frequencyUnits),
  UnitCategory(UnitCategoryId.data, 'Data', 'data.bit', _dataUnits),
  UnitCategory(UnitCategoryId.fuelEconomy, 'Fuel economy', 'fuel.kmpl', _fuelUnits),
  UnitCategory(UnitCategoryId.density, 'Density', 'density.kgm3', _densityUnits),
  UnitCategory(UnitCategoryId.torque, 'Torque', 'torque.nm', _torqueUnits),
];
