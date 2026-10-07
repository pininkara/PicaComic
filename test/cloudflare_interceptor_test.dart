import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/network/cloudflare.dart';

class _ResponseAdapter implements HttpClientAdapter {
  final int status;
  final bool challenge;
  _ResponseAdapter(this.status, {this.challenge = false});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString('<html></html>', status, headers: {
        if (challenge) 'cf-mitigated': ['challenge'],
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final status in [200, 403, 503]) {
    test('challenge header is detected even for HTTP $status', () async {
      final dio = Dio(BaseOptions(responseType: ResponseType.plain))
        ..httpClientAdapter = _ResponseAdapter(status, challenge: true)
        ..interceptors.add(CloudflareInterceptor());
      addTearDown(dio.close);
      await expectLater(dio.get('https://nhentai.net/g/123/'),
          throwsA(isA<CloudflareException>()));
    });
  }

  for (final status in [403, 429]) {
    test('ordinary HTTP $status is preserved without verification', () async {
      final dio = Dio(BaseOptions(responseType: ResponseType.plain))
        ..httpClientAdapter = _ResponseAdapter(status)
        ..interceptors.add(CloudflareInterceptor());
      addTearDown(dio.close);
      await expectLater(dio.get('https://nhentai.net/g/123/'),
          throwsA(isA<DioException>().having(
              (error) => error.response?.statusCode, 'status', status)));
    });
  }
}
