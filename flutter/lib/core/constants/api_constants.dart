class ApiConstants {
  static const baseUrl = 'http://192.168.1.5:8000/api/v1'; // Android emulator
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
