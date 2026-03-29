import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';

class MockPostRepository extends Mock implements PostRepository {}

class MockSettingsNotifier extends Mock implements SettingsNotifier {}

void main() {
  late FeedNotifier feedNotifier;
  late MockPostRepository mockPostRepository;
  late MockSettingsNotifier mockSettingsNotifier;

  setUp(() {
    mockPostRepository = MockPostRepository();
    mockSettingsNotifier = MockSettingsNotifier();

    when(() => mockSettingsNotifier.defaultSort).thenReturn(FeedSort.hot);
    when(() => mockSettingsNotifier.hideNsfw).thenReturn(false);
    when(() => mockSettingsNotifier.hideReadPosts).thenReturn(false);
    when(() => mockPostRepository.getReadPostIds()).thenReturn(<String>{});
    when(() => mockPostRepository.getSubredditInfo(any()))
        .thenAnswer((_) async => null);

    feedNotifier = FeedNotifier()
      ..setRepository(mockPostRepository)
      ..setSettings(mockSettingsNotifier);
  });

  test('loadPosts loads posts correctly', () async {
    final postList = [
      const Post(
        id: '1',
        title: 'Test',
        author: 'u1',
        subreddit: 'all',
        createdUtc: 0,
        content: '',
        ups: 10,
        numComments: 2,
        permalink: '/r/all/1',
      ),
    ];

    when(
      () => mockPostRepository.getPosts(
        subreddit: 'all',
      ),
    ).thenAnswer((_) async => (posts: postList, nextAfter: 'after_1'));

    feedNotifier.selectSubreddit('all');
    await feedNotifier.loadPosts();

    expect(feedNotifier.posts.length, 1);
    expect(feedNotifier.posts.first.id, '1');
    expect(feedNotifier.isLoading, false);
  });

  test('markAsRead updates read status without fetching again', () async {
    when(() => mockPostRepository.markAsRead('1')).thenAnswer((_) async {});
    when(() => mockPostRepository.getReadPostIds()).thenReturn({'1'});

    await feedNotifier.markAsRead('1');
    expect(feedNotifier.readPostIds.contains('1'), true);
  });
}
