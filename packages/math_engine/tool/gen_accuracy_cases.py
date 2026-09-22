"""Deterministic generator for the math_engine accuracy test suite.

Reference oracle: mpmath (arbitrary precision) and fractions.Fraction (exact).

Run from the package root:

    python tool/gen_accuracy_cases.py

Writes test/data/accuracy_cases.json, a list of case objects:

    expr       expression text fed to DefaultMathEngine.evaluate
    angle      "deg" | "rad" | "grad"
    precision  CalcSettings.precision
    complex    CalcSettings.complexResults (optional, default false)
    kind       "real"    expect = normalized decimal (see norm_real)
               "complex" expect = "<re>|<im>" (each normalized)
               "exact"   expect = "n" or "n/d" (engine must return an exact Rat)
               "digits"  expect = normalized decimal rounded to `digits` sig digits;
                         compared as digit strings (high-precision cases)
               "matrix"  expect = [[ "n/d", ...], ...] exact entries
               "bool"    expect = "true" | "false"
               "error"   error = MathErrorCode name
    rel_tol / abs_tol   tolerances for real/complex kinds
    digits     number of significant digits for kind "digits"
    cat        category label (for grouping in the Dart test)
    known_issue  true for engine discrepancies (skipped in the Dart test, see note)
    note       explanation for known issues

Normalized decimal format (shared with the Dart test): "0" or
"[-]D.DDDDE<exp>" with trailing zeros of the mantissa removed.
"""

import json
import os
import random
import sys
from fractions import Fraction

import mpmath as mp

sys.set_int_max_str_digits(0)
SEED = 20260922
R = random.Random(SEED)
mp.mp.dps = 60

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "test", "data", "accuracy_cases.json")

CASES = []

TOL = 1e-13
ABS = 1e-15


# --------------------------------------------------------------- formatting

def norm_real(v, sig=30):
    """Normalized decimal string of an mpf with `sig` significant digits."""
    v = mp.mpf(v)
    if v == 0:
        return "0"
    neg = v < 0
    a = abs(v)
    e = int(mp.floor(mp.log10(a)))
    # Fix possible off-by-one from log10 rounding.
    while a >= mp.mpf(10) ** (e + 1):
        e += 1
    while a < mp.mpf(10) ** e:
        e -= 1
    digits = int(mp.nint(a / mp.mpf(10) ** (e - sig + 1)))
    if digits >= 10 ** sig:
        digits //= 10
        e += 1
    s = str(digits).rstrip("0") or "0"
    mant = s[0] + ("." + s[1:] if len(s) > 1 else "")
    return ("-" if neg else "") + mant + "E" + str(e)


def near_tie(v, sig):
    """True when rounding `v` to `sig` digits is ambiguous (guards double rounding)."""
    v = mp.mpf(v)
    if v == 0:
        return False
    a = abs(v)
    e = int(mp.floor(mp.log10(a)))
    scaled = a / mp.mpf(10) ** (e - sig + 1)
    frac = scaled - mp.floor(scaled)
    return abs(frac - mp.mpf("0.5")) < mp.mpf("0.02") or frac < mp.mpf("1e-6") or frac > 1 - mp.mpf("1e-6")


def frac_str(f):
    f = Fraction(f)
    return str(f.numerator) if f.denominator == 1 else f"{f.numerator}/{f.denominator}"


def dec_str(f, max_digits=None):
    """Exact finite decimal text for a Fraction whose denominator is 2^a 5^b."""
    f = Fraction(f)
    neg = f < 0
    f = abs(f)
    k = 0
    while (f * 10 ** k).denominator != 1:
        k += 1
        if k > 60:
            raise ValueError("not a finite decimal")
    n = (f * 10 ** k).numerator
    s = str(n).rjust(k + 1, "0")
    out = s if k == 0 else s[:-k] + "." + s[-k:]
    return ("-" if neg else "") + out


def mpf_of(f):
    f = Fraction(f)
    return mp.mpf(f.numerator) / f.denominator


def par(s):
    """Parenthesize negative literals."""
    return f"({s})" if s.startswith("-") else s


# --------------------------------------------------------------- add helpers

def add(expr, kind, expect=None, angle="rad", precision=15, cat="misc", rel=TOL, abs_tol=ABS,
        complex_mode=False, error=None, digits=None, known=None):
    c = {"expr": expr, "angle": angle, "precision": precision, "kind": kind, "cat": cat}
    if complex_mode:
        c["complex"] = True
    if expect is not None:
        c["expect"] = expect
    if error is not None:
        c["error"] = error
    if kind in ("real", "complex"):
        c["rel_tol"] = rel
        c["abs_tol"] = abs_tol
    if digits is not None:
        c["digits"] = digits
    if known:
        # Formerly skipped engine bugs; all fixed on 2026-09-22, so these
        # now run as ordinary regression cases.
        c["note"] = known
    CASES.append(c)


def real(expr, value, **kw):
    add(expr, "real", norm_real(value), **kw)


def cplx(expr, value, **kw):
    z = mp.mpc(value)
    if not (mp.isfinite(z.real) and mp.isfinite(z.imag)):
        return  # singular point (e.g. atan(i)); covered by error cases instead
    add(expr, "complex", norm_real(z.real) + "|" + norm_real(z.imag), **kw)


def exact(expr, value, **kw):
    add(expr, "exact", frac_str(value), **kw)


def err(expr, code, **kw):
    add(expr, "error", error=code, **kw)


def digits_case(expr, value, n, precision, **kw):
    if near_tie(value, n):
        return False
    add(expr, "digits", norm_real(value, n), precision=precision, digits=n, **kw)
    return True


# --------------------------------------------------------------- random data

def rand_dec(lo=-100, hi=100, places=None):
    places = R.randint(0, 4) if places is None else places
    scale = 10 ** places
    n = R.randint(int(lo * scale), int(hi * scale))
    return Fraction(n, scale)


def rand_frac(maxn=50, maxd=30):
    d = R.randint(1, maxd)
    n = R.randint(-maxn, maxn)
    return Fraction(n, d)


def lit(f):
    """Engine literal for a Fraction (decimal if finite, else n/d in parens)."""
    f = Fraction(f)
    try:
        s = dec_str(f)
        if len(s) <= 20:
            return s
    except ValueError:
        pass
    return f"({f.numerator}/{f.denominator})"


# =============================================================== categories

def gen_arith():
    ops = ["+", "-", "*", "/"]
    for _ in range(220):
        form = R.randint(0, 4)
        a, b, c = (rand_dec(-1000, 1000) if R.random() < 0.6 else rand_frac() for _ in range(3))
        oa, ob = R.choice(ops), R.choice(ops)

        def ap(x, y, o):
            if o == "+":
                return x + y
            if o == "-":
                return x - y
            if o == "*":
                return x * y
            return None if y == 0 else x / y

        if form == 0:
            v = ap(a, b, oa)
            e = f"{par(lit(a))}{oa}{par(lit(b))}"
        elif form == 1:
            inner = ap(a, b, oa)
            v = None if inner is None else ap(inner, c, ob)
            e = f"({par(lit(a))}{oa}{par(lit(b))}){ob}{par(lit(c))}"
        elif form == 2:
            inner = ap(b, c, ob)
            v = None if inner is None else ap(a, inner, oa)
            e = f"{par(lit(a))}{oa}({par(lit(b))}{ob}{par(lit(c))})"
        elif form == 3:
            # precedence without parentheses: a op b op c
            if oa in "*/" or ob not in "*/":
                inner = ap(a, b, oa)
                v = None if inner is None else ap(inner, c, ob)
            else:
                inner = ap(b, c, ob)
                v = None if inner is None else ap(a, inner, oa)
            e = f"{par(lit(a))}{oa}{par(lit(b))}{ob}{par(lit(c))}"
        else:
            n = R.randint(-6, 8)
            base = rand_frac(20, 9)
            if base == 0 and n <= 0:
                continue
            v = base ** n
            e = f"{par(lit(base))}^{par(str(n))}"
        if v is None:
            continue
        exact(e, v, cat="arith_exact")
    # scientific-notation literals and percent
    for _ in range(60):
        m = rand_dec(-9.999, 9.999, 3)
        k = R.randint(-30, 30)
        m2 = rand_dec(1, 99, 1)
        v = m * Fraction(10) ** k + m2
        exact(f"{par(lit(m))}E{k}+{lit(m2)}" if not lit(m).startswith("-") else f"({lit(m)}E{k})+{lit(m2)}",
              v, cat="arith_exact")
    for _ in range(40):
        p = rand_dec(0, 300, 1)
        exact(f"{lit(p)}%", p / 100, cat="arith_exact")
    # big integers
    for _ in range(40):
        a = R.randint(10 ** 20, 10 ** 40) * R.choice([-1, 1])
        b = R.randint(10 ** 15, 10 ** 30)
        o = R.choice(["+", "-", "*"])
        v = a + b if o == "+" else a - b if o == "-" else a * b
        exact(f"{par(str(a))}{o}{b}", v, cat="arith_exact")
        exact(f"{par(str(a))}/{b}", Fraction(a, b), cat="arith_exact")
    # implicit multiplication
    for _ in range(20):
        a = R.randint(2, 30)
        b = rand_dec(-10, 10, 1)
        exact(f"{a}({lit(b)})", a * b, cat="arith_exact")
        real(f"{a}pi", a * mp.pi, cat="arith_real")
        real(f"{a}e", a * mp.e, cat="arith_real")


def gen_powers_roots():
    for _ in range(80):
        x = rand_dec(0.001, 1000, R.randint(0, 3))
        if x <= 0:
            continue
        y = rand_dec(-20, 20, R.randint(1, 3))
        v = mp.power(mpf_of(x), mpf_of(y))
        real(f"{lit(x)}^{par(lit(y))}", v, cat="powers")
    for _ in range(40):
        x = rand_dec(0.0001, 1e6, R.randint(0, 4))
        if x <= 0:
            continue
        real(f"sqrt({lit(x)})", mp.sqrt(mpf_of(x)), cat="roots")
        real(f"cbrt({lit(x)})", mp.cbrt(mpf_of(x)), cat="roots")
        real(f"cbrt(-{lit(x)})", -mp.cbrt(mpf_of(x)), cat="roots")
        n = R.randint(2, 9)
        real(f"nroot({n},{lit(x)})", mp.root(mpf_of(x), n), cat="roots")
    # perfect powers must be exact
    for _ in range(60):
        r = rand_frac(40, 20)
        if r == 0:
            continue
        k = R.randint(2, 5)
        p = r ** k
        if k % 2 == 0:
            exact(f"nroot({k},{lit(abs(p))})", abs(r), cat="roots_exact")
        else:
            exact(f"nroot({k},{lit(p)})", r, cat="roots_exact")
        if k == 2:
            exact(f"sqrt({lit(p)})", abs(r), cat="roots_exact")
    # large exact powers
    for b, n in [(2, 10000), (3, 2000), (7, 500), (Fraction(3, 2), 200), (Fraction(-5, 7), 151), (10, 400)]:
        exact(f"{par(lit(b))}^{n}", Fraction(b) ** n, cat="powers_exact")
        inv = Fraction(b) ** -n
        if inv.denominator != 1 and inv.numerator.bit_length() + inv.denominator.bit_length() > 8000:
            # beyond Arith.ratBitLimit the engine intentionally switches to a decimal
            real(f"{par(lit(b))}^(-{n})", mpf_of(inv), cat="powers")
        else:
            exact(f"{par(lit(b))}^(-{n})", inv, cat="powers_exact")
    add("[[1,1],[1,0]]^50", "matrix", [["20365011074", "12586269025"], ["12586269025", "7778742049"]], cat="matrix")
    # rational exponents of perfect powers
    for b, e, v in [("8", "2/3", 4), ("27", "4/3", 81), ("16", "-3/4", Fraction(1, 8)),
                    ("(-8)", "1/3", -2), ("(-32)", "3/5", -8), ("(1/64)", "1/2", Fraction(1, 8))]:
        exact(f"{b}^({e})", v, cat="roots_exact")
    # huge / tiny magnitudes
    for _ in range(40):
        x = rand_dec(1.01, 9.99, 2)
        y = R.randint(50, 2000)
        v = mp.power(mpf_of(x), y)
        real(f"{lit(x)}^{y}", v, cat="powers")
        real(f"{lit(x)}^(-{y})", 1 / v, cat="powers")
        real(f"{lit(x)}^{y}.5", mp.power(mpf_of(x), y + mp.mpf("0.5")), cat="powers")


def gen_exp_log():
    for _ in range(80):
        x = rand_dec(-690, 690, R.randint(0, 4))
        real(f"exp({lit(x)})", mp.exp(mpf_of(x)), cat="exp")
    for _ in range(30):
        x = rand_dec(-5000, 5000, 2)
        real(f"exp({lit(x)})", mp.exp(mpf_of(x)), cat="exp")
    for _ in range(30):
        x = rand_dec(-1, 1, 6) * Fraction(1, 10 ** R.randint(0, 8))
        real(f"exp({lit(x)})", mp.exp(mpf_of(x)), cat="exp")
        real(f"e^({lit(x)})", mp.exp(mpf_of(x)), cat="exp")
    for _ in range(60):
        m = rand_dec(1, 9.999, R.randint(0, 3))
        k = R.randint(-300, 300)
        x = m * Fraction(10) ** k
        mx = mpf_of(x)
        t = f"{lit(m)}E{k}"
        real(f"ln({t})", mp.ln(mx), cat="log")
        real(f"log({t})", mp.log10(mx), cat="log")
        real(f"log2({t})", mp.log(mx, 2), cat="log")
    for _ in range(40):
        x = 1 + rand_dec(-1, 1, 6) * Fraction(1, 10 ** R.randint(0, 6))
        if x <= 0 or x == 1:
            continue
        real(f"ln({lit(x)})", mp.ln(mpf_of(x)), cat="log", abs_tol=1e-30)
    for _ in range(60):
        b = rand_dec(1.1, 50, 2)
        x = rand_dec(0.001, 1e5, 3)
        if x <= 0 or b == 1:
            continue
        real(f"log({lit(b)},{lit(x)})", mp.log(mpf_of(x)) / mp.log(mpf_of(b)), cat="log")
    for b in range(2, 11):
        for k in range(-3, 7):
            exact(f"log({b},{lit(Fraction(b) ** k)})", k, cat="log_exact")
    for k in range(-20, 21):
        exact(f"log({lit(Fraction(10) ** k)})", k, cat="log_exact")


TRIG = {
    "sin": mp.sin, "cos": mp.cos, "tan": mp.tan,
    "sec": mp.sec, "csc": mp.csc, "cot": mp.cot,
}
INV = {"asin": mp.asin, "acos": mp.acos, "atan": mp.atan}
UNIT = {"rad": mp.mpf(1), "deg": mp.pi / 180, "grad": mp.pi / 200}
FULL = {"deg": 360, "grad": 400}


def trig_ok(fn, rad_val):
    """Skip points where the function is (numerically) at a pole."""
    s, c = mp.sin(rad_val), mp.cos(rad_val)
    if fn in ("tan", "sec") and abs(c) < mp.mpf("1e-8"):
        return False
    if fn in ("cot", "csc") and abs(s) < mp.mpf("1e-8"):
        return False
    return True


def gen_trig():
    for mode in ("rad", "deg", "grad"):
        lo, hi = {"rad": (-10, 10), "deg": (-720, 720), "grad": (-800, 800)}[mode]
        for fn, f in TRIG.items():
            for _ in range(28):
                x = rand_dec(lo, hi, R.randint(1, 4))
                xr = mpf_of(x) * UNIT[mode]
                if not trig_ok(fn, xr):
                    continue
                real(f"{fn}({lit(x)})", f(xr), angle=mode, cat=f"trig_{mode}", abs_tol=1e-14)
        for fn, f in INV.items():
            for _ in range(25):
                if fn == "atan":
                    x = rand_dec(-1000, 1000, 3) * Fraction(1, 10 ** R.randint(0, 3))
                else:
                    x = rand_dec(-1, 1, R.randint(1, 5))
                v = f(mpf_of(x)) / UNIT[mode]
                real(f"{fn}({lit(x)})", v, angle=mode, cat=f"invtrig_{mode}", abs_tol=1e-13)
        for _ in range(20):
            y = rand_dec(-50, 50, 2)
            x = rand_dec(-50, 50, 2)
            if x == 0 and y == 0:
                continue
            v = mp.atan2(mpf_of(y), mpf_of(x)) / UNIT[mode]
            real(f"atan2({lit(y)},{lit(x)})", v, angle=mode, cat=f"invtrig_{mode}", abs_tol=1e-13)
    # special angles (exact values) in deg and grad, plus rad via pi fractions
    for mode in ("deg", "grad"):
        full = FULL[mode]
        steps = [Fraction(full, k) for k in (8, 12, 10)]
        seen = set()
        for st in steps:
            for m in range(-2, 13):
                a = st * m
                if a in seen:
                    continue
                seen.add(a)
                ar = mpf_of(a) * UNIT[mode]
                for fn, f in TRIG.items():
                    if not trig_ok(fn, ar):
                        continue
                    real(f"{fn}({lit(a)})", f(ar), angle=mode, cat=f"trig_special_{mode}", abs_tol=1e-14)
    for num in range(-6, 13):
        for den in (1, 2, 3, 4, 6, 12):
            q = Fraction(num, den)
            ar = mpf_of(q) * mp.pi
            s = f"{q.numerator}pi/{q.denominator}" if q.denominator != 1 else f"{q.numerator}pi"
            if q == 0:
                s = "0"
            for fn, f in (("sin", mp.sin), ("cos", mp.cos), ("tan", mp.tan)):
                if not trig_ok(fn, ar):
                    continue
                real(f"{fn}({s})", f(ar), angle="rad", cat="trig_special_rad", abs_tol=1e-14)
    # special inverse values
    for x in ["0", "0.5", "-0.5", "1", "-1"]:
        for mode in ("deg", "grad", "rad"):
            for fn, f in INV.items():
                v = f(mp.mpf(x)) / UNIT[mode]
                real(f"{fn}({x})", v, angle=mode, cat="invtrig_special", abs_tol=1e-13)
    # degree marker in rad mode
    for _ in range(30):
        x = rand_dec(-360, 360, 1)
        real(f"sin({lit(x)}°)", mp.sin(mpf_of(x) * mp.pi / 180), angle="rad", cat="trig_rad", abs_tol=1e-14)
        real(f"cos({lit(x)}°)", mp.cos(mpf_of(x) * mp.pi / 180), angle="grad", cat="trig_grad", abs_tol=1e-14)
    # moderately large arguments (argument reduction)
    for k in range(3, 16):
        x = R.randint(10 ** k, 10 ** (k + 1))
        real(f"sin({x})", mp.sin(x), angle="rad", cat="trig_large", abs_tol=1e-14)
        real(f"cos({x})", mp.cos(x), angle="rad", cat="trig_large", abs_tol=1e-14)
    # Large arguments: rad reduction snaps to exact multiples of pi/2 (known issue),
    # deg/grad reduction goes through a 21-digit radian value (known issue).
    note_rad = ("sinCos() treats a residue r < |x|*10^-(wp-3) as an exact multiple of pi/2; for |x| >= ~1e15 "
                "at precision 15 every argument snaps to 0/+-1")
    for x in ["1E18", "1E19", "1E20", "1E22", "123456789012345678", "1E25", "1E30"]:
        real(f"sin({x})", mp.sin(mp.mpf(x)), angle="rad", cat="trig_large", abs_tol=1e-14, known=note_rad)
        real(f"cos({x})", mp.cos(mp.mpf(x)), angle="rad", cat="trig_large", abs_tol=1e-14, known=note_rad)
    note_deg = ("deg/grad trig converts the full angle x*pi/180 to a wp-digit radian Dec instead of reducing the "
                "exact rational angle mod 360 first (the reduced value is already computed in _exactDegrees)")
    for k in (12, 14, 16, 18, 20, 22):
        x = R.randint(10 ** k, 10 ** (k + 1))
        red = x % 360
        real(f"sin({x})", mp.sin(red * mp.pi / 180), angle="deg", cat="trig_large", abs_tol=1e-14,
             known=note_deg)
    for x in ["1E20", "1E22"]:
        red = int(mp.mpf(x)) % 360
        real(f"sin({x})", mp.sin(red * mp.pi / 180), angle="deg", cat="trig_large", abs_tol=1e-14, known=note_deg)


def gen_hyperbolic():
    fns = {"sinh": mp.sinh, "cosh": mp.cosh, "tanh": mp.tanh}
    for fn, f in fns.items():
        for _ in range(18):
            x = rand_dec(-50, 50, R.randint(0, 4))
            real(f"{fn}({lit(x)})", f(mpf_of(x)), cat="hyperbolic", abs_tol=1e-15)
        for _ in range(10):
            x = rand_dec(-1, 1, 6) * Fraction(1, 10 ** R.randint(1, 8))
            real(f"{fn}({lit(x)})", f(mpf_of(x)), cat="hyperbolic", abs_tol=1e-30)
        for _ in range(8):
            x = rand_dec(-2000, 2000, 1)
            real(f"{fn}({lit(x)})", f(mpf_of(x)), cat="hyperbolic", abs_tol=1e-15)
    for _ in range(25):
        x = rand_dec(-1e4, 1e4, 3)
        real(f"asinh({lit(x)})", mp.asinh(mpf_of(x)), cat="hyperbolic", abs_tol=1e-15)
        y = rand_dec(1, 1e4, 3)
        real(f"acosh({lit(y)})", mp.acosh(mpf_of(y)), cat="hyperbolic", abs_tol=1e-15)
        z = rand_dec(-0.9999, 0.9999, 4)
        real(f"atanh({lit(z)})", mp.atanh(mpf_of(z)), cat="hyperbolic", abs_tol=1e-15)
    for _ in range(10):
        x = rand_dec(-1, 1, 6) * Fraction(1, 10 ** R.randint(1, 8))
        real(f"asinh({lit(x)})", mp.asinh(mpf_of(x)), cat="hyperbolic", abs_tol=1e-30)
        real(f"atanh({lit(x)})", mp.atanh(mpf_of(x)), cat="hyperbolic", abs_tol=1e-30)


def gen_gamma():
    import math
    for n in list(range(0, 31)) + [R.randint(31, 3000) for _ in range(25)]:
        exact(f"{n}!", math.factorial(n), cat="factorial_exact")
        if n < 200:
            exact(f"factorial({n})", math.factorial(n), cat="factorial_exact")
    for n in range(1, 40):
        exact(f"gamma({n})", math.factorial(n - 1), cat="factorial_exact")
    for _ in range(80):
        x = rand_dec(-20, 60, R.randint(1, 4))
        if x <= 0 and x.denominator == 1:
            continue
        real(f"gamma({lit(x)})", mp.gamma(mpf_of(x)), cat="gamma")
    for _ in range(40):
        x = rand_dec(-9, 30, R.randint(1, 3))
        if x < 0 and x.denominator == 1:
            continue
        real(f"factorial({lit(x)})", mp.gamma(mpf_of(x) + 1), cat="gamma")
        real(f"({lit(x)})!", mp.gamma(mpf_of(x) + 1), cat="gamma")
    for _ in range(15):
        x = rand_dec(100, 3000, 2)
        real(f"gamma({lit(x)})", mp.gamma(mpf_of(x)), cat="gamma")
    for x in ["0.5", "1.5", "-0.5", "-1.5", "0.001", "-0.001", "1E-10", "170.5", "171.5"]:
        real(f"gamma({x})", mp.gamma(mp.mpf(x)), cat="gamma")


def gen_number_theory():
    import math
    for _ in range(70):
        n = R.randint(0, 60)
        r = R.randint(0, n + 2)
        exact(f"nCr({n},{r})", math.comb(n, r), cat="combinatorics")
        exact(f"nPr({n},{r})", math.perm(n, r) if r <= n else 0, cat="combinatorics")
    for _ in range(20):
        n = R.randint(100, 1000)
        r = R.randint(0, n)
        exact(f"nCr({n},{r})", math.comb(n, r), cat="combinatorics")
    for _ in range(30):
        a = R.randint(-10 ** 6, 10 ** 6)
        b = R.randint(1, 10 ** 5) * R.choice([-1, 1])
        exact(f"gcd({a},{b})", math.gcd(a, b), cat="number_theory")
        exact(f"lcm({a},{b})", abs(a * b) // math.gcd(a, b) if a else 0, cat="number_theory")
        exact(f"mod({a},{b})", a % b, cat="number_theory")
        q = abs(a) // abs(b) * (1 if (a >= 0) == (b > 0) else -1)
        exact(f"quot({a},{b})", q, cat="number_theory")
        exact(f"rem({a},{b})", a - q * b, cat="number_theory")
    for _ in range(20):
        a = rand_dec(-100, 100, 2)
        b = rand_dec(0.5, 20, 1)
        if b == 0:
            continue
        exact(f"mod({lit(a)},{lit(b)})", a - b * math.floor(a / b), cat="number_theory")
    for _ in range(25):
        n = R.randint(1, 10 ** 6)
        exact(f"totient({n})", totient(n), cat="number_theory")
        exact(f"nextprime({n})", next_prime(n), cat="number_theory")
        add(f"isprime({n})", "bool", "true" if is_prime(n) else "false", cat="number_theory")
    for p in [2, 3, 97, 7919, 104729, 1000003, 2147483647, 1000000007, 999999999989]:
        add(f"isprime({p})", "bool", "true", cat="number_theory")
        add(f"isprime({p * 3})", "bool", "false", cat="number_theory")
    # rounding family
    for _ in range(25):
        x = rand_dec(-1000, 1000, R.randint(1, 5))
        exact(f"floor({lit(x)})", math.floor(x), cat="rounding")
        exact(f"ceil({lit(x)})", math.ceil(x), cat="rounding")
        exact(f"trunc({lit(x)})", math.trunc(x), cat="rounding")
        exact(f"fpart({lit(x)})", x - math.trunc(x), cat="rounding")
        exact(f"abs({lit(x)})", abs(x), cat="rounding")
        exact(f"sign({lit(x)})", (x > 0) - (x < 0), cat="rounding")
        n = R.randint(0, 3)
        exact(f"round({lit(x)},{n})", round_half_away(x, n), cat="rounding")
        exact(f"round({lit(x)})", round_half_away(x, 0), cat="rounding")
    for x in ["2.5", "-2.5", "0.5", "-0.5", "1.5", "3.5"]:
        exact(f"round({x})", round_half_away(Fraction(x), 0), cat="rounding")
    for x, n in [("0.125", 2), ("-1.2345", 3), ("2.675", 2), ("1.005", 2)]:
        exact(f"round({x},{n})", round_half_away(Fraction(x), n), cat="rounding")


def round_half_away(x, n):
    s = Fraction(10) ** n
    y = abs(x) * s
    r = int(y + Fraction(1, 2))
    return (r if x >= 0 else -r) / s


def is_prime(n):
    if n < 2:
        return False
    for p in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        if n % p == 0:
            return n == p
    d, s = n - 1, 0
    while d % 2 == 0:
        d //= 2
        s += 1
    for a in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(s - 1):
            x = x * x % n
            if x == n - 1:
                break
        else:
            return False
    return True


def next_prime(n):
    m = n + 1
    while not is_prime(m):
        m += 1
    return m


def totient(n):
    res, m, p = n, n, 2
    while p * p <= m:
        if m % p == 0:
            while m % p == 0:
                m //= p
            res -= res // p
        p += 1
    if m > 1:
        res -= res // m
    return res


def rand_cpx(lo=-10, hi=10):
    return (rand_dec(lo, hi, R.randint(0, 2)), rand_dec(lo, hi, R.randint(0, 2)))


def cpx_lit(z):
    a, b = z
    bs = lit(abs(b))
    sign = "-" if b < 0 else "+"
    return f"({lit(a)}{sign}{bs}i)"


def gen_complex():
    for _ in range(35):
        z, w = rand_cpx(), rand_cpx()
        if z[1] == 0 or w[1] == 0:
            continue
        zc = mp.mpc(mpf_of(z[0]), mpf_of(z[1]))
        wc = mp.mpc(mpf_of(w[0]), mpf_of(w[1]))
        for o, v in (("+", zc + wc), ("-", zc - wc), ("*", zc * wc), ("/", zc / wc)):
            cplx(f"{cpx_lit(z)}{o}{cpx_lit(w)}", v, cat="complex_arith", abs_tol=1e-14)
        n = R.randint(-5, 8)
        cplx(f"{cpx_lit(z)}^{par(str(n))}", zc ** n, cat="complex_arith", abs_tol=1e-14)
    for fn, f in (("sqrt", mp.sqrt), ("exp", mp.exp), ("ln", mp.ln), ("sin", mp.sin), ("cos", mp.cos),
                  ("tan", mp.tan), ("sinh", mp.sinh), ("cosh", mp.cosh), ("tanh", mp.tanh),
                  ("asin", mp.asin), ("acos", mp.acos), ("atan", mp.atan)):
        for _ in range(14):
            z = rand_cpx(-3, 3)
            if z[1] == 0:
                continue
            zc = mp.mpc(mpf_of(z[0]), mpf_of(z[1]))
            cplx(f"{fn}{cpx_lit(z)}", f(zc), cat="complex_fn", abs_tol=1e-14)
    for _ in range(40):
        z, w = rand_cpx(-4, 4), rand_cpx(-2, 2)
        if z[1] == 0 or w[1] == 0:
            continue
        zc = mp.mpc(mpf_of(z[0]), mpf_of(z[1]))
        wc = mp.mpc(mpf_of(w[0]), mpf_of(w[1]))
        cplx(f"{cpx_lit(z)}^{cpx_lit(w)}", mp.power(zc, wc), cat="complex_pow", abs_tol=1e-14)
        x = rand_dec(0.1, 10, 2)
        cplx(f"{lit(x)}^{cpx_lit(w)}", mp.power(mpf_of(x), wc), cat="complex_pow", abs_tol=1e-14)
        y = rand_dec(-3, 3, 1)
        cplx(f"{cpx_lit(z)}^{par(lit(y))}", mp.power(zc, mpf_of(y)), cat="complex_pow", abs_tol=1e-14)
    for _ in range(25):
        z = rand_cpx(-50, 50)
        if z[1] == 0:
            continue
        zc = mp.mpc(mpf_of(z[0]), mpf_of(z[1]))
        real(f"abs{cpx_lit(z)}", abs(zc), cat="complex_parts")
        real(f"arg{cpx_lit(z)}", mp.arg(zc), cat="complex_parts", abs_tol=1e-14)
        real(f"arg{cpx_lit(z)}", mp.arg(zc) * 180 / mp.pi, angle="deg", cat="complex_parts", abs_tol=1e-12)
        exact(f"re{cpx_lit(z)}", z[0], cat="complex_parts")
        exact(f"im{cpx_lit(z)}", z[1], cat="complex_parts")
        cplx(f"conj{cpx_lit(z)}", mp.conj(zc), cat="complex_parts")
    # complexResults mode: real inputs with complex results
    for _ in range(20):
        x = rand_dec(-100, -0.01, 2)
        cplx(f"sqrt({lit(x)})", mp.sqrt(mpf_of(x)), cat="complex_mode", complex_mode=True)
        cplx(f"ln({lit(x)})", mp.ln(mpf_of(x)), cat="complex_mode", complex_mode=True)
        cplx(f"log({lit(x)})", mp.log10(mpf_of(x)), cat="complex_mode", complex_mode=True)
    for x in ["2", "-2", "1.5", "-3.25", "10"]:
        cplx(f"asin({x})", mp.asin(mp.mpf(x)), cat="complex_mode", complex_mode=True)
        cplx(f"acos({x})", mp.acos(mp.mpf(x)), cat="complex_mode", complex_mode=True)
        cplx(f"atanh({x})", mp.atanh(mp.mpf(x)), cat="complex_mode", complex_mode=True)
    for x in ["0.5", "-2", "0", "-0.75"]:
        cplx(f"acosh({x})", mp.acosh(mp.mpf(x)), cat="complex_mode", complex_mode=True)
    cplx("i^2", -1, cat="complex_arith")
    cplx("e^(i*pi)", -1, cat="complex_fn", abs_tol=1e-14)
    cplx("i^i", mp.power(1j, 1j), cat="complex_pow")
    cplx("sqrt(i)", mp.sqrt(1j), cat="complex_fn")


def gen_statistics():
    for _ in range(35):
        n = R.randint(2, 12)
        xs = [rand_dec(-100, 100, R.randint(0, 2)) for _ in range(n)]
        args = ",".join(lit(x) for x in xs)
        mean = sum(xs) / n
        ss = sum((x - mean) ** 2 for x in xs)
        exact(f"mean({args})", mean, cat="statistics")
        s = sorted(xs)
        med = s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2
        exact(f"median({args})", med, cat="statistics")
        exact(f"var({args})", ss / (n - 1), cat="statistics")
        exact(f"pvar({args})", ss / n, cat="statistics")
        real(f"stdev({args})", mp.sqrt(mpf_of(ss / (n - 1))), cat="statistics")
        real(f"pstdev({args})", mp.sqrt(mpf_of(ss / n)), cat="statistics")


def probit(p):
    return mp.sqrt(2) * mp.erfinv(2 * p - 1)


def gen_probability():
    P = 1e-9
    for _ in range(25):
        x = rand_dec(-6, 6, 3)
        real(f"normcdf({lit(x)})", mp.ncdf(mpf_of(x)), cat="probability", rel=P, abs_tol=1e-15)
        real(f"normpdf({lit(x)})", mp.npdf(mpf_of(x)), cat="probability", rel=P, abs_tol=1e-15)
        mu, sd = rand_dec(-10, 10, 1), rand_dec(0.1, 5, 2)
        real(f"normcdf({lit(x)},{lit(mu)},{lit(sd)})", mp.ncdf(mpf_of(x), mpf_of(mu), mpf_of(sd)),
             cat="probability", rel=P, abs_tol=1e-15)
        real(f"normpdf({lit(x)},{lit(mu)},{lit(sd)})", mp.npdf(mpf_of(x), mpf_of(mu), mpf_of(sd)),
             cat="probability", rel=P, abs_tol=1e-15)
    for x in ["-8", "-10", "-15", "-20", "-30", "8", "10"]:
        real(f"normcdf({x})", mp.ncdf(mp.mpf(x)), cat="probability_tail", rel=P, abs_tol=1e-300)
    for _ in range(50):
        p = rand_dec(0.0001, 0.9999, 4)
        v = probit(mpf_of(p))
        real(f"invnorm({lit(p)})", v, cat="probability", rel=P, abs_tol=1e-12)
    for p in ["1E-10", "1E-6", "0.999999"]:
        v = probit(mp.mpf(p))
        real(f"invnorm({p})", v, cat="probability", rel=P, abs_tol=1e-12)
    for _ in range(20):
        p = rand_dec(0.01, 0.99, 2)
        mu, sd = rand_dec(-10, 10, 1), rand_dec(0.1, 5, 2)
        v = mpf_of(mu) + mpf_of(sd) * probit(mpf_of(p))
        real(f"invnorm({lit(p)},{lit(mu)},{lit(sd)})", v, cat="probability", rel=P, abs_tol=1e-12)
    for _ in range(35):
        n = R.randint(1, 60)
        p = rand_dec(0.01, 0.99, 2)
        k = R.randint(0, n)
        pf = mpf_of(p)
        pmf = lambda j: mp.binomial(n, j) * pf ** j * (1 - pf) ** (n - j)
        real(f"binompdf({n},{lit(p)},{k})", pmf(k), cat="probability", rel=P, abs_tol=1e-15)
        real(f"binomcdf({n},{lit(p)},{k})", mp.fsum(pmf(j) for j in range(k + 1)), cat="probability",
             rel=P, abs_tol=1e-15)
    for _ in range(35):
        lam = rand_dec(0.1, 50, 2)
        k = R.randint(0, 80)
        lf = mpf_of(lam)
        pmf = lambda j: mp.exp(-lf) * lf ** j / mp.factorial(j)
        real(f"poissonpdf({lit(lam)},{k})", pmf(k), cat="probability", rel=P, abs_tol=1e-15)
        real(f"poissoncdf({lit(lam)},{k})", mp.fsum(pmf(j) for j in range(k + 1)), cat="probability",
             rel=P, abs_tol=1e-15)


INTEGRANDS = [
    ("x^{n}", lambda a, n: (lambda x: x ** n)),
    ("sin({a}x)", lambda a, n: (lambda x: mp.sin(a * x))),
    ("cos({a}*x)", lambda a, n: (lambda x: mp.cos(a * x))),
    ("exp({a}*x)", lambda a, n: (lambda x: mp.exp(a * x))),
    ("1/(1+x^2)", lambda a, n: (lambda x: 1 / (1 + x ** 2))),
    ("sqrt(1+x^2)", lambda a, n: (lambda x: mp.sqrt(1 + x ** 2))),
    ("x*exp(-x)", lambda a, n: (lambda x: x * mp.exp(-x))),
    ("exp(-x^2)", lambda a, n: (lambda x: mp.exp(-x ** 2))),
    ("x^2*sin(x)", lambda a, n: (lambda x: x ** 2 * mp.sin(x))),
    ("atan(x)", lambda a, n: (lambda x: mp.atan(x))),
    ("cos(x)^2", lambda a, n: (lambda x: mp.cos(x) ** 2)),
    ("1/(x^2+{a})", lambda a, n: (lambda x: 1 / (x ** 2 + a))),
    ("sin(x)*exp(-x/{a})", lambda a, n: (lambda x: mp.sin(x) * mp.exp(-x / a))),
    ("{a}x^3-2x+1", lambda a, n: (lambda x: a * x ** 3 - 2 * x + 1)),
    ("ln(1+x^2)", lambda a, n: (lambda x: mp.ln(1 + x ** 2))),
    ("cosh(x/{a})", lambda a, n: (lambda x: mp.cosh(x / a))),
]


def gen_integrals():
    for tmpl, mk in INTEGRANDS:
        for _ in range(7):
            a = rand_dec(0.5, 3, 1)
            n = R.randint(0, 6)
            lo = rand_dec(-3, 1, 1)
            hi = lo + rand_dec(0.5, 4, 1)
            f = mk(mpf_of(a), n)
            expr = tmpl.replace("{a}", lit(a)).replace("{n}", str(n))
            v = mp.quad(f, [mpf_of(lo), mpf_of(hi)])
            real(f"integral({expr},x,{lit(lo)},{lit(hi)})", v, cat="integral", rel=1e-9, abs_tol=1e-12)
    extra = [
        ("integral(ln(x),x,1,3)", mp.quad(mp.ln, [1, 3])),
        ("integral(sqrt(x),x,0,2)", mp.quad(mp.sqrt, [0, 2])),
        ("integral(1/sqrt(x),x,0,1)", mp.mpf(2)),
        ("integral(sin(x)/x,x,1,5)", mp.quad(lambda x: mp.sin(x) / x, [1, 5])),
        ("integral(sin(x),x,0,pi)", mp.mpf(2)),
        ("integral(exp(-x^2),x,-5,5)", mp.quad(lambda x: mp.exp(-x ** 2), [-5, 5])),
        ("integral(1/x,x,1,e)", mp.mpf(1)),
        ("integral(x^x,x,0,1)", mp.quad(lambda x: x ** x, [0, 1])),
        ("integral(sqrt(1-x^2),x,-1,1)", mp.pi / 2),
        ("integral(4/(1+x^2),x,0,1)", mp.pi),
    ]
    for e, v in extra:
        real(e, v, cat="integral", rel=1e-9, abs_tol=1e-12)


DERIVS = [
    ("x^{n}", lambda a, n: (lambda x: x ** n)),
    ("sin({a}x)", lambda a, n: (lambda x: mp.sin(a * x))),
    ("exp({a}*x)", lambda a, n: (lambda x: mp.exp(a * x))),
    ("ln(x)", lambda a, n: (lambda x: mp.ln(x))),
    ("x*sin(x)", lambda a, n: (lambda x: x * mp.sin(x))),
    ("atan(x)", lambda a, n: (lambda x: mp.atan(x))),
    ("sqrt(x)", lambda a, n: (lambda x: mp.sqrt(x))),
    ("exp(-x^2)", lambda a, n: (lambda x: mp.exp(-x ** 2))),
    ("tan(x)", lambda a, n: (lambda x: mp.tan(x))),
    ("1/(1+{a}x^2)", lambda a, n: (lambda x: 1 / (1 + a * x ** 2))),
    ("x^x", lambda a, n: (lambda x: x ** x)),
    ("cosh(x)*cos(x)", lambda a, n: (lambda x: mp.cosh(x) * mp.cos(x))),
]


def gen_derivatives():
    for tmpl, mk in DERIVS:
        for _ in range(9):
            a = rand_dec(0.5, 3, 1)
            n = R.randint(1, 6)
            x0 = rand_dec(0.2, 1.4, 2)
            order = R.choice([1, 1, 1, 2, 2, 3])
            f = mk(mpf_of(a), n)
            expr = tmpl.replace("{a}", lit(a)).replace("{n}", str(n))
            v = mp.diff(f, mpf_of(x0), order)
            e = f"deriv({expr},x,{lit(x0)})" if order == 1 else f"deriv({expr},x,{lit(x0)},{order})"
            real(e, v, cat="derivative", rel=1e-11, abs_tol=1e-11)


def gen_sums():
    for _ in range(12):
        n = R.randint(5, 200)
        exact(f"sum(k^2,k,1,{n})", sum(k * k for k in range(1, n + 1)), cat="sum_exact")
        exact(f"sum(1/(k*(k+1)),k,1,{n})", Fraction(n, n + 1), cat="sum_exact")
        real(f"sum(1/k^2,k,1,{n})", mp.fsum(mp.mpf(1) / k ** 2 for k in range(1, n + 1)), cat="sum")
        real(f"sum(sin(k),k,1,{n})", mp.fsum(mp.sin(k) for k in range(1, n + 1)), cat="sum", abs_tol=1e-13)
        real(f"sum(1/k!,k,0,{min(n, 40)})", mp.fsum(1 / mp.factorial(k) for k in range(0, min(n, 40) + 1)),
             cat="sum")
        m = R.randint(2, 25)
        exact(f"prod(k,k,1,{m})", Fraction(mp.factorial(m).__int__()), cat="sum_exact")
        real(f"prod(1+1/k^2,k,1,{n})", mp.fprod(1 + mp.mpf(1) / k ** 2 for k in range(1, n + 1)), cat="sum")
        real(f"sum(sqrt(k),k,1,{n})", mp.fsum(mp.sqrt(k) for k in range(1, n + 1)), cat="sum")
        x = rand_dec(-2, 2, 1)
        exact(f"sum({par(lit(x))}^k,k,0,20)", sum(x ** k for k in range(21)), cat="sum_exact")


def gen_limits():
    L = 1e-9
    for _ in range(8):
        a = rand_dec(0.5, 5, 1)
        af = mpf_of(a)
        real(f"lim(sin({lit(a)}x)/x,x,0)", af, cat="limit", rel=L, abs_tol=1e-10)
        real(f"lim((exp({lit(a)}x)-1)/x,x,0)", af, cat="limit", rel=L, abs_tol=1e-10)
        real(f"lim((1-cos({lit(a)}x))/x^2,x,0)", af ** 2 / 2, cat="limit", rel=L, abs_tol=1e-10)
        real(f"lim((x^2-{lit(a * a)})/(x-{lit(a)}),x,{lit(a)})", 2 * af, cat="limit", rel=L, abs_tol=1e-10)
        real(f"lim((sqrt(x+{lit(a)})-sqrt({lit(a)}))/x,x,0)", 1 / (2 * mp.sqrt(af)), cat="limit", rel=L,
             abs_tol=1e-10)
        real(f"lim(ln(1+{lit(a)}x)/x,x,0)", af, cat="limit", rel=L, abs_tol=1e-10)
    for e, v in [("lim((1+1/x)^x,x,inf)", mp.e), ("lim(x*sin(1/x),x,inf)", 1), ("lim(tan(x)/x,x,0)", 1),
                 ("lim((x^3-1)/(x-1),x,1)", 3), ("lim(x^2+3x,x,2)", 10), ("lim(atan(x),x,inf)", mp.pi / 2)]:
        real(e, v, cat="limit", rel=L, abs_tol=1e-10)


def mat_lit(m):
    return "[" + ",".join("[" + ",".join(lit(x) if x >= 0 else lit(x) for x in row) + "]" for row in m) + "]"


def det(m):
    m = [list(map(Fraction, r)) for r in m]
    n = len(m)
    d = Fraction(1)
    for c in range(n):
        p = next((r for r in range(c, n) if m[r][c] != 0), None)
        if p is None:
            return Fraction(0)
        if p != c:
            m[c], m[p] = m[p], m[c]
            d = -d
        d *= m[c][c]
        for r in range(c + 1, n):
            f = m[r][c] / m[c][c]
            for k in range(c, n):
                m[r][k] -= f * m[c][k]
    return d


def inverse(m):
    n = len(m)
    a = [list(map(Fraction, r)) + [Fraction(int(i == j)) for j in range(n)] for i, r in enumerate(m)]
    for c in range(n):
        p = next(r for r in range(c, n) if a[r][c] != 0)
        a[c], a[p] = a[p], a[c]
        pv = a[c][c]
        a[c] = [x / pv for x in a[c]]
        for r in range(n):
            if r != c and a[r][c] != 0:
                f = a[r][c]
                a[r] = [x - f * y for x, y in zip(a[r], a[c])]
    return [row[n:] for row in a]


def rank(m):
    m = [list(map(Fraction, r)) for r in m]
    rows, cols = len(m), len(m[0])
    rk = 0
    for c in range(cols):
        p = next((r for r in range(rk, rows) if m[r][c] != 0), None)
        if p is None:
            continue
        m[rk], m[p] = m[p], m[rk]
        for r in range(rows):
            if r != rk and m[r][c] != 0:
                f = m[r][c] / m[rk][c]
                m[r] = [x - f * y for x, y in zip(m[r], m[rk])]
        rk += 1
    return rk


def gen_matrices():
    for _ in range(40):
        n = R.randint(2, 5)
        m = [[R.randint(-9, 9) for _ in range(n)] for _ in range(n)]
        ml = mat_lit(m)
        d = det(m)
        exact(f"det({ml})", d, cat="matrix")
        if d != 0:
            add(f"inv({ml})", "matrix", [[frac_str(x) for x in row] for row in inverse(m)], cat="matrix")
        else:
            err(f"inv({ml})", "singularMatrix", cat="matrix")
        add(f"trn({ml})", "matrix", [[frac_str(m[j][i]) for j in range(n)] for i in range(n)], cat="matrix")
        exact(f"rank({ml})", rank(m), cat="matrix")
    for _ in range(30):
        n = R.randint(2, 4)
        m = [[rand_dec(-5, 5, 1) for _ in range(n)] for _ in range(n)]
        exact(f"det({mat_lit(m)})", det(m), cat="matrix")
    for _ in range(30):
        a, b, c = R.randint(1, 4), R.randint(1, 4), R.randint(1, 4)
        A = [[R.randint(-9, 9) for _ in range(b)] for _ in range(a)]
        B = [[R.randint(-9, 9) for _ in range(c)] for _ in range(b)]
        P = [[sum(A[i][k] * B[k][j] for k in range(b)) for j in range(c)] for i in range(a)]
        if a == 1 and c == 1:
            continue  # 1x1 result may collapse to a scalar
        add(f"{mat_lit(A)}*{mat_lit(B)}", "matrix", [[frac_str(x) for x in r] for r in P], cat="matrix")
    for _ in range(12):
        n = R.randint(2, 4)
        base = [[R.randint(-5, 5) for _ in range(n)] for _ in range(n - 1)]
        k = R.randint(-3, 3)
        m = base + [[k * x for x in base[0]]]
        exact(f"det({mat_lit(m)})", 0, cat="matrix")
        exact(f"rank({mat_lit(m)})", rank(m), cat="matrix")
        err(f"inv({mat_lit(m)})", "singularMatrix", cat="matrix")


def gen_high_precision():
    consts = [("pi", mp.pi), ("e", mp.e), ("phi", mp.phi), ("sqrt(2)", mp.sqrt(2)), ("sqrt(3)", mp.sqrt(3)),
              ("ln(2)", mp.ln(2)), ("ln(10)", mp.ln(10)), ("exp(1/3)", mp.exp(mp.mpf(1) / 3)),
              ("sin(1)", mp.sin(1)), ("cos(1)", mp.cos(1)), ("tan(1)", mp.tan(1)), ("atan(1/7)", mp.atan(mp.mpf(1) / 7)),
              ("asin(1/3)", mp.asin(mp.mpf(1) / 3)), ("acos(1/3)", mp.acos(mp.mpf(1) / 3)),
              ("cbrt(2)", mp.cbrt(2)), ("2^(1/7)", mp.root(2, 7)), ("gamma(1/3)", mp.gamma(mp.mpf(1) / 3)),
              ("gamma(0.5)", mp.sqrt(mp.pi)), ("sinh(1)", mp.sinh(1)), ("atanh(1/2)", mp.atanh(mp.mpf(1) / 2)),
              ("log(7)", mp.log10(7)), ("log2(3)", mp.log(3, 2)), ("e^pi", mp.exp(mp.pi)), ("pi^e", mp.pi ** mp.e),
              ("exp(100)", mp.exp(100)), ("ln(1E-50)", mp.ln(mp.mpf("1e-50"))), ("1/7", mp.mpf(1) / 7),
              ("sqrt(1E-100+1)", mp.sqrt(mp.mpf("1e-100") + 1))]
    for prec, n, dps in ((10, 9, 40), (20, 18, 60), (30, 27, 70), (50, 45, 90), (100, 95, 140)):
        for e, _v in consts:
            with mp.workdps(dps):
                v = eval_hp(e)
                digits_case(e, v, n, prec, cat=f"high_precision_{prec}")
        count = 0
        while count < {10: 30, 20: 30, 30: 30, 50: 70, 100: 40}[prec]:
            with mp.workdps(dps):
                fn = R.choice(["sqrt", "ln", "exp", "sin", "cos", "tan", "atan", "asin", "sinh", "cosh", "tanh",
                               "asinh", "cbrt", "pow", "gamma", "log"])
                p, q = R.randint(1, 999), R.randint(1, 97)
                x = mp.mpf(p) / q
                arg = f"{p}/{q}"
                if fn == "asin":
                    x = mp.mpf(p % 97) / 97
                    arg = f"{p % 97}/97"
                if fn == "gamma":
                    x = mp.mpf(p % 300) / q + mp.mpf(1) / 3
                    arg = f"{p % 300}/{q}+1/3"
                if fn == "pow":
                    yn, yd = R.randint(-50, 50), R.randint(1, 13)
                    y = mp.mpf(yn) / yd
                    expr = f"({arg})^({yn}/{yd})"
                    v = mp.power(x, y)
                else:
                    f = {"sqrt": mp.sqrt, "ln": mp.ln, "exp": mp.exp, "sin": mp.sin, "cos": mp.cos, "tan": mp.tan,
                         "atan": mp.atan, "asin": mp.asin, "sinh": mp.sinh, "cosh": mp.cosh, "tanh": mp.tanh,
                         "asinh": mp.asinh, "cbrt": mp.cbrt, "gamma": mp.gamma, "log": mp.log10}[fn]
                    if fn in ("exp", "sinh", "cosh") and x > 200:
                        continue
                    v = f(x)
                    expr = f"{fn}({arg})"
                if isinstance(v, mp.mpc) or v == 0:
                    continue
                if digits_case(expr, v, n, prec, cat=f"high_precision_{prec}"):
                    count += 1


def eval_hp(e):
    table = {
        "pi": lambda: mp.pi, "e": lambda: mp.e, "phi": lambda: mp.phi, "sqrt(2)": lambda: mp.sqrt(2),
        "sqrt(3)": lambda: mp.sqrt(3), "ln(2)": lambda: mp.ln(2), "ln(10)": lambda: mp.ln(10),
        "exp(1/3)": lambda: mp.exp(mp.mpf(1) / 3), "sin(1)": lambda: mp.sin(1), "cos(1)": lambda: mp.cos(1),
        "tan(1)": lambda: mp.tan(1), "atan(1/7)": lambda: mp.atan(mp.mpf(1) / 7),
        "asin(1/3)": lambda: mp.asin(mp.mpf(1) / 3), "acos(1/3)": lambda: mp.acos(mp.mpf(1) / 3),
        "cbrt(2)": lambda: mp.cbrt(2), "2^(1/7)": lambda: mp.root(2, 7), "gamma(1/3)": lambda: mp.gamma(mp.mpf(1) / 3),
        "gamma(0.5)": lambda: mp.sqrt(mp.pi), "sinh(1)": lambda: mp.sinh(1),
        "atanh(1/2)": lambda: mp.atanh(mp.mpf(1) / 2), "log(7)": lambda: mp.log10(7),
        "log2(3)": lambda: mp.log(3, 2), "e^pi": lambda: mp.exp(mp.pi), "pi^e": lambda: mp.pi ** mp.e,
        "exp(100)": lambda: mp.exp(100), "ln(1E-50)": lambda: mp.ln(mp.mpf(10) ** -50), "1/7": lambda: mp.mpf(1) / 7,
        "sqrt(1E-100+1)": lambda: mp.sqrt(mp.mpf(10) ** -100 + 1),
    }
    return table[e]()


def gen_edge():
    """Hand-picked numerically delicate inputs (all expected to pass)."""
    D = mp.pi / 180
    cases = [
        ("tan(1.5707963267948966)", mp.tan(mp.mpf("1.5707963267948966")), "rad"),
        ("tan(1.57079632679)", mp.tan(mp.mpf("1.57079632679")), "rad"),
        ("sin(3.14159265358979)", mp.sin(mp.mpf("3.14159265358979")), "rad"),
        ("sin(6.28318530717959)", mp.sin(mp.mpf("6.28318530717959")), "rad"),
        ("cos(1.5707963267949)", mp.cos(mp.mpf("1.5707963267949")), "rad"),
        ("tan(3.1415926535898)", mp.tan(mp.mpf("3.1415926535898")), "rad"),
        ("sin(1E-20)", mp.sin(mp.mpf("1e-20")), "rad"),
        ("sin(1E-10)", mp.sin(mp.mpf("1e-10") * D), "deg"),
        ("asin(0.9999999999)", mp.asin(mp.mpf("0.9999999999")), "rad"),
        ("acos(0.99999999999999)", mp.acos(mp.mpf("0.99999999999999")), "rad"),
        ("acos(-0.99999999999999)", mp.acos(mp.mpf("-0.99999999999999")), "rad"),
        ("atanh(0.99999999999)", mp.atanh(mp.mpf("0.99999999999")), "rad"),
        ("asin(1E-15)", mp.asin(mp.mpf("1e-15")) / D, "deg"),
        ("atan(1E300)", mp.atan(mp.mpf("1e300")), "rad"),
        ("atan(-1E-300)", mp.atan(mp.mpf("-1e-300")), "rad"),
        ("gamma(-4.999)", mp.gamma(mp.mpf("-4.999")), "rad"),
        ("gamma(-170.5)", mp.gamma(mp.mpf("-170.5")), "rad"),
        ("gamma(1E-20)", mp.gamma(mp.mpf("1e-20")), "rad"),
        ("(-2)^(1/3)", -mp.cbrt(2), "rad"),
        ("(-2)^(2/5)", mp.root(4, 5), "rad"),
        ("exp(1E-20)", mp.exp(mp.mpf("1e-20")), "rad"),
        ("ln(1E-300)", mp.ln(mp.mpf("1e-300")), "rad"),
        ("sqrt(1E-300)", mp.sqrt(mp.mpf("1e-300")), "rad"),
        ("sqrt(2E301)", mp.sqrt(mp.mpf("2e301")), "rad"),
        ("2^1000.5", mp.power(2, mp.mpf("1000.5")), "rad"),
        ("0.5^3000", mp.power(mp.mpf("0.5"), 3000), "rad"),
        ("poissonpdf(1000,1000)", mp.exp(-1000) * mp.power(1000, 1000) / mp.factorial(1000), "rad"),
        ("binompdf(1000,0.5,500)", mp.binomial(1000, 500) / mp.power(2, 1000), "rad"),
        ("normcdf(-30)", mp.ncdf(-30), "rad"),
        ("invnorm(1E-300)", probit_hp("1e-300"), "rad"),
        ("sum(1/k,k,1,1000)", mp.harmonic(1000), "rad"),
        ("integral(sin(x)^2,x,0,100)", mp.quad(lambda x: mp.sin(x) ** 2, mp.linspace(0, 100, 40)), "rad"),
        ("integral(exp(-x),x,0,50)", 1 - mp.exp(-50), "rad"),
        ("integral(1/x,x,0.001,1000)", mp.ln(10 ** 6), "rad"),
        ("integral(sqrt(x)*ln(x),x,0,1)", mp.mpf(-4) / 9, "rad"),
        ("integral(abs(x),x,-1,2)", mp.mpf(5) / 2, "rad"),
        ("integral(sin(50x),x,0,10)", (1 - mp.cos(500)) / 50, "rad"),
        ("integral(1/(1+x^2),x,-inf,inf)", mp.pi, "rad"),
        ("integral(exp(-x^2),x,-inf,inf)", mp.sqrt(mp.pi), "rad"),
        ("integral(floor(x),x,0,3.5)", mp.mpf("4.5"), "rad"),
        ("deriv(sin(x),x,1,4)", mp.sin(1), "rad"),
        ("deriv(exp(x),x,1,5)", mp.e, "rad"),
        ("lim(sin(x)/x,x,inf)", 0, "rad"),
        ("lim((1+x)^(1/x),x,0)", mp.e, "rad"),
        ("lim((x-sin(x))/x^3,x,0)", mp.mpf(1) / 6, "rad"),
        ("lim((tan(x)-sin(x))/x^3,x,0)", mp.mpf(1) / 2, "rad"),
        ("lim(sqrt(x^2+x)-x,x,inf)", mp.mpf(1) / 2, "rad"),
        ("lim(x*ln(1+1/x),x,inf)", 1, "rad"),
        ("lim((x+1)/(2x+3),x,inf)", mp.mpf(1) / 2, "rad"),
        ("lim(x*(exp(1/x)-1),x,inf)", 1, "rad"),
        ("lim(x*(atan(x)-pi/2),x,inf)", -1, "rad"),
        ("lim(sqrt(x)*(sqrt(x+1)-sqrt(x)),x,inf)", mp.mpf(1) / 2, "rad"),
        ("lim((1+2/x)^x,x,inf)", mp.exp(2), "rad"),
    ]
    for e, v, mode in cases:
        cat = "integral" if e.startswith("integral") else "limit" if e.startswith("lim") else "edge"
        loose = cat in ("integral", "limit") or "norm" in e or "poisson" in e or e.startswith("deriv")
        real(e, v, angle=mode, cat=cat, rel=1e-9 if loose else 1e-13,
             abs_tol=1e-12 if cat != "edge" else (0 if not e.startswith("deriv") else 1e-11))
    cplx("(1+i)^100", mp.power(1 + 1j, 100), cat="complex_pow")
    cplx("exp(700+i)", mp.exp(mp.mpc(700, 1)), cat="complex_fn")
    cplx("sin(100i)", mp.sin(mp.mpc(0, 100)), cat="complex_fn")
    cplx("ln(1+1E-10i)", mp.ln(mp.mpc(1, mp.mpf("1e-10"))), cat="complex_fn", abs_tol=1e-30,
         known="minor: Re(ln z)=ln|z| is computed as 0.5*ln(1+1e-20) at working precision, giving exact 0 "
               "instead of 5E-21 (no log1p-style evaluation)")
    exact("det([[2,1,0,0,0,0],[1,2,1,0,0,0],[0,1,2,1,0,0],[0,0,1,2,1,0],[0,0,0,1,2,1],[0,0,0,0,1,2]])", 7,
          cat="matrix")
    exact("stdev(1E9+1,1E9+2,1E9+3)", 1, cat="statistics")
    exact("var(1E15+0.1,1E15+0.2)", Fraction(1, 200), cat="statistics")


def probit_hp(p):
    with mp.workdps(400):
        v = -mp.sqrt(2) * mp.erfinv(1 - 2 * mp.mpf(p))
    return +v


def gen_known_issues():
    """Confirmed engine discrepancies (skipped unless ACCURACY_KNOWN=1)."""
    # (1) DEG/GRAD: the angle is converted to radians as a wp-digit decimal before
    # reduction, so results near zeros of sin/cos/tan lose relative accuracy.
    note = ("deg/grad trig converts x*pi/180 to a (precision+6)-digit radian value before argument "
            "reduction; results near a zero of sin/cos/tan lose relative accuracy")
    D, G = mp.pi / 180, mp.pi / 200
    for fn, f in (("sin", mp.sin), ("cos", mp.cos), ("tan", mp.tan)):
        bases = (180, 360, -180, 540) if fn != "cos" else (90, 270, -90, 450)
        for base in bases:
            for d in ("0.000000001", "0.0000000001", "0.00000000001"):
                x = mp.mpf(base) + mp.mpf(d)
                real(f"{fn}({base}+{d})", f(x * D), angle="deg", cat="trig_near_zero", abs_tol=0, known=note)
    for base in (200, 400):
        x = mp.mpf(base) + mp.mpf("0.0000000001")
        real(f"sin({base}+0.0000000001)", mp.sin(x * G), angle="grad", cat="trig_near_zero", abs_tol=0,
             known=note)
    # passing counterparts in RAD mode (the reduction there is exact)
    for e in ("sin(3.14159265358979)", "sin(-3.1415926535898)", "cos(1.57079632679490)", "tan(6.2831853071796)",
              "sin(9.42477796076938)"):
        x = mp.mpf(e[e.index("(") + 1:-1])
        f = {"sin": mp.sin, "cos": mp.cos, "tan": mp.tan}[e[:3]]
        real(e, f(x), angle="rad", cat="trig_near_zero", abs_tol=0)
    # (2) limits at infinity of 0*inf forms whose leading terms cancel return exact 0
    note_lim = ("lim at inf returns exact 0 for a 0*inf form whose leading terms cancel "
                "(true limit is finite and non-zero)")
    for e, v in (("lim(x*(sqrt(x^2+1)-x),x,inf)", mp.mpf(1) / 2), ("lim(x*(sqrt(x^2+4)-x),x,inf)", 2),
                 ("lim(x^2*(1-cos(1/x)),x,inf)", mp.mpf(1) / 2), ("lim(x^2*(exp(1/x^2)-1),x,inf)", 1)):
        real(e, v, cat="limit", rel=1e-9, abs_tol=1e-10, known=note_lim)
    # (3) RAD: arguments ~1e17 whose residue mod pi/2 is < |x|*1e-18 snap to 0/+-1
    note_snap = ("sinCos() snaps residues r < |x|*10^-(precision+3) to an exact multiple of pi/2; for |x|~1e17 "
                 "that is a residue up to 0.1 rad (absolute error up to 0.1)")
    for x in (54108510191576730, 35381580413678162):
        real(f"sin({x})", mp.sin(x), cat="trig_large", abs_tol=1e-14, known=note_snap)
        real(f"cos({x})", mp.cos(x), cat="trig_large", abs_tol=1e-14, known=note_snap)


def gen_calculus_singular():
    """Singular / discontinuous inputs for integral, deriv and lim."""
    # correct behaviour (passes)
    for e, code in (("integral(1/x,x,-1,1)", "noConvergence"), ("integral(1/x^2,x,-1,1)", "noConvergence"),
                    ("integral(1/x,x,1,inf)", "noConvergence"), ("integral(1/(x-0.5),x,0,1)", "noConvergence"),
                    ("integral(1/(x-1)^2,x,0,2)", "noConvergence"), ("integral(cot(x),x,-1,1)", "noConvergence"),
                    ("lim(sin(1/x),x,0)", "noConvergence"), ("lim(cos(1/x),x,0)", "noConvergence"),
                    ("lim(sin(x),x,inf)", "noConvergence"), ("lim(x*cos(x),x,inf)", "noConvergence"),
                    ("lim(abs(x)/x,x,0)", "undefinedResult"), ("lim(floor(x),x,1)", "undefinedResult"),
                    ("lim(1/(x-1),x,1)", "undefinedResult"), ("lim(1/x,x,0)", "undefinedResult"),
                    ("deriv(abs(x),x,0)", "undefinedResult"), ("deriv(abs(x-1),x,1)", "undefinedResult"),
                    ("deriv(1/x,x,0)", "undefinedResult"), ("deriv(sqrt(x),x,0)", "undefinedResult")):
        err(e, code, cat="calculus_singular")
    for e, v in (("integral(1/sqrt(abs(x)),x,0,1)", 2), ("integral(1/sqrt(abs(x)),x,-1,0)", 2),
                 ("integral(ln(x),x,0,1)", -1), ("integral(1/x^2,x,1,inf)", 1),
                 ("integral(exp(-x)*x^10,x,0,inf)", 3628800),
                 ("integral(tan(x),x,0,1.5)", -mp.ln(mp.cos(mp.mpf("1.5")))),
                 ("deriv(floor(x),x,1.5)", 0), ("lim((2^x-1)/x,x,0)", mp.ln(2)), ("lim(x^(1/x),x,inf)", 1),
                 ("lim((1-1/x)^x,x,inf)", mp.exp(-1)), ("lim(exp(-1/x^2)/x^10,x,0)", 0)):
        real(e, v, cat="calculus_singular", rel=1e-9, abs_tol=1e-12)
    # known issues: divergent integrals through a non-integrable pole return a finite number
    note_div = ("integral across a non-integrable pole returns a finite (low-sig) number instead of "
                "noConvergence (1/(x-1)^2 over the same kind of interval is correctly rejected)")
    for e in ("integral(tan(x),x,0,2)", "integral(tan(x),x,1,2)", "integral(1/cos(x),x,0,2)",
              "integral(sec(x)^2,x,0,2)"):
        err(e, "noConvergence", cat="calculus_singular", known=note_div)
    # known issues: integrable interior singularities are rejected
    note_int = "integrable singularity strictly inside the interval gives noConvergence (endpoint case works)"
    for e, v in (("integral(1/sqrt(abs(x)),x,-1,1)", 4), ("integral(abs(x)^(-0.5),x,-1,1)", 4),
                 ("integral(1/sqrt(abs(x-0.3)),x,0,1)", 2 * (mp.sqrt(mp.mpf("0.3")) + mp.sqrt(mp.mpf("0.7")))),
                 ("integral(ln(abs(x)),x,-1,1)", -2)):
        real(e, v, cat="calculus_singular", rel=1e-9, abs_tol=1e-12, known=note_int)
    # known issues: derivative at a jump discontinuity returns a huge finite difference quotient
    note_jump = ("deriv at a jump discontinuity returns a huge finite number (~1e13) instead of undefinedResult "
                 "(abs(x) at 0 is correctly rejected)")
    for e in ("deriv(floor(x),x,1)", "deriv(sign(x),x,0)", "deriv(round(x),x,0.5)", "deriv(ceil(x),x,2)",
              "deriv(floor(x),x,-3)"):
        err(e, "undefinedResult", cat="calculus_singular", known=note_jump)
    # known issues: limits
    err("lim(tan(x),x,pi/2)", "undefinedResult", cat="calculus_singular",
        known="two-sided limit at a pole with opposite one-sided infinities returns a huge exact rational "
              "(83983280715065120629642/111 ~ 7.57E20)")
    note_osc = ("unbounded oscillation reported as +infinity; lim(x*cos(x),x,inf) correctly gives noConvergence")
    for e in ("lim(x*sin(x),x,inf)", "lim(x*sin(x),x,-inf)", "lim(x^2*sin(x),x,inf)"):
        err(e, "noConvergence", cat="calculus_singular", known=note_osc)


def gen_errors():
    E = [
        ("1/0", "divisionByZero", "rad"), ("5/(3-3)", "divisionByZero", "rad"), ("0/0", "divisionByZero", "rad"),
        ("0^(-1)", "divisionByZero", "rad"), ("0^(-2)", "divisionByZero", "rad"),
        ("mod(5,0)", "divisionByZero", "rad"), ("rem(5,0)", "divisionByZero", "rad"),
        ("log(0)", "domainError", "rad"), ("ln(0)", "domainError", "rad"), ("log2(0)", "domainError", "rad"),
        ("log(1,5)", "domainError", "rad"),
        ("sqrt(-4)", "complexResult", "rad"), ("sqrt(-4)", "complexResult", "deg"), ("ln(-1)", "complexResult", "rad"),
        ("log(-5)", "complexResult", "rad"), ("(-8)^0.5", "complexResult", "rad"), ("nroot(4,-16)", "complexResult", "rad"),
        ("asin(2)", "complexResult", "deg"), ("asin(-1.0001)", "complexResult", "rad"),
        ("acos(-1.5)", "complexResult", "grad"), ("acosh(0.5)", "complexResult", "rad"),
        ("atanh(2)", "complexResult", "rad"),
        ("atanh(1)", "domainError", "rad"), ("atanh(-1)", "domainError", "rad"),
        ("tan(90)", "undefinedResult", "deg"), ("tan(270)", "undefinedResult", "deg"), ("tan(-90)", "undefinedResult", "deg"),
        ("tan(450)", "undefinedResult", "deg"), ("sec(90)", "undefinedResult", "deg"), ("cot(0)", "undefinedResult", "deg"),
        ("csc(180)", "undefinedResult", "deg"), ("csc(0)", "undefinedResult", "rad"), ("cot(0)", "undefinedResult", "rad"),
        ("tan(100)", "undefinedResult", "grad"), ("tan(300)", "undefinedResult", "grad"), ("sec(100)", "undefinedResult", "grad"),
        ("atan2(0,0)", "undefinedResult", "rad"),
        ("(-1)!", "domainError", "rad"), ("(-3)!", "domainError", "rad"), ("gamma(0)", "domainError", "rad"),
        ("gamma(-3)", "domainError", "rad"),
        ("factorial(300000)", "overflow", "rad"), ("exp(1E7)", "overflow", "rad"), ("10^(10^7)", "overflow", "rad"),
        ("nCr(-5,2)", "domainError", "rad"), ("gcd(1.5,3)", "nonIntegerArgument", "rad"),
        ("inv([[1,2],[2,4]])", "singularMatrix", "rad"), ("det([[1,2,3],[4,5,6]])", "notSquare", "rad"),
        ("2+", "missingArgument", "rad"), ("2+3)", "mismatchedParentheses", "rad"),
        ("invnorm(0)", "domainError", "rad"), ("invnorm(1)", "domainError", "rad"), ("invnorm(1.5)", "domainError", "rad"),
        ("normcdf(1,0,-1)", "domainError", "rad"), ("binompdf(10,1.5,3)", "domainError", "rad"),
    ]
    for e, code, mode in E:
        err(e, code, angle=mode, cat="error")
    # generated: division by zero-valued subexpressions, tan at odd multiples of 90 deg
    for _ in range(20):
        a = R.randint(1, 99)
        b = R.randint(1, 50)
        err(f"{a}/({b}-{b})", "divisionByZero", cat="error")
    for k in range(-6, 7):
        err(f"tan({90 + 180 * k})", "undefinedResult", angle="deg", cat="error")
        err(f"tan({100 + 200 * k})", "undefinedResult", angle="grad", cat="error")
    for _ in range(10):
        x = rand_dec(1.001, 100, 3)
        err(f"asin({lit(x)})", "complexResult", angle=R.choice(["deg", "rad", "grad"]), cat="error")
        err(f"sqrt(-{lit(x)})", "complexResult", cat="error")
        err(f"ln(-{lit(x)})", "complexResult", cat="error")


def main():
    gen_arith()
    gen_powers_roots()
    gen_exp_log()
    gen_trig()
    gen_hyperbolic()
    gen_gamma()
    gen_number_theory()
    gen_complex()
    gen_statistics()
    gen_probability()
    gen_integrals()
    gen_derivatives()
    gen_sums()
    gen_limits()
    gen_matrices()
    gen_high_precision()
    gen_edge()
    gen_known_issues()
    gen_calculus_singular()
    gen_errors()
    # de-duplicate (same expr+mode+precision)
    seen, out = set(), []
    for c in CASES:
        key = (c["expr"], c["angle"], c["precision"], c.get("complex", False))
        if key in seen:
            continue
        seen.add(key)
        out.append(c)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=0)
        fh.write("\n")
    by = {}
    for c in out:
        by[c["cat"]] = by.get(c["cat"], 0) + 1
    for k in sorted(by):
        print(f"{k:28s} {by[k]}")
    print("total", len(out), "known issues", sum(1 for c in out if c.get("known_issue")))


if __name__ == "__main__":
    main()
