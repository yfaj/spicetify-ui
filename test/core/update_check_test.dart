import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spicetify_ui/core/update_check.dart';

void main() {
  group('isNewerVersion', () {
    test('detects newer releases', () {
      expect(isNewerVersion('1.1.0', 'v1.2.0'), isTrue);
      expect(isNewerVersion('1.1.0', 'v2.0.0'), isTrue);
      expect(isNewerVersion('1.1.0', 'v1.1.1'), isTrue);
      expect(isNewerVersion('1.1.0+2', 'v1.1.1'), isTrue);
    });

    test('same or older releases are not updates', () {
      expect(isNewerVersion('1.1.0', 'v1.1.0'), isFalse);
      expect(isNewerVersion('1.1.0+2', 'v1.1.0'), isFalse);
      expect(isNewerVersion('1.2.0', 'v1.1.0'), isFalse);
    });

    test('handles missing segments', () {
      expect(isNewerVersion('1.1', 'v1.1.0'), isFalse);
      expect(isNewerVersion('1.1', 'v1.1.1'), isTrue);
    });
  });

  group('fetchLatestReleaseTag', () {
    test('returns the tag from a valid response', () async {
      final tag = await fetchLatestReleaseTag(
        clientFactory: _fakeClient('{"tag_name": "v9.9.9"}', 200),
      );
      expect(tag, 'v9.9.9');
    });

    test('returns null on non-200', () async {
      final tag = await fetchLatestReleaseTag(
        clientFactory: _fakeClient('{"message": "nope"}', 404),
      );
      expect(tag, isNull);
    });

    test('returns null on malformed json', () async {
      final tag = await fetchLatestReleaseTag(
        clientFactory: _fakeClient('not json', 200),
      );
      expect(tag, isNull);
    });
  });
}

HttpClient Function() _fakeClient(String body, int status) {
  return () {
    final client = _StubClient(body, status);
    return client;
  };
}

class _StubClient implements HttpClient {
  _StubClient(this.body, this.status);

  final String body;
  final int status;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _StubRequest(body, status);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _StubRequest implements HttpClientRequest {
  _StubRequest(this.body, this.status);

  final String body;
  final int status;

  @override
  void add(List<int> data) {}

  @override
  Future<HttpClientResponse> close() async => _StubResponse(body, status);

  @override
  HttpHeaders get headers => _StubHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _StubHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _StubResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _StubResponse(this.body, this.statusCode);

  final String body;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(body)).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
