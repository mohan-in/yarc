import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/services/history_service.dart';
import 'package:yarc/utils/constants.dart';

import '../helpers/mocks.dart';

void main() {
  late MockBox<dynamic> mockBox;
  late HistoryService historyService;

  setUp(() {
    mockBox = MockBox<dynamic>();
    historyService = HistoryService(mockBox);
  });

  group('HistoryService', () {
    test('markAsRead puts postId with timestamp and checks cap', () async {
      when(() => mockBox.length).thenReturn(1);
      when(
        () => mockBox.put(any<String>(), any<dynamic>()),
      ).thenAnswer((_) async {});

      await historyService.markAsRead('t3_123');

      verify(() => mockBox.put('t3_123', any<dynamic>())).called(1);
    });

    test('markMultipleAsRead puts all entries and checks cap', () async {
      when(() => mockBox.length).thenReturn(2);
      when(
        () => mockBox.putAll(any<Map<dynamic, dynamic>>()),
      ).thenAnswer((_) async {});

      await historyService.markMultipleAsRead(['t3_1', 't3_2']);

      verify(() => mockBox.putAll(any<Map<dynamic, dynamic>>())).called(1);
    });

    test('isRead checks if box contains key', () {
      when(() => mockBox.containsKey('t3_123')).thenReturn(true);
      when(() => mockBox.containsKey('t3_456')).thenReturn(false);

      expect(historyService.isRead('t3_123'), isTrue);
      expect(historyService.isRead('t3_456'), isFalse);
    });

    test('getReadPostIds returns keys as set', () {
      when(() => mockBox.keys).thenReturn(['t3_1', 't3_2']);

      expect(historyService.getReadPostIds(), equals({'t3_1', 't3_2'}));
    });

    test('clearReadPosts clears box', () async {
      when(() => mockBox.clear()).thenAnswer((_) async => 0);

      await historyService.clearReadPosts();

      verify(() => mockBox.clear()).called(1);
    });

    test(
      'enforces cap by deleting oldest entries when exceeding max',
      () async {
        when(
          () => mockBox.put(any<String>(), any<dynamic>()),
        ).thenAnswer((_) async {});
        when(() => mockBox.length).thenReturn(kMaxReadHistoryCount + 2);
        when(() => mockBox.toMap()).thenReturn({
          'old1': 100,
          'old2': 200,
          'new1': 300,
          'new2': 400,
        });
        when(
          () => mockBox.deleteAll(any<Iterable<dynamic>>()),
        ).thenAnswer((_) async {});

        await historyService.markAsRead('new_post');

        verify(() => mockBox.deleteAll(['old1', 'old2'])).called(1);
      },
    );
  });
}
