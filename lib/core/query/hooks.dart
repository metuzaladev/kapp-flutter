import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'query_client.dart';

/// What a screen sees of a query (TanStack `UseQueryResult`).
class QueryResult<T> {
  const QueryResult({
    required this.data,
    required this.error,
    required this.isPending,
    required this.isFetching,
    required this.isPlaceholderData,
    required this.refetch,
  });

  final T? data;
  final Object? error;

  /// No data yet (the first load, or a disabled query that never ran).
  final bool isPending;
  final bool isFetching;

  /// `data` is the previous key's result, shown while the new one loads.
  final bool isPlaceholderData;
  final Future<void> Function() refetch;

  bool get isLoading => isPending && isFetching;
  bool get isSuccess => !isPending && error == null;
  bool get isError => error != null;
}

/// Subscribes the widget to a cached query and fetches it when it is missing or stale.
///
/// - `keepPreviousData`: while a new key loads, keep showing the last key's data (filters, maps).
/// - `refetchInterval`: polling, e.g. while the realtime socket is down.
QueryResult<T> useQuery<T>(
  QueryKey key,
  Future<T> Function() fetcher, {
  Duration staleTime = QueryClient.defaultStaleTime,
  bool enabled = true,
  bool keepPreviousData = false,
  Duration? refetchInterval,
  QueryClient? client,
}) {
  final c = client ?? queryClient;
  final hash = hashKey(key);
  final entry = useMemoized(() => c.entry<T>(key), [hash, c]);
  entry
    ..fetcher = fetcher
    ..staleTime = staleTime;
  useListenable(entry);

  useEffect(() {
    final observer = QueryObserver(enabled: enabled);
    entry.addObserver(observer);
    if (enabled && entry.isStale()) {
      // After the frame: fetch() notifies listeners, which must not happen during build.
      scheduleMicrotask(() => unawaited(entry.fetch()));
    }
    Timer? timer;
    if (enabled && refetchInterval != null) {
      timer = Timer.periodic(refetchInterval, (_) => unawaited(entry.fetch()));
    }
    return () {
      timer?.cancel();
      entry.removeObserver(observer);
    };
  }, [entry, enabled, refetchInterval]);

  final previous = useRef<(bool, T?)>((false, null));
  if (entry.hasData) previous.value = (true, entry.data);
  final usePlaceholder = keepPreviousData && !entry.hasData && previous.value.$1;

  return QueryResult<T>(
    data: usePlaceholder ? previous.value.$2 : entry.data,
    error: entry.error,
    isPending: !entry.hasData && !usePlaceholder,
    isFetching: entry.isFetching,
    isPlaceholderData: usePlaceholder,
    refetch: () {
      entry.invalidate();
      return entry.fetch();
    },
  );
}

/// A paged list (TanStack `useInfiniteQuery`).
class InfiniteQueryResult<P> {
  const InfiniteQueryResult({
    required this.data,
    required this.error,
    required this.isPending,
    required this.isFetching,
    required this.isFetchingNextPage,
    required this.hasNextPage,
    required this.fetchNextPage,
    required this.refetch,
  });

  final InfiniteData<P>? data;
  final Object? error;
  final bool isPending;
  final bool isFetching;
  final bool isFetchingNextPage;
  final bool hasNextPage;
  final Future<void> Function() fetchNextPage;
  final Future<void> Function() refetch;

  List<P> get pages => data?.pages ?? const [];
}

InfiniteQueryResult<P> useInfiniteQuery<P>(
  QueryKey key,
  Future<P> Function(String? cursor) fetchPage,
  String? Function(P lastPage) nextCursor, {
  Duration staleTime = QueryClient.defaultStaleTime,
  bool enabled = true,
  bool keepPreviousData = false,
  Duration? refetchInterval,
  QueryClient? client,
}) {
  final c = client ?? queryClient;
  final hash = hashKey(key);
  final entry = useMemoized(() => c.entry<InfiniteData<P>>(key), [hash, c]);

  // A refetch reloads every page that is already shown, in order, like TanStack Query.
  Future<InfiniteData<P>> reloadAll() async {
    final count = entry.data?.pages.length ?? 1;
    final pages = <P>[];
    final params = <String?>[];
    String? cursor;
    for (var i = 0; i < count; i++) {
      final page = await fetchPage(cursor);
      pages.add(page);
      params.add(cursor);
      cursor = nextCursor(page);
      if (cursor == null) break;
    }
    return InfiniteData(pages, params);
  }

  final result = useQuery<InfiniteData<P>>(
    key,
    reloadAll,
    staleTime: staleTime,
    enabled: enabled,
    keepPreviousData: keepPreviousData,
    refetchInterval: refetchInterval,
    client: c,
  );
  useListenable(entry);

  final data = result.data;
  final cursor = data == null || data.pages.isEmpty ? null : nextCursor(data.pages.last);

  return InfiniteQueryResult<P>(
    data: data,
    error: result.error,
    isPending: result.isPending,
    isFetching: result.isFetching,
    isFetchingNextPage: entry.isFetchingNextPage,
    hasNextPage: cursor != null,
    refetch: result.refetch,
    fetchNextPage: () async {
      final current = entry.data;
      if (current == null || cursor == null || entry.isFetchingNextPage) return;
      await entry.runAndStore(() async {
        final page = await fetchPage(cursor);
        return InfiniteData([...current.pages, page], [...current.pageParams, cursor]);
      }, nextPage: true);
    },
  );
}

/// A write (TanStack `useMutation`). Callbacks given to `mutate` run after the hook's own.
class MutationHandle<I, O> extends ChangeNotifier {
  MutationHandle();

  late Future<O> Function(I input) _fn;
  FutureOr<Object?> Function(I input)? _onMutate;
  FutureOr<void> Function(O result, I input)? _onSuccess;
  FutureOr<void> Function(Object error, I input, Object? context)? _onError;
  FutureOr<void> Function(O? result, Object? error, I input)? _onSettled;

  bool isPending = false;
  bool isSuccess = false;
  Object? error;
  O? data;
  I? variables;
  bool _disposed = false;

  bool get isError => error != null;

  Future<O> mutateAsync(I input) async {
    isPending = true;
    isSuccess = false;
    error = null;
    variables = input;
    _notify();
    Object? context;
    try {
      context = await _onMutate?.call(input);
      final result = await _fn(input);
      data = result;
      isSuccess = true;
      isPending = false;
      _notify();
      await _onSuccess?.call(result, input);
      await _onSettled?.call(result, null, input);
      return result;
    } catch (e) {
      error = e;
      isPending = false;
      _notify();
      await _onError?.call(e, input, context);
      await _onSettled?.call(null, e, input);
      rethrow;
    }
  }

  /// Fire and forget; errors end up in [error] and the optional callback.
  void mutate(I input, {void Function(O result)? onSuccess, void Function(Object error)? onError}) {
    mutateAsync(input).then((r) => onSuccess?.call(r), onError: (Object e) => onError?.call(e));
  }

  void reset() {
    isPending = false;
    isSuccess = false;
    error = null;
    data = null;
    variables = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

MutationHandle<I, O> useMutation<I, O>(
  Future<O> Function(I input) fn, {
  FutureOr<Object?> Function(I input)? onMutate,
  FutureOr<void> Function(O result, I input)? onSuccess,
  FutureOr<void> Function(Object error, I input, Object? context)? onError,
  FutureOr<void> Function(O? result, Object? error, I input)? onSettled,
}) {
  final handle = useMemoized(MutationHandle<I, O>.new);
  useEffect(() => handle.dispose, [handle]);
  handle
    .._fn = fn
    .._onMutate = onMutate
    .._onSuccess = onSuccess
    .._onError = onError
    .._onSettled = onSettled;
  useListenable(handle);
  return handle;
}

/// A [ValueListenable] as hook state (module stores such as park filters).
T useStore<T>(ValueListenable<T> store) => useValueListenable(store);
