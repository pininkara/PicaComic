import 'dart:async';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/cookie_jar.dart';
import 'package:pica_comic/pages/webview.dart';
import 'package:pica_comic/tools/translations.dart';
import 'cloudflare_session.dart';

import '../components/components.dart';

class CloudflareException implements DioException {
  final String url;

  const CloudflareException(this.url);

  @override
  String toString() {
    return "CloudflareException: $url";
  }

  static CloudflareException? fromString(String message) {
    var match = RegExp(r"CloudflareException: (.+)").firstMatch(message);
    if (match == null) return null;
    return CloudflareException(match.group(1)!);
  }

  @override
  DioException copyWith(
      {RequestOptions? requestOptions,
      Response<dynamic>? response,
      DioExceptionType? type,
      Object? error,
      StackTrace? stackTrace,
      String? message}) {
    return this;
  }

  @override
  Object? get error => this;

  @override
  String? get message => toString();

  @override
  RequestOptions get requestOptions => RequestOptions();

  @override
  Response? get response => null;

  @override
  StackTrace get stackTrace => StackTrace.empty;

  @override
  DioExceptionType get type => DioExceptionType.badResponse;
}

class CloudflareInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if(options.headers['cookie'].toString().contains('cf_clearance')) {
      options.headers['user-agent'] = appdata.implicitData[3];
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response != null) {
      handler.next(_check(err.response!) ?? err);
    } else {
      handler.next(err);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    var err = _check(response);
    if (err != null) {
      handler.reject(err);
      return;
    }
    handler.next(response);
  }

  CloudflareException? _check(Response response) {
    if (response.headers['cf-mitigated']?.firstOrNull == "challenge") {
      return CloudflareException(response.requestOptions.uri.toString());
    }
    return null;
  }
}

bool _verificationOpen = false;

Future<void> passCloudflare(
    CloudflareException e, void Function() onFinished) async {
  if (_verificationOpen) return;
  _verificationOpen = true;
  final uri = Uri.parse(e.url);
  final url = uri.path.startsWith('/api/')
      ? uri.replace(path: '/', query: '').toString()
      : e.url;
  final session = CloudflareSession();

  void saveSession(Map<String, String> cookies, String ua) {
    appdata.implicitData[3] = ua;
    appdata.writeImplicitData();
    // Replace rejected clearance at every matching domain/path. Otherwise a
    // stale host-only cookie can shadow the freshly imported domain cookie.
    final jar = SingleInstanceCookieJar.instance!;
    jar.deleteMatching(uri, 'cf_clearance');
    jar.saveFromResponse(uri, cookies.entries.map((entry) =>
        io.Cookie(entry.key, entry.value)
          ..domain = uri.host
          ..path = '/'
          ..secure = uri.scheme == 'https').toList());
    browserSessionHosts.add(uri.host);
  }

  try {
    if (App.isDesktop && (await DesktopWebview.isAvailable())) {
      final closed = Completer<void>();
      final webview = DesktopWebview(
        initialUrl: url,
        onTitleChange: (title, controller) async {
          try {
            final success = await session.check(() async {
              final ready = await controller.evaluateJavascript(
                  cloudflarePageReadyScript);
              if (ready != 'true') return false;
              final cookies = await controller.getCookies(url);
              final ua = controller.userAgent;
              if (cookies['cf_clearance']?.isNotEmpty != true ||
                  ua == null || ua.isEmpty) return false;
              saveSession(cookies, ua);
              return true;
            });
            if (success) {
              controller.close();
              onFinished();
            }
          } catch (_) {
            // Keep verification open if the document navigated during a check.
          }
        },
        onClose: () {
          session.cancel();
          if (!closed.isCompleted) closed.complete();
        },
      );
      webview.open();
      await closed.future;
    } else if (App.isMobile) {
      bool verified = false;
      await App.globalTo(() => AppWebview(
        initialUrl: url,
        singlePage: true,
        onLoadStop: (controller) async {
          try {
            final success = await session.check(() async {
              final currentUrl = await controller.getUrl();
              if (currentUrl == null ||
                  Uri.parse(currentUrl.toString()).host != uri.host) return false;
              final ready = await controller.evaluateJavascript(
                  source: cloudflarePageReadyScript);
              if (ready != true) return false;
              if (uri.host == 'nhentai.net' || uri.host == 'nhentai.xxx') {
                final content = await controller.evaluateJavascript(source:
                    "!!document.querySelector('#content, #info, .index-container')");
                if (content != true) return false;
              }
              final cookies = await controller.getCookies(url) ?? {};
              final ua = await controller.getUA();
              if (cookies['cf_clearance']?.isNotEmpty != true ||
                  ua == null || ua.isEmpty) return false;
              saveSession(cookies, ua);
              return true;
            });
            if (success) {
              verified = true;
              App.globalBack();
            }
          } catch (_) {
            // A navigation can invalidate JS evaluation. Check the next load.
          }
        },
      ));
      session.cancel();
      // Back/cancel must not retry a rejected request.
      if (verified) onFinished();
    } else {
      showToast(message: "当前设备不支持".tl);
    }
  } finally {
    _verificationOpen = false;
  }
}
