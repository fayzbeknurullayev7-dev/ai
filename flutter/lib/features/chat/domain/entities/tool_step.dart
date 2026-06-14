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

  Map<String, dynamic> toJson() => {
        'step': step,
        'tool': tool,
        'args': args,
        'observation': observation,
        'success': success,
      };

  factory ToolStep.fromJson(Map<String, dynamic> json) {
    return ToolStep(
      step: (json['step'] as num?)?.toInt() ?? 0,
      tool: json['tool'] as String? ?? 'unknown',
      args: (json['args'] as Map?)?.cast<String, dynamic>() ?? const {},
      observation: json['observation'] as String? ?? '',
      success: json['success'] as bool? ?? false,
    );
  }
}
