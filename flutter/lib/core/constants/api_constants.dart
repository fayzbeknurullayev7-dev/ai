class ApiConstants {
  static const baseUrl = 'https://nexus-project-3gnp.onrender.com/api/v1';

  static const chatEndpoint = '/chat/';
  static const chatStreamEndpoint = '/chat/stream';
  static const agentRunEndpoint = '/agent/run';
  static const agentStreamEndpoint = '/agent/stream';
  static const registerEndpoint = '/auth/register';
  static const loginEndpoint = '/auth/login';
  static const meEndpoint = '/auth/me';
  static const connectTimeout = Duration(seconds: 120);
  static const receiveTimeout = Duration(seconds: 120);
}
