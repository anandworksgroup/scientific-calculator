/// Built-in mathematical and physical constants (CODATA 2018 values).
///
/// Constants are referenced in expressions as `@id` (e.g. `@c`, `@hbar`).
/// SI-defining constants are exact; measured ones use their recommended
/// value, which the engine then treats as an exact decimal.
library;

import '../numbers/num.dart';

enum ConstantCategory { mathematical, universal, electromagnetic, atomic, physicoChemical, astronomical, adopted }

class PhysicalConstant {
  const PhysicalConstant({
    required this.id,
    required this.name,
    required this.symbol,
    required this.latex,
    required this.value,
    required this.unit,
    required this.category,
    required this.description,
    this.exact = false,
    this.uncertainty,
    this.compute,
  });

  /// Identifier used after `@` in expressions.
  final String id;
  final String name;

  /// Plain-text symbol, e.g. `ħ`.
  final String symbol;
  final String latex;

  /// Decimal value (for display and as the stored value).
  final String value;
  final String unit;
  final ConstantCategory category;
  final String description;

  /// True when the value is exact by definition of the SI.
  final bool exact;

  /// Standard uncertainty as published (for measured constants).
  final String? uncertainty;

  /// Derived constants computed to full working precision.
  final Num Function(Arith a)? compute;

  Num numericValue(Arith a) => compute?.call(a) ?? a.normalize(Rat.parseDecimal(value));
}

Num _hbar(Arith a) => a.div(Rat.parseDecimal('6.62607015E-34'), a.mul(Rat.two, a.pi()));

Num _stefan(Arith a) {
  final k = Rat.parseDecimal('1.380649E-23');
  final h = Rat.parseDecimal('6.62607015E-34');
  final c = Rat.int(299792458);
  final pi5 = a.pow(a.pi(), Rat.int(5));
  return a.div(a.mul(Rat.two, a.mul(pi5, k.powInt(4))), Rat.int(15) * h.powInt(3) * c.powInt(2));
}

Num _phi(Arith a) => a.div(a.add(Rat.one, a.sqrt(Rat.int(5))), Rat.two);

const List<PhysicalConstant> physicalConstants = [
  // ------------------------------------------------------------ mathematical
  PhysicalConstant(
    id: 'pi', name: 'Pi', symbol: 'π', latex: r'\pi', value: '3.14159265358979323846',
    unit: '', category: ConstantCategory.mathematical, exact: true,
    description: 'Ratio of a circle\'s circumference to its diameter.',
    compute: _piC,
  ),
  PhysicalConstant(
    id: 'e', name: "Euler's number", symbol: 'e', latex: r'e', value: '2.71828182845904523536',
    unit: '', category: ConstantCategory.mathematical, exact: true,
    description: 'Base of the natural logarithm.',
    compute: _eC,
  ),
  PhysicalConstant(
    id: 'phi', name: 'Golden ratio', symbol: 'φ', latex: r'\varphi', value: '1.61803398874989484820',
    unit: '', category: ConstantCategory.mathematical, exact: true,
    description: '(1 + √5) / 2, the ratio a/b when (a+b)/a = a/b.',
    compute: _phi,
  ),
  PhysicalConstant(
    id: 'gamma', name: 'Euler–Mascheroni constant', symbol: 'γ', latex: r'\gamma',
    value: '0.5772156649015328606065120900824024310421593359399235988057672348848677267776646709369470632917467495146314472498071',
    unit: '', category: ConstantCategory.mathematical, exact: true,
    description: 'Limiting difference between the harmonic series and the natural logarithm.',
  ),
  PhysicalConstant(
    id: 'catalan', name: "Catalan's constant", symbol: 'G', latex: r'G',
    value: '0.9159655941772190150546035149323841107741493742816721342664981196217630197762547694793565129261151062485744226191962',
    unit: '', category: ConstantCategory.mathematical, exact: true,
    description: 'Sum of (−1)ⁿ/(2n+1)² over n ≥ 0.',
  ),
  PhysicalConstant(
    id: 'zeta3', name: "Apéry's constant", symbol: 'ζ(3)', latex: r'\zeta(3)',
    value: '1.202056903159594285399738161511449990764986292340498881792271555341838205786313090186455873609335258146199157795261',
    unit: '', category: ConstantCategory.mathematical, exact: true,
    description: 'Sum of 1/n³ over n ≥ 1.',
  ),
  // --------------------------------------------------------------- universal
  PhysicalConstant(
    id: 'c', name: 'Speed of light in vacuum', symbol: 'c', latex: r'c', value: '299792458',
    unit: 'm/s', category: ConstantCategory.universal, exact: true,
    description: 'Speed of electromagnetic waves in vacuum; defines the metre.',
  ),
  PhysicalConstant(
    id: 'h', name: 'Planck constant', symbol: 'h', latex: r'h', value: '6.62607015E-34',
    unit: 'J·s', category: ConstantCategory.universal, exact: true,
    description: 'Quantum of action; relates photon energy to frequency (E = hf).',
  ),
  PhysicalConstant(
    id: 'hbar', name: 'Reduced Planck constant', symbol: 'ħ', latex: r'\hbar', value: '1.054571817646156391262E-34',
    unit: 'J·s', category: ConstantCategory.universal, exact: true,
    description: 'h / 2π.',
    compute: _hbar,
  ),
  PhysicalConstant(
    id: 'G', name: 'Newtonian constant of gravitation', symbol: 'G', latex: r'G', value: '6.67430E-11',
    unit: 'm³/(kg·s²)', category: ConstantCategory.universal, uncertainty: '0.00015E-11',
    description: 'Strength of gravity in Newton\'s law F = Gm₁m₂/r².',
  ),
  PhysicalConstant(
    id: 'mu0', name: 'Vacuum magnetic permeability', symbol: 'μ₀', latex: r'\mu_0', value: '1.25663706212E-6',
    unit: 'N/A²', category: ConstantCategory.universal, uncertainty: '0.00000000019E-6',
    description: 'Magnetic constant; permeability of free space.',
  ),
  PhysicalConstant(
    id: 'eps0', name: 'Vacuum electric permittivity', symbol: 'ε₀', latex: r'\varepsilon_0', value: '8.8541878128E-12',
    unit: 'F/m', category: ConstantCategory.universal, uncertainty: '0.0000000013E-12',
    description: 'Electric constant; permittivity of free space.',
  ),
  PhysicalConstant(
    id: 'Z0', name: 'Characteristic impedance of vacuum', symbol: 'Z₀', latex: r'Z_0', value: '376.730313668',
    unit: 'Ω', category: ConstantCategory.universal, uncertainty: '0.000000057',
    description: 'μ₀c, the impedance of free space.',
  ),
  // --------------------------------------------------------- electromagnetic
  PhysicalConstant(
    id: 'qe', name: 'Elementary charge', symbol: 'e', latex: r'e', value: '1.602176634E-19',
    unit: 'C', category: ConstantCategory.electromagnetic, exact: true,
    description: 'Electric charge of a proton; defines the coulomb.',
  ),
  PhysicalConstant(
    id: 'ke', name: 'Coulomb constant', symbol: 'kₑ', latex: r'k_e', value: '8.9875517923E9',
    unit: 'N·m²/C²', category: ConstantCategory.electromagnetic, uncertainty: '0.0000000014E9',
    description: '1 / (4πε₀), used in Coulomb\'s law.',
  ),
  PhysicalConstant(
    id: 'Phi0', name: 'Magnetic flux quantum', symbol: 'Φ₀', latex: r'\Phi_0', value: '2.067833848E-15',
    unit: 'Wb', category: ConstantCategory.electromagnetic, exact: true,
    description: 'h / 2e.',
  ),
  PhysicalConstant(
    id: 'G0', name: 'Conductance quantum', symbol: 'G₀', latex: r'G_0', value: '7.748091729E-5',
    unit: 'S', category: ConstantCategory.electromagnetic, exact: true,
    description: '2e² / h.',
  ),
  PhysicalConstant(
    id: 'muB', name: 'Bohr magneton', symbol: 'μB', latex: r'\mu_B', value: '9.2740100783E-24',
    unit: 'J/T', category: ConstantCategory.electromagnetic, uncertainty: '0.0000000028E-24',
    description: 'Natural unit of the electron magnetic moment, eħ/2mₑ.',
  ),
  PhysicalConstant(
    id: 'muN', name: 'Nuclear magneton', symbol: 'μN', latex: r'\mu_N', value: '5.0507837461E-27',
    unit: 'J/T', category: ConstantCategory.electromagnetic, uncertainty: '0.0000000015E-27',
    description: 'eħ/2mₚ.',
  ),
  // ------------------------------------------------------------ atomic
  PhysicalConstant(
    id: 'me', name: 'Electron mass', symbol: 'mₑ', latex: r'm_e', value: '9.1093837015E-31',
    unit: 'kg', category: ConstantCategory.atomic, uncertainty: '0.0000000028E-31',
    description: 'Rest mass of the electron.',
  ),
  PhysicalConstant(
    id: 'mp', name: 'Proton mass', symbol: 'mₚ', latex: r'm_p', value: '1.67262192369E-27',
    unit: 'kg', category: ConstantCategory.atomic, uncertainty: '0.00000000051E-27',
    description: 'Rest mass of the proton.',
  ),
  PhysicalConstant(
    id: 'mn', name: 'Neutron mass', symbol: 'mₙ', latex: r'm_n', value: '1.67492749804E-27',
    unit: 'kg', category: ConstantCategory.atomic, uncertainty: '0.00000000095E-27',
    description: 'Rest mass of the neutron.',
  ),
  PhysicalConstant(
    id: 'mmu', name: 'Muon mass', symbol: 'm_μ', latex: r'm_\mu', value: '1.883531627E-28',
    unit: 'kg', category: ConstantCategory.atomic, uncertainty: '0.000000042E-28',
    description: 'Rest mass of the muon.',
  ),
  PhysicalConstant(
    id: 'u', name: 'Atomic mass constant', symbol: 'u', latex: r'm_u', value: '1.66053906660E-27',
    unit: 'kg', category: ConstantCategory.atomic, uncertainty: '0.00000000050E-27',
    description: 'One twelfth of the mass of a carbon-12 atom (dalton).',
  ),
  PhysicalConstant(
    id: 'alpha', name: 'Fine-structure constant', symbol: 'α', latex: r'\alpha', value: '7.2973525693E-3',
    unit: '', category: ConstantCategory.atomic, uncertainty: '0.0000000011E-3',
    description: 'Dimensionless strength of the electromagnetic interaction (≈ 1/137).',
  ),
  PhysicalConstant(
    id: 'Rinf', name: 'Rydberg constant', symbol: 'R∞', latex: r'R_\infty', value: '10973731.568160',
    unit: '1/m', category: ConstantCategory.atomic, uncertainty: '0.000021',
    description: 'Limiting wavenumber of the hydrogen spectrum.',
  ),
  PhysicalConstant(
    id: 'a0', name: 'Bohr radius', symbol: 'a₀', latex: r'a_0', value: '5.29177210903E-11',
    unit: 'm', category: ConstantCategory.atomic, uncertainty: '0.00000000080E-11',
    description: 'Most probable electron–nucleus distance in hydrogen ground state.',
  ),
  PhysicalConstant(
    id: 're', name: 'Classical electron radius', symbol: 'rₑ', latex: r'r_e', value: '2.8179403262E-15',
    unit: 'm', category: ConstantCategory.atomic, uncertainty: '0.0000000013E-15',
    description: 'e² / (4πε₀mₑc²).',
  ),
  PhysicalConstant(
    id: 'lambdaC', name: 'Compton wavelength', symbol: 'λC', latex: r'\lambda_C', value: '2.42631023867E-12',
    unit: 'm', category: ConstantCategory.atomic, uncertainty: '0.00000000073E-12',
    description: 'h / (mₑc) for the electron.',
  ),
  // ---------------------------------------------------------- physico-chemical
  PhysicalConstant(
    id: 'NA', name: 'Avogadro constant', symbol: 'N_A', latex: r'N_A', value: '6.02214076E23',
    unit: '1/mol', category: ConstantCategory.physicoChemical, exact: true,
    description: 'Number of entities in one mole; defines the mole.',
  ),
  PhysicalConstant(
    id: 'kB', name: 'Boltzmann constant', symbol: 'k_B', latex: r'k_B', value: '1.380649E-23',
    unit: 'J/K', category: ConstantCategory.physicoChemical, exact: true,
    description: 'Relates temperature to energy; defines the kelvin.',
  ),
  PhysicalConstant(
    id: 'R', name: 'Molar gas constant', symbol: 'R', latex: r'R', value: '8.31446261815324',
    unit: 'J/(mol·K)', category: ConstantCategory.physicoChemical, exact: true,
    description: 'N_A·k_B; appears in the ideal gas law pV = nRT.',
  ),
  PhysicalConstant(
    id: 'F', name: 'Faraday constant', symbol: 'F', latex: r'F', value: '96485.33212331001',
    unit: 'C/mol', category: ConstantCategory.physicoChemical, exact: true,
    description: 'Charge of one mole of electrons, N_A·e.',
  ),
  PhysicalConstant(
    id: 'sigma', name: 'Stefan–Boltzmann constant', symbol: 'σ', latex: r'\sigma', value: '5.670374419184429453970E-8',
    unit: 'W/(m²·K⁴)', category: ConstantCategory.physicoChemical, exact: true,
    description: 'Total power radiated by a black body per area: σT⁴.',
    compute: _stefan,
  ),
  PhysicalConstant(
    id: 'b', name: 'Wien displacement constant', symbol: 'b', latex: r'b', value: '2.897771955E-3',
    unit: 'm·K', category: ConstantCategory.physicoChemical, exact: true,
    description: 'λ_max·T for black-body radiation.',
  ),
  PhysicalConstant(
    id: 'Vm', name: 'Molar volume of ideal gas (273.15 K, 101.325 kPa)', symbol: 'V_m', latex: r'V_m', value: '22.41396954E-3',
    unit: 'm³/mol', category: ConstantCategory.physicoChemical, exact: true,
    description: 'Volume of one mole of ideal gas at STP.',
  ),
  PhysicalConstant(
    id: 'eV', name: 'Electronvolt', symbol: 'eV', latex: r'\mathrm{eV}', value: '1.602176634E-19',
    unit: 'J', category: ConstantCategory.physicoChemical, exact: true,
    description: 'Energy gained by an electron across 1 volt.',
  ),
  // ------------------------------------------------------------ adopted
  PhysicalConstant(
    id: 'g0', name: 'Standard acceleration of gravity', symbol: 'g₀', latex: r'g_0', value: '9.80665',
    unit: 'm/s²', category: ConstantCategory.adopted, exact: true,
    description: 'Conventional value of free-fall acceleration at Earth\'s surface.',
  ),
  PhysicalConstant(
    id: 'atm', name: 'Standard atmosphere', symbol: 'atm', latex: r'\mathrm{atm}', value: '101325',
    unit: 'Pa', category: ConstantCategory.adopted, exact: true,
    description: 'Standard sea-level atmospheric pressure.',
  ),
  PhysicalConstant(
    id: 'T0', name: 'Zero Celsius', symbol: 'T₀', latex: r'T_0', value: '273.15',
    unit: 'K', category: ConstantCategory.adopted, exact: true,
    description: '0 °C expressed in kelvin.',
  ),
  // ----------------------------------------------------------- astronomical
  PhysicalConstant(
    id: 'au', name: 'Astronomical unit', symbol: 'au', latex: r'\mathrm{au}', value: '149597870700',
    unit: 'm', category: ConstantCategory.astronomical, exact: true,
    description: 'Conventional mean Earth–Sun distance.',
  ),
  PhysicalConstant(
    id: 'ly', name: 'Light-year', symbol: 'ly', latex: r'\mathrm{ly}', value: '9460730472580800',
    unit: 'm', category: ConstantCategory.astronomical, exact: true,
    description: 'Distance light travels in one Julian year.',
  ),
  PhysicalConstant(
    id: 'pc', name: 'Parsec', symbol: 'pc', latex: r'\mathrm{pc}', value: '3.0856775814913673E16',
    unit: 'm', category: ConstantCategory.astronomical,
    description: 'Distance at which 1 au subtends one arcsecond.',
  ),
  PhysicalConstant(
    id: 'Msun', name: 'Solar mass', symbol: 'M☉', latex: r'M_\odot', value: '1.98847E30',
    unit: 'kg', category: ConstantCategory.astronomical, uncertainty: '0.00007E30',
    description: 'Mass of the Sun.',
  ),
  PhysicalConstant(
    id: 'Mearth', name: 'Earth mass', symbol: 'M⊕', latex: r'M_\oplus', value: '5.9722E24',
    unit: 'kg', category: ConstantCategory.astronomical, uncertainty: '0.0006E24',
    description: 'Mass of the Earth.',
  ),
  PhysicalConstant(
    id: 'Rearth', name: 'Earth mean radius', symbol: 'R⊕', latex: r'R_\oplus', value: '6.3710E6',
    unit: 'm', category: ConstantCategory.astronomical,
    description: 'Mean radius of the Earth.',
  ),
];

Num _piC(Arith a) => a.pi();
Num _eC(Arith a) => a.e();

final Map<String, PhysicalConstant> constantIndex = {
  for (final c in physicalConstants) c.id: c,
};
