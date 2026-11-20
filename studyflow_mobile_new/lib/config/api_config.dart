class ApiConfig {
  ApiConfig._();

  // Android Emulator -> Windows host machine
  static const String baseUrl =
      'http://10.0.2.2:8080';

  // Authentication SOAP endpoint
  static const String authenticationEndpoint =
      '$baseUrl/AuthenticationService/AuthenticationService';
}