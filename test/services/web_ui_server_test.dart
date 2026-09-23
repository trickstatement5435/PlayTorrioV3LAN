import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/web_ui/web_ui_page.dart';
import 'package:playtorrio/services/web_ui/web_ui_server.dart';

void main() {
  group('toWebVtt', () {
    test('converts SRT timings and keeps text', () {
      const srt = '1\r\n00:00:01,500 --> 00:00:03,000\r\nHello\r\nthere\r\n\r\n2\r\n0:01:02,5 --> 0:01:04,000\r\n<i>Bye</i>\r\n';
      final vtt = WebUiServer.toWebVtt(srt);
      expect(vtt.startsWith('WEBVTT'), isTrue);
      expect(vtt, contains('00:00:01.500 --> 00:00:03.000\nHello\nthere'));
      expect(vtt, contains('00:01:02.500 --> 00:01:04.000\n<i>Bye</i>'));
    });

    test('passes WebVTT through', () {
      const v = 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHi\n';
      expect(WebUiServer.toWebVtt(v), v);
    });

    test('converts ASS dialogue and strips styling', () {
      const ass = '[Script Info]\nTitle: x\n\n[Events]\n'
          'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
          r'Dialogue: 0,0:00:05.20,0:00:07.00,Default,,0,0,0,,{\i1}Hello{\i0}, world\Nline two'
          '\n';
      final vtt = WebUiServer.toWebVtt(ass);
      expect(vtt, contains('00:00:05.200 --> 00:00:07.000'));
      expect(vtt, contains('Hello, world\nline two'));
    });
  });

  test('web page is embedded', () {
    expect(kWebUiHtml, contains('<title>PlayTorrio</title>'));
    expect(kWebUiHtml, contains('api/sources/start'));
  });
}
