import 'tool_step.dart';

/// Backend SSE oqimidagi tipizatsiyalangan eventlar.
/// Protokol: start | token | step | done | error
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
