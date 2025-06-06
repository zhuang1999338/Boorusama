// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../core/configs/config.dart';
import '../../../../core/configs/ref.dart';
import '../../moebooru.dart';
import 'moebooru_comment.dart';
import 'moebooru_comment_repository.dart';

final moebooruCommentRepoProvider =
    Provider.family<MoebooruCommentRepository, BooruConfigAuth>((ref, config) {
  return MoebooruCommentRepositoryApi(
    client: ref.watch(moebooruClientProvider(config)),
    booruConfig: ref.watchConfig,
  );
});

final moebooruCommentsProvider = FutureProvider.autoDispose
    .family<List<MoebooruComment>, int>((ref, postId) {
  final config = ref.watchConfigAuth;
  return ref.watch(moebooruCommentRepoProvider(config)).getComments(postId);
});
