import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';

import '../core/api/api_client.dart';
import '../core/logic/explore.dart';
import '../core/logic/map_search.dart';
import '../core/logic/upload_order.dart';
import '../core/photo_upload.dart';
import '../core/query/hooks.dart';
import '../core/query/query_client.dart';
import '../models/dogs.dart';
import '../models/explore.dart';
import '../models/json.dart';
import 'parks.dart';
import 'services.dart';

/// Avasta (docs/16): community place posts, likes/bookmarks, reports, "Soovita kohta" and the map
/// pins. Every post list lives under ['place-posts'] so one invalidation refreshes all of them.
class ExploreKeys {
  static const all = ['place-posts'];
  static QueryKey feed(Map<String, Object> params) => ['place-posts', 'feed', params];
  static QueryKey detail(String postId) => ['place-posts', 'detail', postId];
  static const mine = ['place-posts', 'mine'];
  static const saved = ['place-posts', 'saved'];
  static QueryKey map(Bbox? bbox, List<MapTag>? tags) => [
    'map-places',
    bbox?.toJson(),
    tags?.map((t) => t.name).toList() ?? 'all',
  ];
}

/// Post photos are signed for 15 minutes; stale after 5 so a refetch replaces links in time.
const _signedUrlStale = Duration(minutes: 5);

InfiniteQueryResult<PlacePostPage> _pagedPosts(
  QueryKey key,
  String path,
  Map<String, Object> params, {
  bool enabled = true,
  bool keepPrevious = false,
}) => useInfiniteQuery<PlacePostPage>(
  key,
  (cursor) async => PlacePostPage.fromJson(await apiGet<Json>(path, {...params, 'before': ?cursor})),
  (last) => last.nextCursor,
  staleTime: _signedUrlStale,
  enabled: enabled,
  keepPreviousData: keepPrevious,
);

/// GET /place-posts: approved posts plus the viewer's own pending ones, newest first. Keeps the old
/// list while another filter loads, instead of flashing the skeleton.
InfiniteQueryResult<PlacePostPage> usePlacePostFeed(Map<String, Object> params, {bool enabled = true}) =>
    _pagedPosts(ExploreKeys.feed(params), '/place-posts', params, enabled: enabled, keepPrevious: true);

QueryResult<PlacePost> usePlacePost(String postId) => useQuery(
  ExploreKeys.detail(postId),
  () async => PlacePost.fromJson(await apiGet<Json>('/place-posts/$postId')),
  staleTime: _signedUrlStale,
);

InfiniteQueryResult<PlacePostPage> useMyPlacePosts({bool enabled = true}) =>
    _pagedPosts(ExploreKeys.mine, '/me/place-posts', const {}, enabled: enabled);

InfiniteQueryResult<PlacePostPage> useSavedPlacePosts({bool enabled = true}) =>
    _pagedPosts(ExploreKeys.saved, '/me/place-posts/saved', const {}, enabled: enabled);

/// Applies a patch to one post in any cached shape (a single post or a paged list); returns the
/// same object when the post is not in it, so unrelated screens are not notified.
Object? patchPostData(Object? data, String postId, PlacePost Function(PlacePost post) patch) {
  if (data is PlacePost) return data.id == postId ? patch(data) : data;
  if (data is InfiniteData<PlacePostPage>) {
    var changed = false;
    final pages = [
      for (final page in data.pages)
        if (page.items.any((p) => p.id == postId))
          () {
            changed = true;
            return page.withItems([for (final p in page.items) p.id == postId ? patch(p) : p]);
          }()
        else
          page,
    ];
    return changed ? data.copyWithPages(pages) : data;
  }
  return data;
}

void _patchEverywhere(String postId, PlacePost Function(PlacePost post) patch) =>
    queryClient.setQueriesData(ExploreKeys.all, (data) => patchPostData(data, postId, patch));

PlacePost? _findCached(String postId) {
  for (final (_, data) in queryClient.getQueriesData(ExploreKeys.all)) {
    if (data is PlacePost && data.id == postId) return data;
    if (data is InfiniteData<PlacePostPage>) {
      for (final page in data.pages) {
        for (final p in page.items) {
          if (p.id == postId) return p;
        }
      }
    }
  }
  return null;
}

enum PostReaction { like, save }

/// Heart and bookmark with an optimistic update. The request names the wanted state (PUT = on,
/// DELETE = off), so a retry or a double tap cannot flip it twice; the answer is the server's state
/// and replaces the guess. On failure every cache is rolled back.
MutationHandle<({String postId, bool on}), PlacePostReactions> useTogglePostReaction(PostReaction kind) =>
    useMutation<({String postId, bool on}), PlacePostReactions>(
      (input) async => PlacePostReactions.fromJson(
        await apiSend<Json>(input.on ? 'PUT' : 'DELETE', '/place-posts/${input.postId}/${kind.name}'),
      ),
      onMutate: (input) {
        queryClient.cancelQueries(ExploreKeys.all);
        final snapshot = queryClient.getQueriesData(ExploreKeys.all);
        final post = _findCached(input.postId);
        if (post != null) {
          if (kind == PostReaction.like && post.liked != input.on) {
            final next = toggledLike(liked: post.liked, likeCount: post.likeCount);
            _patchEverywhere(input.postId, (p) => p.withReactions(liked: next.liked, likeCount: next.likeCount));
          }
          if (kind == PostReaction.save) _patchEverywhere(input.postId, (p) => p.withReactions(saved: input.on));
        }
        return snapshot;
      },
      onError: (_, _, snapshot) {
        if (snapshot is List<(QueryKey, Object?)>) {
          for (final (key, data) in snapshot) {
            queryClient.find(key)?.setData(data);
          }
        }
      },
      onSuccess: (state, input) {
        _patchEverywhere(
          input.postId,
          (p) => p.withReactions(liked: state.liked, saved: state.saved, likeCount: state.likeCount),
        );
        // The "Salvestatud" list gains or loses the post.
        if (kind == PostReaction.save) queryClient.invalidateQueries(ExploreKeys.saved);
      },
    );

MutationHandle<Json, void> useReportPlacePost(String postId) =>
    useMutation<Json, void>((input) => apiSend<void>('POST', '/place-posts/$postId/reports', input));

MutationHandle<String, void> useDeletePlacePost() => useMutation<String, void>(
  (postId) => apiSend<void>('DELETE', '/me/place-posts/$postId'),
  onSuccess: (_, _) {
    queryClient.invalidateQueries(ExploreKeys.all);
    queryClient.invalidateQueries(['map-places']);
  },
);

typedef CreatePostInput = ({Json input, List<PickedPhoto> photos, void Function(int done, int total)? onProgress});

/// "Soovita kohta": photos first (each re-encoded and PUT to its own presigned URL, in the order the
/// user arranged them), then the post with their upload keys. The new post is `pending`.
MutationHandle<CreatePostInput, PlacePost> useCreatePlacePost() => useMutation<CreatePostInput, PlacePost>(
  (args) async {
    final keys = await uploadInOrder<PickedPhoto>(
      args.photos,
      (photo, _) => uploadPickedPhoto(
        photo,
        (body) async => PhotoUpload.fromJson(await apiSend<Json>('POST', '/me/place-posts/uploads', body)),
      ),
      onProgress: args.onProgress,
    );
    return PlacePost.fromJson(await apiSend<Json>('POST', '/me/place-posts', {...args.input, 'photoUploadKeys': keys}));
  },
  onSuccess: (_, _) {
    queryClient.invalidateQueries(ExploreKeys.all);
    queryClient.invalidateQueries(RewardKeys.all);
  },
);

/// GET /map/places for the visible box. Pins stay while a new box loads, and a box already seen is
/// served from the cache (the box is snapped to a grid).
QueryResult<List<MapPlace>> useMapPlaces(Bbox? bbox, List<MapTag>? tags) => useQuery(
  ExploreKeys.map(bbox, tags),
  () async => listOf(
    await apiGet<List<Object?>>('/map/places', {
      ...bbox!.toJson(),
      if (tags != null) 'tags': tags.map((t) => t.name).join(','),
    }),
    MapPlace.fromJson,
  ),
  enabled: bbox != null,
  keepPreviousData: true,
  staleTime: const Duration(minutes: 5),
);

/// The value after it has stopped changing for `delay` (typing pauses).
T useSettledValue<T>(T value, Duration delay) {
  final settled = useState(value);
  useEffect(() {
    final timer = Timer(delay, () => settled.value = value);
    return timer.cancel;
  }, [value]);
  return settled.value;
}

/// Suggestions for the Kaart search field (GET /search, docs/19). Debounced so typing "Kalamaja" is
/// one request; the origin (rounded like every location we send) sorts nearer places first.
QueryResult<SearchResponse> useMapSearch(String text, LatLng? origin) {
  final q = searchableQuery(useSettledValue(text, searchDebounce));
  final lat = origin == null ? null : (origin.lat * 1000).roundToDouble() / 1000;
  final lng = origin == null ? null : (origin.lng * 1000).roundToDouble() / 1000;
  return useQuery(
    ['map-search', q, lat, lng],
    () async => SearchResponse.fromJson(await apiGet<Json>('/search', {'q': q!, 'lat': ?lat, 'lng': ?lng})),
    enabled: q != null,
    keepPreviousData: true,
    staleTime: const Duration(minutes: 5),
  );
}
