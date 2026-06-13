import '../../domain/entities/tool_step.dart';

class ToolStepModel extends ToolStep {
  const ToolStepModel({
    required super.step,
    required super.tool,
    required super.args,
    required super.observation,
    required super.success,
  });

  factory ToolStepModel.fromJson(Map<String, dynamic> json) {
    return ToolStepModel(
      step: (json['step'] as num?)?.toInt() ?? 0,
      tool: json['tool'] as String? ?? 'unknown',
      args: (json['args'] as Map?)?.cast<String, dynamic>() ?? const {},
      observation: json['observation'] as String? ?? '',
      success: json['success'] as bool? ?? false,
    );
  }
}
