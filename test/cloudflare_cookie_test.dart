import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pica_comic/network/cookie_jar.dart';

void main() {
  test('new clearance replaces stale domain/path variants and preserves login', () {
    final jar = CookieJarSql(':memory:');
    addTearDown(jar.dispose);
    final gallery = Uri.parse('https://nhentai.net/g/123/');
    jar.saveFromResponse(gallery, [
      Cookie('cf_clearance', 'stale')..domain = 'nhentai.net'..path = '/g/',
      Cookie('cf_clearance', 'also-stale')..domain = '.nhentai.net'..path = '/',
      Cookie('sessionid', 'login')..domain = 'nhentai.net'..path = '/',
    ]);
    jar.deleteMatching(gallery, 'cf_clearance');
    jar.saveFromResponse(gallery, [
      Cookie('cf_clearance', 'fresh')..domain = 'nhentai.net'..path = '/',
    ]);
    final cookies = jar.loadForRequestCookieHeader(gallery);
    expect(cookies, contains('cf_clearance=fresh'));
    expect(cookies, isNot(contains('stale')));
    expect(cookies, contains('sessionid=login'));
    expect(jar.loadForRequestCookieHeader(Uri.parse('https://nhentai.net/')),
        contains('cf_clearance=fresh'));
  });
}
