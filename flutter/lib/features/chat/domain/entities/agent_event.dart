import 'tool_step.dart';

/// Backend SSE oqimidagi tipizatsiyalangan eventlar.
/// Protokol: start | token | image | step | done | error
sealed class AgentEvent {
  const AgentEvent();
}

class StartEvent extends AgentEvent {
  final String agent;
  final String? model;
  const StartEvent({required this.agent, this.model});
}

class TokenEvent extends AgentEvent {
  final String content;
  const TokenEvent(this.content);
}

/// AI yaratgan rasm (base64) — ixtiyoriy izoh (caption) bilan.
class ImageEvent extends AgentEvent {
  final String base64;
  final String? caption;
  const ImageEvent(this.base64, {this.caption});
}

class StepEvent extends AgentEvent {
  final ToolStep step;
  const StepEvent(this.step);
}

class DoneEvent extends AgentEvent {
  const DoneEvent();
}

class ErrorEvent extends AgentEvent {
  final String detail;
  const ErrorEvent(this.detail);
}
