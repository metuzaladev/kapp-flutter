import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

/// Server-state cache for the whole app — a small port of the TanStack Query features the React
/// Native app relies on: hierarchical keys with prefix invalidation, stale times, deduplicated
/// requests, retries for transient errors, optimistic `setQueryData`, paged ("infinite") lists, and
/// a refetch when the app returns to the foreground or the network comes back.
///
/// Why not a package: the screens were written against exactly these semantics (query keys such as
/// `['parks', 'detail', id]`, `invalidateQueries(['parks'])`), and keeping them makes the port
/// reviewable side by side with the React Native code.
typedef QueryKey = List<Object?>;

Object? _encodable(Object? value) {
  if (value == null || value is num || value is String || value is bool) return value;
  if (value is List) return value.map(_encodable).toList();
  if (value is Map) return {for (final e in value.entries) '${e.key}': _encodable(e.value)};
  try {
    return _encodable((value as dynamic).toJson());
  } catch (_) {
    return value.toString();
  }
}

/// Stable string for a key (maps are compared by content, like TanStack's hashKey).
String hashKey(QueryKey key) => jsonEncode(_encodable(key));

/// Whether `key` starts with `prefix` (element-wise, by value).
bool keyMatches(QueryKey key, QueryKey prefix, {bool exact = false}) {
  if (exact) return hashKey(key) == hashKey(prefix);
  if (prefix.length > key.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (jsonEncode(_encodable(key[i])) != jsonEncode(_encodable(prefix[i]))) return false;
  }
  return true;
}

/// 4xx answers are final (bad input, not found, signed out) — retrying cannot help.
bool shouldRetry(int failureCount, Object error) {
  if (error is ApiRequestError && error.status >= 400 && error.status < 500) return false;
  return failureCount < 2;
}

class QueryObserver {
  QueryObserver({required this.enabled});
  bool enabled;
}

/// One cached query. Widgets listen to it; [QueryClient] owns it.
class QueryEntry<T> extends ChangeNotifier {
  QueryEntry(this.client, this.key);

  final QueryClient client;
  final QueryKey key;

  T? _data;
  bool _hasData = false;
  Object? error;
  bool isFetching = false;
  bool isFetchingNextPage = false;
  DateTime? dataUpdatedAt;
  bool _invalidated = false;

  Future<T> Function()? fetcher;
  Duration staleTime = QueryClient.defaultStaleTime;

  final Set<QueryObserver> _observers = {};
  Future<void>? _inFlight;
  int _generation = 0;
  Timer? _gcTimer;
  bool _disposed = false;

  T? get data => _data;
  bool get hasData => _hasData;
  bool get hasObservers => _observers.isNotEmpty;
  bool get hasEnabledObservers => _observers.any((o) => o.enabled);

  bool isStale([DateTime? now]) =>
      _invalidated || dataUpdatedAt == null || (now ?? DateTime.now()).difference(dataUpdatedAt!) >= staleTime;

  void addObserver(QueryObserver observer) {
    _gcTimer?.cancel();
    _observers.add(observer);
  }

  void removeObserver(QueryObserver observer) {
    _observers.remove(observer);
    if (_observers.isEmpty) {
      // Keep data around for offline use (30 min after the last screen stops using it).
      _gcTimer = Timer(QueryClient.gcTime, () => client._remove(this));
    }
  }

  void setData(T? data) {
    _data = data;
    _hasData = true;
    error = null;
    dataUpdatedAt = DateTime.now();
    _invalidated = false;
    _notify();
  }

  void invalidate() => _invalidated = true;

  /// Ignores the result of a running fetch (an optimistic update must not be overwritten by it).
  void cancel() {
    _generation++;
    _inFlight = null;
    if (isFetching) {
      isFetching = false;
      _notify();
    }
  }

  /// Fetches unless a request is already running (deduplication).
  Future<void> fetch() {
    final task = fetcher;
    if (task == null) return Future.value();
    return _inFlight ??= _run(task);
  }

  /// Runs `task` and stores its result as the new data (used for "load more" pages).
  Future<void> runAndStore(Future<T> Function() task, {bool nextPage = false}) async {
    if (nextPage) {
      if (isFetchingNextPage) return;
      isFetchingNextPage = true;
      _notify();
    }
    final generation = _generation;
    try {
      final result = await task();
      if (generation == _generation) setData(result);
    } catch (e) {
      if (generation == _generation) {
        error = e;
        _notify();
      }
    } finally {
      if (nextPage) {
        isFetchingNextPage = false;
        _notify();
      }
    }
  }

  Future<void> _run(Future<T> Function() task) async {
    final generation = ++_generation;
    isFetching = true;
    _notify();
    var failures = 0;
    while (true) {
      try {
        final result = await task();
        if (generation != _generation) return;
        isFetching = false;
        _inFlight = null;
        setData(result);
        return;
      } catch (e) {
        if (generation != _generation) return;
        if (shouldRetry(failures, e) && !client.testMode) {
          // Exponential back-off like TanStack Query: 1 s, 2 s.
          await Future<void>.delayed(Duration(milliseconds: math.min(1000 * (1 << failures), 30000)));
          failures++;
          if (generation != _generation) return;
          continue;
        }
        isFetching = false;
        _inFlight = null;
        error = e;
        _notify();
        return;
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _gcTimer?.cancel();
    super.dispose();
  }
}

class QueryClient {
  QueryClient({this.testMode = false});

  /// Parks and profiles change rarely; avoid refetching on every screen visit.
  static const defaultStaleTime = Duration(seconds: 60);
  static const gcTime = Duration(minutes: 30);

  /// No retry delays (unit tests).
  final bool testMode;

  final Map<String, QueryEntry<Object?>> _entries = {};

  QueryEntry<T> entry<T>(QueryKey key) {
    final hash = hashKey(key);
    final existing = _entries[hash];
    if (existing != null) return existing as QueryEntry<T>;
    final created = QueryEntry<T>(this, List.unmodifiable(key));
    _entries[hash] = created as QueryEntry<Object?>;
    return created;
  }

  QueryEntry<Object?>? find(QueryKey key) => _entries[hashKey(key)];

  T? getQueryData<T>(QueryKey key) => find(key)?.data as T?;

  /// Replaces a query's data (optimistic updates, answers that already carry the new state).
  void setQueryData<T>(QueryKey key, T? Function(T? previous) update) {
    final e = entry<T>(key);
    e.setData(update(e.data));
  }

  /// Marks every query under `prefix` stale and refetches the ones a screen is showing.
  void invalidateQueries(QueryKey prefix, {bool exact = false}) {
    for (final e in _matching(prefix, exact: exact)) {
      e.invalidate();
      if (e.hasEnabledObservers) unawaited(e.fetch());
    }
  }

  /// Ignores running fetches under `prefix` (before an optimistic update).
  void cancelQueries(QueryKey prefix) {
    for (final e in _matching(prefix)) {
      e.cancel();
    }
  }

  List<(QueryKey, Object?)> getQueriesData(QueryKey prefix) => [
    for (final e in _matching(prefix))
      if (e.hasData) (e.key, e.data),
  ];

  void setQueriesData(QueryKey prefix, Object? Function(Object? data) update) {
    for (final e in _matching(prefix)) {
      if (!e.hasData) continue;
      final next = update(e.data);
      if (!identical(next, e.data)) e.setData(next);
    }
  }

  /// Cached server data belongs to one user: never show the previous user's favourites.
  void clear() {
    for (final e in _entries.values.toList()) {
      e.cancel();
      if (!e.hasObservers) {
        _remove(e);
      } else {
        e
          .._data = null
          .._hasData = false
          ..dataUpdatedAt = null
          ..error = null
          .._notify();
      }
    }
  }

  /// The app came back to the foreground or the network returned: refresh what is on screen.
  void refetchStaleObserved() {
    final now = DateTime.now();
    for (final e in _entries.values.toList()) {
      if (e.hasEnabledObservers && e.isStale(now)) unawaited(e.fetch());
    }
  }

  Iterable<QueryEntry<Object?>> _matching(QueryKey prefix, {bool exact = false}) =>
      _entries.values.where((e) => keyMatches(e.key, prefix, exact: exact)).toList();

  void _remove(QueryEntry<Object?> e) {
    if (e.hasObservers) return;
    _entries.remove(hashKey(e.key));
    e.dispose();
  }
}

/// The app's cache.
final QueryClient queryClient = QueryClient();

/// Pages of a newest-first list with a `before` cursor (TanStack `InfiniteData`).
@immutable
class InfiniteData<P> {
  const InfiniteData(this.pages, this.pageParams);
  final List<P> pages;
  final List<String?> pageParams;

  InfiniteData<P> copyWithPages(List<P> pages) => InfiniteData(pages, pageParams);
}
