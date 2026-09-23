import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/lan_cast/lan_cast_service.dart';

void main() {
  group('LanCastQuality', () {
    test('custom bitrate picks sane resolution and audio split', () {
      final low = LanCastQuality.custom(1000);
      expect(low.maxHeight, 360);
      expect(low.totalKbps, 1000);

      final mid = LanCastQuality.custom(3000);
      expect(mid.maxHeight, 720);
      expect(mid.audioKbps, 128);

      final high = LanCastQuality.custom(8000);
      expect(high.maxHeight, 1080);

      final clamped = LanCastQuality.custom(10);
      expect(clamped.totalKbps, 500);
    });

    test('original is passthrough', () {
      expect(LanCastQuality.original.isOriginal, isTrue);
      expect(LanCastQuality.presets.first.isOriginal, isTrue);
    });
  });

  group('buildFfmpegArgs', () {
    const q720 = LanCastQuality(id: 'medium', label: '720p', videoKbps: 2800, audioKbps: 160, maxHeight: 720);

    test('network source gets headers, reconnect flags, seek and bitrate', () {
      final args = LanCastService.buildFfmpegArgs(
        input: 'https://cdn.example/video.mkv',
        headers: {'User-Agent': 'UA/1', 'Referer': 'https://example/'},
        quality: q720,
        start: const Duration(minutes: 1, seconds: 30),
        audioStreamIndex: 1,
      );
      expect(args, containsAllInOrder(['-user_agent', 'UA/1']));
      expect(args, containsAllInOrder(['-headers', 'Referer: https://example/\r\n']));
      expect(args, contains('-reconnect'));
      expect(args, containsAllInOrder(['-ss', '90.000', '-fflags', '+genpts+discardcorrupt', '-i']));
      expect(args, containsAllInOrder(['-map', '0:a:1?']));
      expect(args, containsAllInOrder(['-b:v', '2800k']));
      expect(args, containsAllInOrder(['-b:a', '160k']));
      expect(args.join(' '), contains("min(720,ih)"));
      expect(args.last, 'pipe:1');
    });

    test('local TorrServer URL gets a long read timeout', () {
      final args = LanCastService.buildFfmpegArgs(
        input: 'http://127.0.0.1:41234/stream?link=abc&index=1&play',
        headers: const {},
        quality: q720,
      );
      expect(args, containsAllInOrder(['-rw_timeout', '180000000']));
    });

    test('local file skips network flags; original remuxes', () {
      final args = LanCastService.buildFfmpegArgs(
        input: '/tmp/movie.mkv',
        headers: const {},
        quality: LanCastQuality.original,
      );
      expect(args, isNot(contains('-reconnect')));
      expect(args, isNot(contains('-ss')));
      expect(args, containsAllInOrder(['-c', 'copy']));
      expect(args, isNot(contains('libx264')));
    });
  });
}
