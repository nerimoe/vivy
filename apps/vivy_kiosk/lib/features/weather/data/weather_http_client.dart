import 'package:http/http.dart' as http;

import 'weather_http_client_stub.dart'
    if (dart.library.io) 'weather_http_client_io.dart';

Future<http.Client> createWeatherHttpClient() =>
    createPlatformWeatherHttpClient();
