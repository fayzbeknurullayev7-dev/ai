class ApiConstants {
  static const baseUrl = 'https://dd9447fb48d9ef7e-84-54-70-106.serveousercontent.com/api/v1'; // Serveo tunnel
  // static const baseUrl = 'http://localhost:8000/api/v1'; // iOS/Web

  static const chatEndpoint = '/chat/';
  static const chatStreamEndpoint = '/chat/stream';
  static const agentRunEndpoint = '/agent/run';
  static const agentStreamEndpoint = '/agent/stream';
  // Auth
  static const registerEndpoint = '/auth/register';
  static const loginEndpoint = '/auth/login';
  static const meEndpoint = '/auth/me';
  static const connectTimeout = Duration(seconds: 30);
  static const receiveTimeout = Duration(seconds: 60);
}
