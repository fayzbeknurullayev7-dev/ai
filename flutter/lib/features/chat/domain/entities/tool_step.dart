/// Planner Agent ReAct siklidagi bitta tool chaqiruvi izi.
class ToolStep {
  final int step;
  final String tool;
  final Map<String, dynamic> args;
  final String observation;
  final bool success;

  const ToolStep({
    required this.step,
    required this.tool,
    required this.args,
    required this.observation,
    required this.success,
  });
}
