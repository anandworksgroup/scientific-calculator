import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'routes.dart';

/// A navigable module (Tools screen, quick access, global search).
class ToolInfo {
  const ToolInfo(this.id, this.route, this.icon, this.title, {this.keywords = const []});
  final String id;
  final String route;
  final IconData icon;
  final String Function(AppLocalizations l) title;

  /// Extra English search terms.
  final List<String> keywords;
}

final List<ToolInfo> allTools = [
  ToolInfo('equation', Routes.equation, Icons.calculate_outlined, (l) => l.toolEquation, keywords: ['solve', 'root', 'nonlinear', 'quadratic', 'linear']),
  ToolInfo('polynomial', Routes.polynomial, Icons.stacked_line_chart, (l) => l.toolPolynomial, keywords: ['roots', 'quadratic', 'cubic', 'quartic', 'multiplicity']),
  ToolInfo('system', Routes.system, Icons.grid_on, (l) => l.toolSystem, keywords: ['linear system', 'simultaneous', 'equations']),
  ToolInfo('cas', Routes.cas, Icons.auto_fix_high, (l) => l.toolCas, keywords: ['simplify', 'expand', 'factor', 'collect', 'substitute', 'algebra', 'symbolic']),
  ToolInfo('graph', Routes.graph, Icons.show_chart, (l) => l.toolGraph, keywords: ['plot', 'function', 'curve', 'polar', 'parametric', 'quadratic']),
  ToolInfo('matrix', Routes.matrix, Icons.grid_view, (l) => l.toolMatrix, keywords: ['determinant', 'inverse', 'eigenvalue', 'rref', 'transpose']),
  ToolInfo('vector', Routes.vector, Icons.north_east, (l) => l.toolVector, keywords: ['dot', 'cross', 'magnitude', 'projection']),
  ToolInfo('complex', Routes.complex, Icons.blur_circular, (l) => l.toolComplex, keywords: ['imaginary', 'polar', 'argument', 'conjugate']),
  ToolInfo('derivative', Routes.derivative, Icons.trending_up, (l) => l.toolDerivative, keywords: ['differentiate', 'calculus', 'slope']),
  ToolInfo('integral', Routes.integral, Icons.area_chart_outlined, (l) => l.toolIntegral, keywords: ['integrate', 'antiderivative', 'area', 'calculus']),
  ToolInfo('limit', Routes.limit, Icons.linear_scale, (l) => l.toolLimit, keywords: ['calculus', 'approach', 'infinity']),
  ToolInfo('series', Routes.series, Icons.functions, (l) => l.toolSeries, keywords: ['sigma', 'summation', 'product', 'pi']),
  ToolInfo('statistics', Routes.statistics, Icons.bar_chart, (l) => l.toolStatistics, keywords: ['mean', 'median', 'regression', 'deviation', 'variance']),
  ToolInfo('probability', Routes.probability, Icons.casino_outlined, (l) => l.toolProbability, keywords: ['normal', 'binomial', 'poisson', 'distribution', 'ncr', 'npr']),
  ToolInfo('numberTheory', Routes.numberTheory, Icons.tag, (l) => l.toolNumberTheory, keywords: ['prime', 'factor', 'gcd', 'lcm', 'divisors', 'modulo']),
  ToolInfo('random', Routes.random, Icons.shuffle, (l) => l.toolRandom, keywords: ['random', 'dice', 'permutation', 'seed']),
  ToolInfo('converter', Routes.converter, Icons.swap_horiz, (l) => l.toolConverter, keywords: ['units', 'length', 'temperature', 'mass', 'currency-free']),
  ToolInfo('constants', Routes.constants, Icons.science_outlined, (l) => l.toolConstants, keywords: ['physics', 'planck', 'speed of light', 'avogadro']),
  ToolInfo('formulas', Routes.formulas, Icons.menu_book_outlined, (l) => l.toolFormulas, keywords: ['physics', 'geometry', 'algebra', 'reference']),
  ToolInfo('programmer', Routes.programmer, Icons.memory, (l) => l.toolProgrammer, keywords: ['binary', 'hex', 'octal', 'bitwise', 'base']),
  ToolInfo('table', Routes.table, Icons.table_chart_outlined, (l) => l.toolTable, keywords: ['values', 'f(x)', 'table']),
  ToolInfo('variables', Routes.variables, Icons.data_object, (l) => l.toolVariables, keywords: ['memory', 'store', 'ans']),
  ToolInfo('functions', Routes.functions, Icons.timeline, (l) => l.toolFunctions, keywords: ['f(x)', 'define', 'saved']),
  ToolInfo('favorites', Routes.favorites, Icons.star_outline, (l) => l.toolFavorites, keywords: ['saved', 'starred']),
];

ToolInfo? toolById(String id) {
  for (final t in allTools) {
    if (t.id == id) return t;
  }
  return null;
}
