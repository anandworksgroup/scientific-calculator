/// Catalog of built-in functions: arity, category, display and
/// accessibility metadata. Used by the parser (known names), the
/// evaluator (arity validation), formatters and the function picker UI.
library;

enum FunctionCategory {
  arithmetic,
  powers,
  logarithms,
  trigonometry,
  hyperbolic,
  rounding,
  numberTheory,
  probability,
  statistics,
  complex,
  matrix,
  vector,
  calculus,
  random,
}

class FunctionSpec {
  const FunctionSpec(
    this.name,
    this.minArgs,
    this.maxArgs,
    this.category,
    this.signature,
    this.spokenName,
    this.description, {
    this.lazy = false,
  });

  /// Identifier used in expressions.
  final String name;
  final int minArgs;

  /// -1 = variadic.
  final int maxArgs;
  final FunctionCategory category;

  /// Human-readable signature, e.g. `nroot(n, x)`.
  final String signature;

  /// Screen-reader name, e.g. "Inverse sine".
  final String spokenName;
  final String description;

  /// Higher-order function receiving an unevaluated expression.
  final bool lazy;

  String get insertText => '$name(';
}

const _a = FunctionCategory.arithmetic;
const _p = FunctionCategory.powers;
const _l = FunctionCategory.logarithms;
const _t = FunctionCategory.trigonometry;
const _h = FunctionCategory.hyperbolic;
const _r = FunctionCategory.rounding;
const _n = FunctionCategory.numberTheory;
const _pr = FunctionCategory.probability;
const _s = FunctionCategory.statistics;
const _c = FunctionCategory.complex;
const _m = FunctionCategory.matrix;
const _v = FunctionCategory.vector;
const _cal = FunctionCategory.calculus;
const _rnd = FunctionCategory.random;

const List<FunctionSpec> builtinFunctions = [
  // Powers and roots
  FunctionSpec('sqrt', 1, 1, _p, 'sqrt(x)', 'Square root', 'Square root √x.'),
  FunctionSpec('cbrt', 1, 1, _p, 'cbrt(x)', 'Cube root', 'Cube root ∛x (real for negative x).'),
  FunctionSpec('nroot', 2, 2, _p, 'nroot(n, x)', 'Nth root', 'The n-th root of x.'),
  FunctionSpec('exp', 1, 1, _p, 'exp(x)', 'Exponential', 'eˣ.'),
  FunctionSpec('pow', 2, 2, _p, 'pow(x, y)', 'Power', 'x raised to the power y.'),
  // Logarithms
  FunctionSpec('ln', 1, 1, _l, 'ln(x)', 'Natural logarithm', 'Logarithm base e.'),
  FunctionSpec('log', 1, 2, _l, 'log(x) or log(b, x)', 'Logarithm', 'Base-10 logarithm, or log base b of x.'),
  FunctionSpec('log2', 1, 1, _l, 'log2(x)', 'Logarithm base 2', 'Binary logarithm.'),
  // Trigonometry
  FunctionSpec('sin', 1, 1, _t, 'sin(x)', 'Sine', 'Sine of an angle.'),
  FunctionSpec('cos', 1, 1, _t, 'cos(x)', 'Cosine', 'Cosine of an angle.'),
  FunctionSpec('tan', 1, 1, _t, 'tan(x)', 'Tangent', 'Tangent of an angle.'),
  FunctionSpec('sec', 1, 1, _t, 'sec(x)', 'Secant', '1 / cos(x).'),
  FunctionSpec('csc', 1, 1, _t, 'csc(x)', 'Cosecant', '1 / sin(x).'),
  FunctionSpec('cot', 1, 1, _t, 'cot(x)', 'Cotangent', '1 / tan(x).'),
  FunctionSpec('asin', 1, 1, _t, 'asin(x)', 'Inverse sine', 'Angle whose sine is x.'),
  FunctionSpec('acos', 1, 1, _t, 'acos(x)', 'Inverse cosine', 'Angle whose cosine is x.'),
  FunctionSpec('atan', 1, 1, _t, 'atan(x)', 'Inverse tangent', 'Angle whose tangent is x.'),
  FunctionSpec('atan2', 2, 2, _t, 'atan2(y, x)', 'Two-argument inverse tangent', 'Angle of the point (x, y).'),
  // Hyperbolic
  FunctionSpec('sinh', 1, 1, _h, 'sinh(x)', 'Hyperbolic sine', 'Hyperbolic sine.'),
  FunctionSpec('cosh', 1, 1, _h, 'cosh(x)', 'Hyperbolic cosine', 'Hyperbolic cosine.'),
  FunctionSpec('tanh', 1, 1, _h, 'tanh(x)', 'Hyperbolic tangent', 'Hyperbolic tangent.'),
  FunctionSpec('asinh', 1, 1, _h, 'asinh(x)', 'Inverse hyperbolic sine', 'Inverse hyperbolic sine.'),
  FunctionSpec('acosh', 1, 1, _h, 'acosh(x)', 'Inverse hyperbolic cosine', 'Inverse hyperbolic cosine.'),
  FunctionSpec('atanh', 1, 1, _h, 'atanh(x)', 'Inverse hyperbolic tangent', 'Inverse hyperbolic tangent.'),
  // Rounding and parts
  FunctionSpec('abs', 1, 1, _r, 'abs(x)', 'Absolute value', 'Distance from zero; modulus of a complex number.'),
  FunctionSpec('floor', 1, 1, _r, 'floor(x)', 'Floor', 'Largest integer ≤ x.'),
  FunctionSpec('ceil', 1, 1, _r, 'ceil(x)', 'Ceiling', 'Smallest integer ≥ x.'),
  FunctionSpec('round', 1, 2, _r, 'round(x) or round(x, n)', 'Round', 'Round to the nearest integer or to n decimal places.'),
  FunctionSpec('trunc', 1, 1, _r, 'trunc(x)', 'Integer part', 'Integer part (rounds toward zero).'),
  FunctionSpec('fpart', 1, 1, _r, 'fpart(x)', 'Fractional part', 'x − trunc(x).'),
  FunctionSpec('sign', 1, 1, _r, 'sign(x)', 'Sign', '−1, 0 or 1.'),
  // Arithmetic helpers
  FunctionSpec('factorial', 1, 1, _a, 'factorial(n)', 'Factorial', 'n! = 1·2·…·n; Γ(n+1) for non-integers.'),
  FunctionSpec('gamma', 1, 1, _a, 'gamma(x)', 'Gamma function', 'Γ(x) = (x−1)!.'),
  // Number theory
  FunctionSpec('nCr', 2, 2, _n, 'nCr(n, r)', 'Combinations', 'Number of ways to choose r of n items.'),
  FunctionSpec('nPr', 2, 2, _n, 'nPr(n, r)', 'Permutations', 'Ordered arrangements of r of n items.'),
  FunctionSpec('gcd', 2, -1, _n, 'gcd(a, b, …)', 'Greatest common divisor', 'Greatest common divisor.'),
  FunctionSpec('lcm', 2, -1, _n, 'lcm(a, b, …)', 'Least common multiple', 'Least common multiple.'),
  FunctionSpec('mod', 2, 2, _n, 'mod(a, b)', 'Modulo', 'Remainder with the sign of b (floored division).'),
  FunctionSpec('rem', 2, 2, _n, 'rem(a, b)', 'Remainder', 'Remainder of truncated division (sign of a).'),
  FunctionSpec('quot', 2, 2, _n, 'quot(a, b)', 'Integer quotient', 'Quotient of truncated division.'),
  FunctionSpec('isprime', 1, 1, _n, 'isprime(n)', 'Is prime', '1 if n is prime, otherwise 0.'),
  FunctionSpec('factor', 1, 1, _n, 'factor(n)', 'Prime factorization', 'Prime factorization of an integer.'),
  FunctionSpec('divisors', 1, 1, _n, 'divisors(n)', 'Divisors', 'All positive divisors of n.'),
  FunctionSpec('nextprime', 1, 1, _n, 'nextprime(n)', 'Next prime', 'Smallest prime greater than n.'),
  FunctionSpec('prevprime', 1, 1, _n, 'prevprime(n)', 'Previous prime', 'Largest prime less than n.'),
  FunctionSpec('totient', 1, 1, _n, 'totient(n)', 'Euler totient', 'Count of integers ≤ n coprime to n.'),
  // Random
  FunctionSpec('rand', 0, 0, _rnd, 'rand()', 'Random number', 'Random decimal in [0, 1).'),
  FunctionSpec('randint', 2, 2, _rnd, 'randint(a, b)', 'Random integer', 'Random integer between a and b inclusive.'),
  FunctionSpec('randreal', 2, 2, _rnd, 'randreal(a, b)', 'Random in range', 'Random decimal in [a, b).'),
  FunctionSpec('randlist', 3, 3, _rnd, 'randlist(n, a, b)', 'Random list', 'List of n random integers between a and b.'),
  FunctionSpec('randperm', 1, 1, _rnd, 'randperm(n)', 'Random permutation', 'Random ordering of 1…n.'),
  // Complex
  FunctionSpec('re', 1, 1, _c, 're(z)', 'Real part', 'Real part of z.'),
  FunctionSpec('im', 1, 1, _c, 'im(z)', 'Imaginary part', 'Imaginary part of z.'),
  FunctionSpec('conj', 1, 1, _c, 'conj(z)', 'Conjugate', 'Complex conjugate.'),
  FunctionSpec('arg', 1, 1, _c, 'arg(z)', 'Argument', 'Angle of z in the current angle unit.'),
  FunctionSpec('cis', 1, 1, _c, 'cis(θ)', 'Cis', 'cos θ + i sin θ.'),
  // Matrix
  FunctionSpec('det', 1, 1, _m, 'det(A)', 'Determinant', 'Determinant of a square matrix.'),
  FunctionSpec('inv', 1, 1, _m, 'inv(A)', 'Inverse', 'Matrix inverse.'),
  FunctionSpec('trn', 1, 1, _m, 'trn(A)', 'Transpose', 'Matrix transpose.'),
  FunctionSpec('rank', 1, 1, _m, 'rank(A)', 'Rank', 'Rank of a matrix.'),
  FunctionSpec('trace', 1, 1, _m, 'trace(A)', 'Trace', 'Sum of the diagonal.'),
  FunctionSpec('identity', 1, 1, _m, 'identity(n)', 'Identity matrix', 'n×n identity matrix.'),
  FunctionSpec('zeros', 1, 2, _m, 'zeros(r, c)', 'Zero matrix', 'r×c matrix of zeros.'),
  FunctionSpec('ref', 1, 1, _m, 'ref(A)', 'Row echelon form', 'Row echelon form.'),
  FunctionSpec('rref', 1, 1, _m, 'rref(A)', 'Reduced row echelon form', 'Reduced row echelon form.'),
  FunctionSpec('eigvals', 1, 1, _m, 'eigvals(A)', 'Eigenvalues', 'Eigenvalues of a square matrix.'),
  // Vector
  FunctionSpec('dot', 2, 2, _v, 'dot(a, b)', 'Dot product', 'Scalar product a·b.'),
  FunctionSpec('cross', 2, 2, _v, 'cross(a, b)', 'Cross product', 'Vector product a×b (3D).'),
  FunctionSpec('norm', 1, 1, _v, 'norm(v)', 'Magnitude', 'Length of a vector.'),
  FunctionSpec('unit', 1, 1, _v, 'unit(v)', 'Unit vector', 'Vector divided by its length.'),
  FunctionSpec('angle', 2, 2, _v, 'angle(a, b)', 'Angle between vectors', 'Angle between two vectors.'),
  FunctionSpec('proj', 2, 2, _v, 'proj(a, b)', 'Projection', 'Projection of a onto b.'),
  FunctionSpec('dist', 2, 2, _v, 'dist(a, b)', 'Distance', 'Distance between two points.'),
  // Statistics
  FunctionSpec('mean', 1, -1, _s, 'mean(list)', 'Mean', 'Arithmetic mean.'),
  FunctionSpec('median', 1, -1, _s, 'median(list)', 'Median', 'Middle value.'),
  FunctionSpec('total', 1, -1, _s, 'total(list)', 'Sum of list', 'Sum of the values.'),
  FunctionSpec('min', 1, -1, _s, 'min(list)', 'Minimum', 'Smallest value.'),
  FunctionSpec('max', 1, -1, _s, 'max(list)', 'Maximum', 'Largest value.'),
  FunctionSpec('var', 1, -1, _s, 'var(list)', 'Sample variance', 'Sample variance (n − 1).'),
  FunctionSpec('pvar', 1, -1, _s, 'pvar(list)', 'Population variance', 'Population variance (n).'),
  FunctionSpec('stdev', 1, -1, _s, 'stdev(list)', 'Sample standard deviation', 'Sample standard deviation.'),
  FunctionSpec('pstdev', 1, -1, _s, 'pstdev(list)', 'Population standard deviation', 'Population standard deviation.'),
  // Probability
  FunctionSpec('normpdf', 1, 3, _pr, 'normpdf(x, μ, σ)', 'Normal PDF', 'Normal probability density.'),
  FunctionSpec('normcdf', 1, 3, _pr, 'normcdf(x, μ, σ)', 'Normal CDF', 'P(X ≤ x) for a normal distribution.'),
  FunctionSpec('invnorm', 1, 3, _pr, 'invnorm(p, μ, σ)', 'Inverse normal', 'x such that P(X ≤ x) = p.'),
  FunctionSpec('binompdf', 3, 3, _pr, 'binompdf(n, p, k)', 'Binomial PDF', 'P(X = k).'),
  FunctionSpec('binomcdf', 3, 3, _pr, 'binomcdf(n, p, k)', 'Binomial CDF', 'P(X ≤ k).'),
  FunctionSpec('poissonpdf', 2, 2, _pr, 'poissonpdf(λ, k)', 'Poisson PDF', 'P(X = k).'),
  FunctionSpec('poissoncdf', 2, 2, _pr, 'poissoncdf(λ, k)', 'Poisson CDF', 'P(X ≤ k).'),
  // Calculus (higher-order)
  FunctionSpec('deriv', 3, 4, _cal, 'deriv(f, x, a, n)', 'Derivative at a point', 'n-th derivative of f with respect to x at x = a.', lazy: true),
  FunctionSpec('integral', 4, 4, _cal, 'integral(f, x, a, b)', 'Definite integral', 'Integral of f from a to b.', lazy: true),
  FunctionSpec('sum', 4, 4, _cal, 'sum(f, k, a, b)', 'Summation', 'Σ f for k from a to b.', lazy: true),
  FunctionSpec('prod', 4, 4, _cal, 'prod(f, k, a, b)', 'Product', 'Π f for k from a to b.', lazy: true),
  FunctionSpec('lim', 3, 3, _cal, 'lim(f, x, a)', 'Limit', 'Limit of f as x approaches a.', lazy: true),
  FunctionSpec('limleft', 3, 3, _cal, 'limleft(f, x, a)', 'Left limit', 'Limit as x approaches a from below.', lazy: true),
  FunctionSpec('limright', 3, 3, _cal, 'limright(f, x, a)', 'Right limit', 'Limit as x approaches a from above.', lazy: true),
];

final Map<String, FunctionSpec> functionIndex = {
  for (final f in builtinFunctions) f.name: f,
};

/// Names that the parser treats as named constants.
const Set<String> builtinConstantNames = {'pi', 'e', 'phi', 'i', 'inf'};

/// Aliases accepted in typed/pasted input.
const Map<String, String> functionAliases = {
  'arcsin': 'asin',
  'arccos': 'acos',
  'arctan': 'atan',
  'arsinh': 'asinh',
  'arcosh': 'acosh',
  'artanh': 'atanh',
  'transpose': 'trn',
  'fact': 'factorial',
  'lg': 'log',
  'ncr': 'nCr',
  'npr': 'nPr',
  'frac': 'fpart',
  'ipart': 'trunc',
  'mag': 'norm',
  'magnitude': 'norm',
  'conjugate': 'conj',
  'avg': 'mean',
  'sd': 'stdev',
};
