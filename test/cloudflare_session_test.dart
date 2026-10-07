import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/network/cloudflare_session.dart';

void main() {
  test('overlapping callbacks finish verification only once', () async {
    final session = CloudflareSession();
    final ready = Completer<bool>();
    final first = session.check(() => ready.future);
    expect(await session.check(() async => true), isFalse);
    ready.complete(true);
    expect(await first, isTrue);
    expect(await session.check(() async => true), isFalse);
  });

  test('challenge is not completion; a later successful load can complete', () async {
    final session = CloudflareSession();
    expect(await session.check(() async => false), isFalse);
    expect(session.finished, isFalse);
    expect(await session.check(() async => true), isTrue);
  });

  test('closing while verification is pending never retries', () async {
    final session = CloudflareSession();
    final ready = Completer<bool>();
    final check = session.check(() => ready.future);
    session.cancel();
    ready.complete(true);
    expect(await check, isFalse);
  });

  test('failed JS check can be retried on the next load', () async {
    final session = CloudflareSession();
    await expectLater(session.check(() async => throw StateError('navigation')),
        throwsStateError);
    expect(await session.check(() async => true), isTrue);
  });
}
