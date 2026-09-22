/// Route paths used throughout the app.
abstract final class Routes {
  // Primary sections (bottom navigation / rail).
  static const calculator = '/calc';
  static const scientific = '/scientific';
  static const graph = '/graph';
  static const solve = '/solve';
  static const tools = '/tools';
  static const history = '/history';

  // Solve
  static const equation = '/equation';
  static const polynomial = '/polynomial';
  static const system = '/system';
  static const cas = '/cas';

  // Tools
  static const matrix = '/matrix';
  static const vector = '/vector';
  static const complex = '/complex';
  static const derivative = '/derivative';
  static const integral = '/integral';
  static const limit = '/limit';
  static const series = '/series';
  static const statistics = '/statistics';
  static const probability = '/probability';
  static const numberTheory = '/number-theory';
  static const converter = '/converter';
  static const constants = '/constants';
  static const formulas = '/formulas';
  static String formula(String id) => '/formulas/${Uri.encodeComponent(id)}';
  static const programmer = '/programmer';
  static const table = '/table';
  static const random = '/random';

  // Graph
  static const graphFunctions = '/graph-functions';

  // User data & app
  static const variables = '/variables';
  static const functions = '/functions';
  static const favorites = '/favorites';
  static const search = '/search';
  static const settings = '/settings';
  static const settingsCalculator = '/settings/calculator';
  static const settingsAppearance = '/settings/appearance';
  static const settingsGraph = '/settings/graph';
  static const backup = '/settings/backup';
  static const privacy = '/settings/privacy';
  static const about = '/settings/about';
  static const premium = '/premium';
  static const onboarding = '/onboarding';
}
