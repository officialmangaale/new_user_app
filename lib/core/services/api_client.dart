import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.example.com/v1',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  final Dio dio;
}
