import 'package:http/http.dart' as http;

Future<http.Client> createPlatformWeatherHttpClient() async => http.Client();
