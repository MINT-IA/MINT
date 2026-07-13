/// One normalized variable rendered by a sensitivity chart.
///
/// The DTO is calculation-engine agnostic: live arbitrage parsers can expose
/// chart data without depending on a dormant retirement projection service.
class TornadoVariable {
  final String label;
  final String category;
  final double baseValue;
  final double lowValue;
  final double highValue;
  final double swing;
  final String lowLabel;
  final String highLabel;

  const TornadoVariable({
    required this.label,
    required this.category,
    required this.baseValue,
    required this.lowValue,
    required this.highValue,
    required this.swing,
    required this.lowLabel,
    required this.highLabel,
  });
}
