// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:booru_clients/hydrus.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../core/configs/create/widgets.dart';
import '../../core/autocompletes/autocompletes.dart';
import '../../core/boorus/booru/booru.dart';
import '../../core/boorus/engine/engine.dart';
import '../../core/configs/auth/widgets.dart';
import '../../core/configs/config.dart';
import '../../core/configs/create/create.dart';
import '../../core/configs/manage/widgets.dart';
import '../../core/configs/ref.dart';
import '../../core/downloads/filename.dart';
import '../../core/home/home_navigation_tile.dart';
import '../../core/home/home_page_scaffold.dart';
import '../../core/home/side_menu_tile.dart';
import '../../core/http/providers.dart';
import '../../core/posts/details/details.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/details_manager/types.dart';
import '../../core/posts/details_parts/widgets.dart';
import '../../core/posts/favorites/providers.dart';
import '../../core/posts/favorites/routes.dart';
import '../../core/posts/post/post.dart';
import '../../core/posts/post/providers.dart';
import '../../core/posts/rating/rating.dart';
import '../../core/posts/sources/source.dart';
import '../../core/search/queries/providers.dart';
import '../../core/search/search/src/pages/search_page.dart';
import '../../core/search/search/widgets.dart';
import '../../core/settings/providers.dart';
import '../../core/widgets/widgets.dart';
import '../danbooru/danbooru.dart';
import '../gelbooru_v2/gelbooru_v2.dart';
import 'favorites/favorites.dart';

class HydrusPost extends SimplePost {
  HydrusPost({
    required super.id,
    required super.thumbnailImageUrl,
    required super.sampleImageUrl,
    required super.originalImageUrl,
    required super.tags,
    required super.rating,
    required super.hasComment,
    required super.isTranslated,
    required super.hasParentOrChildren,
    required super.source,
    required super.score,
    required super.duration,
    required super.fileSize,
    required super.format,
    required super.hasSound,
    required super.height,
    required super.md5,
    required super.videoThumbnailUrl,
    required super.videoUrl,
    required super.width,
    required super.uploaderId,
    required super.createdAt,
    required super.uploaderName,
    required super.metadata,
    required this.ownFavorite,
  });

  final bool? ownFavorite;
}

final hydrusClientProvider =
    Provider.family<HydrusClient, BooruConfigAuth>((ref, config) {
  final dio = ref.watch(dioProvider(config));

  return HydrusClient(
    dio: dio,
    baseUrl: config.url,
    apiKey: config.apiKey ?? '',
  );
});

final hydrusPostRepoProvider =
    Provider.family<PostRepository, BooruConfigSearch>(
  (ref, config) {
    final client = ref.watch(hydrusClientProvider(config.auth));

    Future<PostResult<HydrusPost>> getPosts(
      List<String> tags,
      int page, {
      int? limit,
      PostFetchOptions? options,
    }) async {
      final files = await client.getFiles(
        tags: tags,
        page: page,
        limit: limit,
      );

      final data = files.files
          .map(
            (e) => _postDtoToPost(
              e,
              PostMetadata(
                page: page,
                search: tags.join(' '),
                limit: limit,
              ),
            ),
          )
          .toList()
          .toResult(
            total: files.count,
          );

      if (options?.cascadeRequest ?? true) {
        ref.read(favoritesProvider(config.auth).notifier).preload(data.posts);
      }

      return data;
    }

    return PostRepositoryBuilder(
      getComposer: () => ref.read(tagQueryComposerProvider(config)),
      getSettings: () async => ref.read(imageListingSettingsProvider),
      fetchSingle: (id, {options}) async {
        final numericId = id as NumericPostId?;

        if (numericId == null) return Future.value(null);

        final file = await client.getFile(numericId.value);

        return file != null ? _postDtoToPost(file, null) : null;
      },
      fetchFromController: (controller, page, {limit, options}) {
        final tags = controller.tags.map((e) => e.originalTag).toList();
        final composer = ref.read(tagQueryComposerProvider(config));

        return getPosts(
          composer.compose(tags),
          page,
          limit: limit,
        );
      },
      fetch: getPosts,
    );
  },
);

HydrusPost _postDtoToPost(FileDto file, PostMetadata? metadata) {
  return HydrusPost(
    id: file.fileId ?? 0,
    thumbnailImageUrl: file.thumbnailUrl,
    sampleImageUrl: file.imageUrl,
    originalImageUrl: file.imageUrl,
    tags: file.allTags,
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.from(file.firstSource),
    score: 0,
    duration: file.duration?.toDouble() ?? 0,
    fileSize: file.size ?? 0,
    format: file.ext ?? '',
    hasSound: file.hasAudio,
    height: file.height?.toDouble() ?? 0,
    md5: file.hash ?? '',
    videoThumbnailUrl: file.thumbnailUrl,
    videoUrl: file.imageUrl,
    width: file.width?.toDouble() ?? 0,
    uploaderId: null,
    uploaderName: null,
    createdAt: null,
    metadata: metadata,
    ownFavorite: file.faved,
  );
}

final hydrusAutocompleteRepoProvider =
    Provider.family<AutocompleteRepository, BooruConfigAuth>((ref, config) {
  final client = ref.watch(hydrusClientProvider(config));

  return AutocompleteRepositoryBuilder(
    persistentStorageKey:
        '${Uri.encodeComponent(config.url)}_autocomplete_cache_v1',
    persistentStaleDuration: const Duration(minutes: 5),
    autocomplete: (query) async {
      final dtos = await client.getAutocomplete(query: query.text);

      return dtos.map((e) {
        // looking for xxx:tag format using regex
        final category = RegExp(r'(\w+):').firstMatch(e.value)?.group(1);

        return AutocompleteData(
          label: e.value,
          value: e.value,
          category: category,
          postCount: e.count,
        );
      }).toList();
    },
  );
});

class HydrusBuilder
    with
        ArtistNotSupportedMixin,
        CharacterNotSupportedMixin,
        CommentNotSupportedMixin,
        LegacyGranularRatingOptionsBuilderMixin,
        UnknownMetatagsMixin,
        DefaultTagSuggestionsItemBuilderMixin,
        DefaultMultiSelectionActionsBuilderMixin,
        DefaultHomeMixin,
        DefaultPostGesturesHandlerMixin,
        DefaultGranularRatingFiltererMixin,
        DefaultPostStatisticsPageBuilderMixin,
        DefaultBooruUIMixin
    implements BooruBuilder {
  HydrusBuilder();

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
            child: CreateHydrusConfigPage(
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
            child: CreateHydrusConfigPage(
              backgroundColor: backgroundColor,
              initialTab: initialTab,
            ),
          );

  @override
  PostImageDetailsUrlBuilder get postImageDetailsUrlBuilder =>
      (imageQuality, rawPost, config) => rawPost.sampleImageUrl;

  @override
  PostDetailsPageBuilder get postDetailsPageBuilder => (context, payload) {
        final posts = payload.posts.map((e) => e as HydrusPost).toList();

        return PostDetailsScope(
          initialIndex: payload.initialIndex,
          initialThumbnailUrl: payload.initialThumbnailUrl,
          posts: posts,
          scrollController: payload.scrollController,
          dislclaimer: payload.dislclaimer,
          child: const DefaultPostDetailsPage<HydrusPost>(),
        );
      };

  @override
  FavoritesPageBuilder? get favoritesPageBuilder =>
      (context) => const HydrusFavoritesPage();

  @override
  @override
  HomePageBuilder get homePageBuilder => (context) => const HydrusHomePage();

  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => HydrusSearchPage(
            params: params,
          );

  @override
  QuickFavoriteButtonBuilder? get quickFavoriteButtonBuilder =>
      (context, post) => HydrusQuickFavoriteButton(
            post: post,
          );

  @override
  final PostDetailsUIBuilder postDetailsUIBuilder = PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) => const HydrusPostActionToolbar(),
    },
    full: {
      DetailsPart.toolbar: (context) => const HydrusPostActionToolbar(),
      DetailsPart.tags: (context) =>
          const DefaultInheritedBasicTagsTile<HydrusPost>(),
      DetailsPart.fileDetails: (context) =>
          const DefaultInheritedFileDetailsSection<HydrusPost>(
            initialExpanded: true,
          ),
    },
  );
}

class HydrusRepository extends BooruRepositoryDefault {
  const HydrusRepository({required this.ref});

  @override
  final Ref ref;

  @override
  PostRepository<Post> post(BooruConfigSearch config) {
    return ref.read(hydrusPostRepoProvider(config));
  }

  @override
  AutocompleteRepository autocomplete(BooruConfigAuth config) {
    return ref.read(hydrusAutocompleteRepoProvider(config));
  }

  @override
  FavoriteRepository favorite(BooruConfigAuth config) {
    return HydrusFavoriteRepository(ref, config);
  }

  @override
  BooruSiteValidator? siteValidator(BooruConfigAuth config) {
    final dio = ref.watch(dioProvider(config));

    return () => HydrusClient(
          baseUrl: config.url,
          apiKey: config.apiKey ?? '',
          dio: dio,
        ).getFiles().then((value) => true);
  }

  @override
  PostLinkGenerator postLinkGenerator(BooruConfigAuth config) {
    return const NoLinkPostLinkGenerator();
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
}

class HydrusHomePage extends ConsumerWidget {
  const HydrusHomePage({
    super.key,
  });

  @override
  Widget build(BuildContext contex, WidgetRef ref) {
    return HomePageScaffold(
      mobileMenu: [
        SideMenuTile(
          icon: const Icon(Symbols.favorite),
          title: Text('profile.favorites'.tr()),
          onTap: () => goToFavoritesPage(ref),
        ),
      ],
      desktopMenuBuilder: (context, constraints) => [
        HomeNavigationTile(
          value: 1,
          constraints: constraints,
          selectedIcon: Symbols.favorite,
          icon: Symbols.favorite,
          title: 'Favorites',
        ),
      ],
      desktopViews: const [
        HydrusFavoritesPage(),
      ],
    );
  }
}

final ratingServiceNameProvider =
    FutureProvider.family<String?, BooruConfigAuth>((ref, config) async {
  final client = ref.read(hydrusClientProvider(config));

  final services = await client.getServicesCached();

  final key = getLikeDislikeRatingKey(services);

  if (key == null) {
    return null;
  }

  return services.firstWhereOrNull((e) => e.key == key)?.name;
});

class CreateHydrusConfigPage extends ConsumerWidget {
  const CreateHydrusConfigPage({
    super.key,
    this.backgroundColor,
    this.initialTab,
  });

  final Color? backgroundColor;
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CreateBooruConfigScaffold(
      authTab: const HydrusAuthConfigView(),
      backgroundColor: backgroundColor,
      initialTab: initialTab,
      canSubmit: apiKeyRequired,
    );
  }
}

class HydrusAuthConfigView extends ConsumerWidget {
  const HydrusAuthConfigView({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          const DefaultBooruApiKeyField(
            labelText: 'API access key',
          ),
          const SizedBox(height: 8),
          WarningContainer(
            title: 'Warning',
            contentBuilder: (context) => const Text(
              "It is recommended to not make any changes to Hydrus's services while using the app, you might see unexpected behavior.",
            ),
          ),
        ],
      ),
    );
  }
}

class HydrusPostActionToolbar extends ConsumerWidget {
  const HydrusPostActionToolbar({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<HydrusPost>(context);
    final canFav =
        ref.watch(hydrusCanFavoriteProvider(ref.watchConfigAuth)).maybeWhen(
              data: (fav) => fav,
              orElse: () => false,
            );

    return SliverToBoxAdapter(
      child: PostActionToolbar(
        children: [
          if (canFav) HydrusFavoritePostButton(post: post),
          BookmarkPostButton(post: post),
          DownloadPostButton(post: post),
        ],
      ),
    );
  }
}

class HydrusSearchPage extends ConsumerWidget {
  const HydrusSearchPage({
    required this.params,
    super.key,
  });

  final SearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigSearch;
    return SearchPageScaffold(
      params: params,
      fetcher: (page, controller) => ref
          .read(hydrusPostRepoProvider(config))
          .getPostsFromController(controller.tagSet, page),
    );
  }
}

BooruComponents createHydrus() => BooruComponents(
      parser: YamlBooruParser.standard(
        type: BooruType.hydrus,
        constructor: (siteDef) => Hydrus(
          name: siteDef.name,
          protocol: siteDef.protocol,
        ),
      ),
      createBuilder: HydrusBuilder.new,
      createRepository: (ref) => HydrusRepository(ref: ref),
    );

class Hydrus extends Booru {
  const Hydrus({
    required super.name,
    required super.protocol,
  });

  @override
  Iterable<String> get sites => const [];

  @override
  BooruType get type => BooruType.hydrus;
}
