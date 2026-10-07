import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pica_comic/network/cloudflare.dart';
import 'package:pica_comic/network/cloudflare_session.dart';
import 'package:pica_comic/network/cookie_jar.dart';
import 'package:pica_comic/pages/webview.dart';

Future<void> clearNhentaiBrowserLogin(String url) async {
  final manager = CookieManager.instance();
  for (final name in ['sessionid', 'XSRF-TOKEN']) {
    await manager.deleteCookie(url: WebUri(url), name: name);
    await manager.deleteCookie(url: WebUri(url), name: name,
        domain: '.${Uri.parse(url).host}');
  }
}

/// Read through the same native browser and cookie store that the user verified.
/// Copying clearance to Dart's HTTP stack does not preserve browser identity.
Future<String> readNhentaiInBrowser(String url) async {
  final uri = Uri.parse(url);
  final result = Completer<String>();
  final options = RequestOptions(path: url);
  void fail(Object error) {
    if (!result.isCompleted) result.completeError(error);
  }

  final webview = HeadlessInAppWebView(
    initialUrlRequest: URLRequest(url: WebUri(url)),
    initialSettings: InAppWebViewSettings(blockNetworkImage: true),
    onReceivedHttpError: (controller, request, response) {
      if (request.isForMainFrame != true) return;
      final headers = Headers.fromMap((response.headers ?? {}).map(
          (key, value) => MapEntry(key, [value])));
      if (headers.value('cf-mitigated') == 'challenge') {
        fail(CloudflareException(url));
      } else {
        fail(DioException.badResponse(
          statusCode: response.statusCode ?? 500,
          requestOptions: options,
          response: Response(requestOptions: options,
              statusCode: response.statusCode, headers: headers),
        ));
      }
    },
    onReceivedError: (controller, request, error) {
      if (request.isForMainFrame == true) {
        fail(DioException(requestOptions: options, message: error.description));
      }
    },
    onLoadStop: (controller, loadedUrl) async {
      if (result.isCompleted) return;
      try {
        if (loadedUrl == null ||
            Uri.parse(loadedUrl.toString()).host != uri.host) {
          throw StateError('Unexpected nhentai redirect');
        }
        final ready = await controller.evaluateJavascript(
            source: cloudflarePageReadyScript);
        if (ready != true) throw CloudflareException(url);
        final data = await controller.evaluateJavascript(source: '''
          document.contentType.includes('json') ||
          document.contentType.includes('text/plain')
            ? document.body.innerText : document.documentElement.outerHTML
        ''');
        if (data is! String || data.isEmpty) {
          throw StateError('Empty nhentai response');
        }
        final cookies = await controller.getCookies(url) ?? {};
        final jar = SingleInstanceCookieJar.instance!;
        if (cookies['cf_clearance']?.isNotEmpty == true) {
          jar.deleteMatching(uri, 'cf_clearance');
        }
        // Android does not expose expiry/path metadata through getCookie().
        // The browser remains authoritative for clearance on subsequent reads.
        jar.saveFromResponseCookieHeader(uri, cookies.entries.map((entry) =>
            '${entry.key}=${entry.value}; Path=/; Secure').toList());
        browserSessionHosts.add(uri.host);
        if (!result.isCompleted) result.complete(data);
      } catch (error) {
        fail(error);
      }
    },
  );
  try {
    unawaited(webview.run().catchError((Object error) { fail(error); }));
    return await result.future.timeout(const Duration(seconds: 30));
  } finally {
    await webview.dispose();
  }
}
