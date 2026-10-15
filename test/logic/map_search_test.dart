import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/components/icon.dart';
import 'package:kapp/core/logic/map_search.dart';

void main() {
  test('searchableQuery needs at least two letters and trims', () {
    expect(searchableQuery(''), isNull);
    expect(searchableQuery('  '), isNull);
    expect(searchableQuery('k'), isNull);
    expect(searchableQuery(' ka '), 'ka');
    expect(searchableQuery('Kotzebue 9'), 'Kotzebue 9');
  });

  group('stepZoom', () {
    test('zooms one whole level per tap', () {
      expect(stepZoom(12, 1), 13);
      expect(stepZoom(12, -1), 11);
    });

    test('snaps a pinched (fractional) zoom to the next whole level in the tapped direction', () {
      expect(stepZoom(12.4, 1), 13);
      expect(stepZoom(12.4, -1), 12);
      expect(stepZoom(12.9999999, 1), 14);
    });

    test('stays within the zoom range', () {
      expect(stepZoom(maxZoom, 1), maxZoom);
      expect(stepZoom(minZoom, -1), minZoom);
      expect(stepZoom(30, -1), maxZoom);
      expect(stepZoom(2, 1), minZoom);
    });
  });

  test('searchResultIcon by kind and category', () {
    expect(searchResultIcon('park', 'park'), IconName.trees);
    expect(searchResultIcon('park', 'beach'), IconName.waves);
    expect(searchResultIcon('provider', 'vet'), IconName.stethoscope);
    expect(searchResultIcon('provider', 'grooming'), IconName.scissors);
    expect(searchResultIcon('post', 'cafe'), IconName.coffee);
    expect(searchResultIcon('post', 'shop'), IconName.store);
    expect(searchResultIcon('post', null), IconName.store);
    expect(searchResultIcon('address', 'EHITISHOONE'), IconName.mapPin);
  });

  test('searchResultRoute leads to the page; addresses and missing ids have none', () {
    expect(searchResultRoute('park', 'p1'), '/parks/p1');
    expect(searchResultRoute('provider', 's1'), '/services/s1');
    expect(searchResultRoute('post', 'x1'), '/place-posts/x1');
    expect(searchResultRoute('address', null), isNull);
    expect(searchResultRoute('park', null), isNull);
  });
}
