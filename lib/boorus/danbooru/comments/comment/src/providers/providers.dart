// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/riverpod/riverpod.dart';
import '../../../../danbooru_provider.dart';

final danbooruCommentCountProvider = FutureProvider.autoDispose
    .family<int, (BooruConfigAuth, int)>((ref, params) {
  ref.cacheFor(const Duration(seconds: 60));

  final (config, postId) = params;

  final client = ref.watch(danbooruClientProvider(config));

  return client.getCommentCount(postId: postId);
});
