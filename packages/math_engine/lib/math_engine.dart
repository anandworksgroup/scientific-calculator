/// Pure-Dart mathematics engine for Advanced Calculator.
///
/// Pipeline: text → [tokenize] → [Parser] → AST ([Node]) → validation →
/// [Evaluator] / CAS ([Sym]) → normalization → [ValueFormatter] → display.
/// No dynamic code evaluation is used anywhere.
library;

export 'src/algebra/polynomial.dart';
export 'src/algebra/solve.dart';
export 'src/ast/ast.dart';
export 'src/calculus/numeric_calculus.dart' show ExtNum, IntegralResult, NumericCalculus;
export 'src/cas/cas.dart' show SymConverter, symToNode, symEval, polyCoefficients, symSize;
export 'src/cas/integrate.dart' show integrateSym;
export 'src/cas/sym.dart' show Sym, SNum, SConst, SVar, SAdd, SMul, SPow, SFn, S, dependsOn, symVariables;
export 'src/constants/constants.dart';
export 'src/core/budget.dart';
export 'src/core/errors.dart';
export 'src/engine.dart';
export 'src/eval/double_eval.dart';
export 'src/eval/evaluator.dart';
export 'src/eval/value_codec.dart';
export 'src/eval/values.dart';
export 'src/format/number_format.dart';
export 'src/format/printers.dart';
export 'src/format/value_format.dart';
export 'src/functions/catalog.dart';
export 'src/graph/graph_engine.dart';
export 'src/programmer/programmer.dart';
export 'src/table/function_table.dart';
export 'src/linalg/matrix_ops.dart';
export 'src/number_theory/number_theory.dart';
export 'src/numbers/num.dart';
export 'src/parser/parser.dart';
export 'src/stats/probability.dart';
export 'src/stats/statistics.dart';
export 'src/units/units.dart';
export 'src/content/formulas.dart';
