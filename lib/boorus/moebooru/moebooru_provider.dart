// Package imports:
import 'package:booru_clients/moebooru.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/boorus/booru/booru.dart';
import '../../core/boorus/booru/providers.dart';
import '../../core/configs/config/types.dart';
import '../../core/http/providers.dart';
import 'moebooru.dart';

final moebooruClientProvider =
    Provider.family<MoebooruClient, BooruConfigAuth>((ref, config) {
  final dio = ref.watch(dioProvider(config));

  return MoebooruClient.custom(
    baseUrl: config.url,
    login: config.login,
    apiKey: config.apiKey,
    dio: dio,
  );
});

final moebooruProvider = Provider<Moebooru>((ref) {
  final booruDb = ref.watch(booruDbProvider);
  final booru = booruDb.getBooru<Moebooru>();

  if (booru == null) {
    throw Exception('Booru not found for type: ${BooruType.moebooru}');
  }

  return booru;
});
