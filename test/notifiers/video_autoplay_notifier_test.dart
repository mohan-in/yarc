import 'package:flutter_test/flutter_test.dart';
import 'package:yarc/notifiers/video_autoplay_notifier.dart';

void main() {
  late VideoAutoplayNotifier notifier;

  setUp(() {
    notifier = VideoAutoplayNotifier();
  });

  group('VideoAutoplayNotifier', () {
    test('play sets playingVideoId and notifies listeners', () {
      notifier.play('v1');
      expect(notifier.playingVideoId, 'v1');

      notifier.play('v2');
      expect(notifier.playingVideoId, 'v2');
    });

    test('stop clears playingVideoId if ID matches', () {
      notifier
        ..play('v1')
        ..stop('v2'); // different ID
      expect(notifier.playingVideoId, 'v1');

      notifier.stop('v1'); // matching ID
      expect(notifier.playingVideoId, isNull);
    });

    test('reset clears playingVideoId unconditionally', () {
      notifier
        ..play('v1')
        ..reset();
      expect(notifier.playingVideoId, isNull);
    });
  });
}
