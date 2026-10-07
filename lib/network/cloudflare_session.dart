/// Origins verified in the browser during this process.
final browserSessionHosts = <String>{};

/// Check the loaded document, rather than the existence of an old cookie.
const cloudflarePageReadyScript = '''
(() => document.readyState === 'complete' && !!document.body &&
  !window._cf_chl_opt &&
  !document.querySelector('#challenge-form, #challenge-running, #challenge-stage'))()
''';

/// WebView title/load callbacks can overlap. Only one may complete a session.
class CloudflareSession {
  bool _checking = false;
  bool _finished = false;

  bool get finished => _finished;

  void cancel() => _finished = true;

  Future<bool> check(Future<bool> Function() verify) async {
    if (_checking || _finished) return false;
    _checking = true;
    try {
      if (await verify() && !_finished) {
        _finished = true;
        return true;
      }
      return false;
    } finally {
      _checking = false;
    }
  }
}
