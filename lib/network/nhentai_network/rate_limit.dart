import 'dart:io';

/// Honor Retry-After without sending more requests while rate limited.
class NhentaiRateLimit {
  DateTime? _until;

  Duration remaining(DateTime now) {
    final duration = _until?.difference(now) ?? Duration.zero;
    return duration.isNegative ? Duration.zero : duration;
  }

  void record(String? retryAfter, DateTime now) {
    final seconds = int.tryParse(retryAfter ?? '');
    DateTime? until;
    if (seconds != null && seconds >= 0) {
      until = now.add(Duration(seconds: seconds));
    } else if (retryAfter != null) {
      try {
        until = HttpDate.parse(retryAfter);
      } catch (_) {}
    }
    _until = until != null && until.isAfter(now)
        ? until : now.add(const Duration(seconds: 60));
  }

  String message(DateTime now) =>
      'nhentai: HTTP 429. Too many requests. Please retry after '
      '${(remaining(now).inMilliseconds / 1000).ceil()} seconds.';
}
