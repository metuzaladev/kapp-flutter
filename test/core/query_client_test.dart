import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/api/api_client.dart';
import 'package:kapp/core/query/query_client.dart';

void main() {
  test('keys match by prefix and by value', () {
    expect(keyMatches(['parks', 'detail', 'a'], ['parks']), isTrue);
    expect(
      keyMatches(
        [
          'parks',
          'nearby',
          {'lat': 1},
        ],
        [
          'parks',
          'nearby',
          {'lat': 1},
        ],
      ),
      isTrue,
    );
    expect(keyMatches(['parks'], ['parks', 'detail']), isFalse);
    expect(keyMatches(['parks', 'a'], ['parks'], exact: true), isFalse);
  });

  test('4xx answers are final, other errors retry twice', () {
    expect(shouldRetry(0, const ApiRequestError('x', 404)), isFalse);
    expect(shouldRetry(0, const ApiRequestError('x', 0)), isTrue);
    expect(shouldRetry(2, const ApiRequestError('x', 500)), isFalse);
  });

  test('fetches once for concurrent callers and stores the data', () async {
    final client = QueryClient(testMode: true);
    var calls = 0;
    final entry = client.entry<int>(['n'])..fetcher = () async => ++calls;
    await Future.wait([entry.fetch(), entry.fetch()]);
    expect(calls, 1);
    expect(client.getQueryData<int>(['n']), 1);
  });

  test('invalidation refetches only queries a screen is showing', () async {
    final client = QueryClient(testMode: true);
    var shown = 0, hidden = 0;
    final a = client.entry<int>(['parks', 'a'])..fetcher = () async => ++shown;
    final b = client.entry<int>(['parks', 'b'])..fetcher = () async => ++hidden;
    a.addObserver(QueryObserver(enabled: true));
    await a.fetch();
    await b.fetch();
    client.invalidateQueries(['parks']);
    await Future<void>.delayed(Duration.zero);
    expect(shown, 2);
    expect(hidden, 1);
    expect(b.isStale(), isTrue);
  });

  test('a cancelled fetch cannot overwrite an optimistic update', () async {
    final client = QueryClient(testMode: true);
    final entry = client.entry<String>(['post'])
      ..fetcher = () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'server';
      };
    final running = entry.fetch();
    client.cancelQueries(['post']);
    client.setQueryData<String>(['post'], (_) => 'optimistic');
    await running;
    expect(client.getQueryData<String>(['post']), 'optimistic');
  });

  test('clear() forgets every user\'s data', () async {
    final client = QueryClient(testMode: true);
    client.setQueryData<int>(['me'], (_) => 1);
    client.clear();
    expect(client.getQueryData<int>(['me']), isNull);
  });
}
