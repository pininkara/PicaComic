import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/network/nhentai_network/rate_limit.dart';

void main() {
  final now = DateTime.utc(2026, 10, 7);
  test('Retry-After seconds suppress requests until the deadline', () {
    final limit = NhentaiRateLimit()..record('120', now);
    expect(limit.remaining(now), const Duration(seconds: 120));
    expect(limit.remaining(now.add(const Duration(seconds: 120))), Duration.zero);
  });
  test('HTTP date Retry-After is honored', () {
    final limit = NhentaiRateLimit()
      ..record(HttpDate.format(now.add(const Duration(minutes: 3))), now);
    expect(limit.remaining(now), const Duration(minutes: 3));
  });
  test('missing, invalid, negative or past deadline uses a 60 second cooldown', () {
    for (final header in [null, 'invalid', '-1', '0', HttpDate.format(now)]) {
      final limit = NhentaiRateLimit()..record(header, now);
      expect(limit.remaining(now), const Duration(seconds: 60));
    }
  });
}
