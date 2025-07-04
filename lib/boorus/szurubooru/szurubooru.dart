// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:booru_clients/szurubooru.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/autocompletes/autocompletes.dart';
import '../../core/boorus/booru/booru.dart';
import '../../core/boorus/engine/engine.dart';
import '../../core/configs/auth/widgets.dart';
import '../../core/configs/config.dart';
import '../../core/configs/create/create.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/configs/manage/widgets.dart';
import '../../core/configs/ref.dart';
import '../../core/downloads/filename.dart';
import '../../core/foundation/html.dart';
import '../../core/http/providers.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/details_manager/types.dart';
import '../../core/posts/details_parts/widgets.dart';
import '../../core/posts/favorites/providers.dart';
import '../../core/posts/post/post.dart';
import '../../core/posts/post/providers.dart';
import '../../core/scaffolds/scaffolds.dart';
import '../../core/search/queries/query.dart';
import '../../core/search/search/src/pages/search_page.dart';
import '../../core/search/search/widgets.dart';
import '../../core/tags/tag/tag.dart';
import '../../core/widgets/widgets.dart';
import '../danbooru/danbooru.dart';
import '../gelbooru_v2/gelbooru_v2.dart';
import 'create_szurubooru_config_page.dart';
import 'post_votes/szurubooru_post_action_toolbar.dart';
import 'providers.dart';
import 'szurubooru_home_page.dart';
import 'szurubooru_post.dart';
import 'szurubooru_post_details_page.dart';

class SzurubooruBuilder
    with
        ArtistNotSupportedMixin,
        CharacterNotSupportedMixin,
        LegacyGranularRatingOptionsBuilderMixin,
        UnknownMetatagsMixin,
        DefaultTagSuggestionsItemBuilderMixin,
        DefaultMultiSelectionActionsBuilderMixin,
        DefaultQuickFavoriteButtonBuilderMixin,
        DefaultHomeMixin,
        DefaultPostImageDetailsUrlMixin,
        DefaultPostGesturesHandlerMixin,
        DefaultGranularRatingFiltererMixin,
        DefaultPostStatisticsPageBuilderMixin,
        DefaultBooruUIMixin
    implements BooruBuilder {
  SzurubooruBuilder();

  @override
  CreateConfigPageBuilder get createConfigPageBuilder => (
        context,
        id, {
        backgroundColor,
      }) =>
          CreateBooruConfigScope(
            id: id,
            config: BooruConfig.defaultConfig(
              booruType: id.booruType,
              url: id.url,
              customDownloadFileNameFormat: null,
            ),
            child: CreateSzurubooruConfigPage(
              backgroundColor: backgroundColor,
            ),
          );

  @override
  UpdateConfigPageBuilder get updateConfigPageBuilder => (
        context,
        id, {
        backgroundColor,
        initialTab,
      }) =>
          UpdateBooruConfigScope(
            id: id,
            child: CreateSzurubooruConfigPage(
              backgroundColor: backgroundColor,
              initialTab: initialTab,
            ),
          );

  @override
  CommentPageBuilder? get commentPageBuilder =>
      (context, useAppBar, postId) => CommentPageScaffold(
            postId: postId,
            useAppBar: useAppBar,
          );

  @override
  FavoritesPageBuilder? get favoritesPageBuilder =>
      (context) => const SzurubooruFavoritesPage();

  @override
  HomePageBuilder get homePageBuilder =>
      (context) => const SzurubooruHomePage();

  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => SzurubooruSearchPage(
            params: params,
          );

  @override
  PostDetailsPageBuilder get postDetailsPageBuilder => (context, payload) {
        final posts = payload.posts.map((e) => e as SzurubooruPost).toList();

        return PostDetailsScope(
          initialIndex: payload.initialIndex,
          initialThumbnailUrl: payload.initialThumbnailUrl,
          posts: posts,
          scrollController: payload.scrollController,
          dislclaimer: payload.dislclaimer,
          child: const DefaultPostDetailsPage<SzurubooruPost>(),
        );
      };

  @override
  final PostDetailsUIBuilder postDetailsUIBuilder = PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) => const SzurubooruPostActionToolbar(),
    },
    full: {
      DetailsPart.toolbar: (context) => const SzurubooruPostActionToolbar(),
      DetailsPart.stats: (context) => const SzurubooruStatsTileSection(),
      DetailsPart.tags: (context) =>
          const DefaultInheritedTagsTile<SzurubooruPost>(),
      DetailsPart.fileDetails: (context) =>
          const SzurubooruFileDetailsSection(),
    },
  );
}

class SzurubooruRepository extends BooruRepositoryDefault {
  const SzurubooruRepository({required this.ref});

  @override
  final Ref ref;

  @override
  PostRepository<Post> post(BooruConfigSearch config) {
    return ref.read(szurubooruPostRepoProvider(config));
  }

  @override
  AutocompleteRepository autocomplete(BooruConfigAuth config) {
    return ref.read(szurubooruAutocompleteRepoProvider(config));
  }

  @override
  FavoriteRepository favorite(BooruConfigAuth config) {
    return SzurubooruFavoriteRepository(ref, config);
  }

  @override
  BooruSiteValidator? siteValidator(BooruConfigAuth config) {
    final dio = ref.watch(dioProvider(config));

    return () => SzurubooruClient(
          baseUrl: config.url,
          dio: dio,
          username: config.login,
          token: config.apiKey,
        ).getPosts().then((value) => true);
  }

  @override
  TagQueryComposer tagComposer(BooruConfigSearch config) {
    return SzurubooruTagQueryComposer(config: config);
  }

  @override
  PostLinkGenerator<Post> postLinkGenerator(BooruConfigAuth config) {
    return SingularPostLinkGenerator(baseUrl: config.url);
  }

  @override
  DownloadFilenameGenerator<Post> downloadFilenameBuilder(
    BooruConfigAuth config,
  ) {
    return DownloadFileNameBuilder<Post>(
      defaultFileNameFormat: kGelbooruV2CustomDownloadFileNameFormat,
      defaultBulkDownloadFileNameFormat:
          kGelbooruV2CustomDownloadFileNameFormat,
      sampleData: kDanbooruPostSamples,
      tokenHandlers: [
        WidthTokenHandler(),
        HeightTokenHandler(),
        AspectRatioTokenHandler(),
      ],
    );
  }

  @override
  TagGroupRepository<Post> tagGroup(BooruConfigAuth config) {
    return ref.watch(szurubooruTagGroupRepoProvider(config));
  }
}

class SzurubooruSearchPage extends ConsumerWidget {
  const SzurubooruSearchPage({
    required this.params,
    super.key,
  });

  final SearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigSearch;
    final postRepo = ref.watch(szurubooruPostRepoProvider(config));

    return SearchPageScaffold(
      noticeBuilder: (context) => !config.auth.hasLoginDetails()
          ? InfoContainer(
              contentBuilder: (context) => const AppHtml(
                data:
                    'You need to log in to use <b>Szurubooru</b> tag completion.',
              ),
            )
          : const SizedBox.shrink(),
      params: params,
      fetcher: (page, controller) =>
          postRepo.getPostsFromController(controller.tagSet, page),
    );
  }
}

class SzurubooruFavoritesPage extends ConsumerWidget {
  const SzurubooruFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;

    return BooruConfigAuthFailsafe(
      builder: (_) => SzurubooruFavoritesPageInternal(
        username: config.login!,
      ),
    );
  }
}

class SzurubooruFavoritesPageInternal extends ConsumerWidget {
  const SzurubooruFavoritesPageInternal({
    required this.username,
    super.key,
  });

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigSearch;
    final query = 'fav:${config.auth.login?.replaceAll(' ', '_')}';

    return FavoritesPageScaffold(
      favQueryBuilder: () => query,
      fetcher: (page) =>
          ref.read(szurubooruPostRepoProvider(config)).getPosts(query, page),
    );
  }
}

BooruComponents createSzurubooru() => BooruComponents(
      parser: YamlBooruParser.standard(
        type: BooruType.szurubooru,
        constructor: (siteDef) => Szurubooru(
          name: siteDef.name,
          protocol: siteDef.protocol,
        ),
      ),
      createBuilder: SzurubooruBuilder.new,
      createRepository: (ref) => SzurubooruRepository(ref: ref),
    );

class Szurubooru extends Booru {
  const Szurubooru({
    required super.name,
    required super.protocol,
  });

  @override
  Iterable<String> get sites => const [];

  @override
  BooruType get type => BooruType.szurubooru;
}
