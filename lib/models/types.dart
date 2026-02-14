/// Type aliases for common record types used throughout the app.
library;

import 'package:yarc/models/post.dart';

/// Result type for paginated post fetching operations.
/// Contains the list of posts and an optional cursor for the next page.
typedef PostsResult = ({List<Post> posts, String? nextAfter});
