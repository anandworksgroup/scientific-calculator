part of 'num.dart';

/// Complex number `re + im·i`; both parts are real [Num]s ([Rat] or [Dec]).
///
/// Use [Cpx.of] to construct: it collapses to a real number when the
/// imaginary part is exactly zero.
final class Cpx extends Num {
  const Cpx._(this.re, this.im);

  static Num of(Num re, Num im) {
    assert(re is! Cpx && im is! Cpx);
    if (im is Rat && im.isZero) return re;
    return Cpx._(re, im);
  }

  static final Cpx i = Cpx._(Rat.zero, Rat.one);

  final Num re;
  final Num im;

  @override
  bool get isZero => re.isZero && im.isZero;

  bool get isExact => re is Rat && im is Rat;

  @override
  double toDouble() => im.isZero ? re.toDouble() : double.nan;

  @override
  bool operator ==(Object other) => other is Cpx && other.re == re && other.im == im;

  @override
  int get hashCode => Object.hash(re, im);

  @override
  String toString() => '($re + ${im}i)';
}
