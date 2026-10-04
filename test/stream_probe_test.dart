import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radioapp/data/stream_probe.dart';

HttpStreamProbe probe(
  int status,
  String contentType, {
  List<List<int>> chunks = const [],
  bool endless = false,
}) => HttpStreamProbe(
  timeout: const Duration(milliseconds: 300),
  client: MockClient.streaming((request, _) async {
    final controller = StreamController<List<int>>();
    for (final chunk in chunks) {
      controller.add(chunk);
    }
    if (!endless) unawaited(controller.close());
    return http.StreamedResponse(
      controller.stream,
      status,
      headers: {'content-type': contentType},
    );
  }),
);

void main() {
  test('audio that flows is ok', () async {
    final result = await probe(
      200,
      'audio/mpeg',
      chunks: [List.filled(4096, 0)],
      endless: true,
    ).check('https://radio.example/live');
    expect(result, StreamHealth.ok);
  });

  test('a short HLS playlist is ok', () async {
    expect(
      await probe(
        200,
        'application/vnd.apple.mpegurl',
        chunks: ['#EXTM3U\n'.codeUnits],
      ).check('https://x/a.m3u8'),
      StreamHealth.ok,
    );
  });

  test('errors, web pages and silence fail', () async {
    expect(
      await probe(404, 'audio/mpeg').check('https://x/a'),
      StreamHealth.failed,
    );
    expect(
      await probe(
        200,
        'text/html',
        chunks: ['<html>'.codeUnits],
      ).check('https://x/a'),
      StreamHealth.failed,
    );
    expect(
      await probe(200, 'audio/mpeg', endless: true).check('https://x/a'),
      StreamHealth.failed,
    );
    expect(
      await probe(200, 'audio/mpeg').check('not a url at all\n'),
      StreamHealth.failed,
    );
  });

  test('a geo-blocked server that refuses the connection fails', () async {
    final blocked = HttpStreamProbe(
      client: MockClient(
        (_) async => throw http.ClientException('Connection refused'),
      ),
    );
    expect(await blocked.check('https://x/a'), StreamHealth.failed);
  });
}
