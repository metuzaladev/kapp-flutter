import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/i18n/i18n.dart';
import 'package:kapp/core/logic/account.dart';
import 'package:kapp/core/logic/legal.dart';
import 'package:kapp/models/profile.dart';

Profile _profile({bool hasPassword = true, String? terms, String? privacy}) => Profile(
  id: 'u',
  name: 'Mari',
  email: 'mari@example.com',
  image: null,
  area: null,
  bio: null,
  presenceSharing: PresenceSharing.friends,
  allowFriendRequests: true,
  language: Language.et,
  emailVerified: true,
  hasPassword: hasPassword,
  legal: LegalAcceptance(termsVersion: terms, privacyVersion: privacy, acceptedAt: null),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadLegal);

  group('legal markdown', () {
    test('parses headings, paragraphs, lists, bold and safe links only', () {
      final blocks = parseLegalMarkdown(
        '# Title\n\nLine one\nline two **bold**.\n\n- [site](https://kapp.ee)\n- [bad](javascript:void)',
      );
      expect(blocks[0], isA<LegalHeading>());
      expect((blocks[0] as LegalHeading).level, 1);
      final p = blocks[1] as LegalParagraph;
      expect(inlineText(p.content), 'Line one line two bold.');
      expect(p.content.any((i) => i.bold && i.text == 'bold'), isTrue);
      final list = blocks[2] as LegalList;
      expect(list.items[0].single, const LegalInline('site', href: 'https://kapp.ee'));
      expect(list.items[1].single.href, isNull);
    });

    test('ships both documents in all three languages', () {
      for (final d in LegalDocument.values) {
        for (final l in Language.values) {
          expect(legalBlocks(d, l), isNotEmpty);
        }
      }
    });
  });

  group('account rules (M10)', () {
    test('password accounts confirm deletion with the password, social accounts sign in again', () {
      expect(reauthMode(_profile()), ReauthMode.password);
      expect(reauthMode(_profile(hasPassword: false)), ReauthMode.signIn);
      expect(deleteAccountBody(ReauthMode.password, 'x'), {'password': 'x'});
      expect(deleteAccountBody(ReauthMode.signIn, 'x'), <String, Object>{});
      expect(canRequestDeletion(ReauthMode.password, ''), isFalse);
      expect(canRequestDeletion(ReauthMode.signIn, ''), isTrue);
      expect(deletionMeansGone(401), isTrue);
      expect(deletionMeansGone(404), isTrue);
      expect(deletionMeansGone(500), isFalse);
    });

    test('asks for consent when the accepted versions are not the current ones', () {
      expect(needsLegalAcceptance(null), isFalse);
      expect(needsLegalAcceptance(_profile(terms: legalVersions.terms, privacy: legalVersions.privacy)), isFalse);
      expect(needsLegalAcceptance(_profile(terms: '2020-01-01', privacy: legalVersions.privacy)), isTrue);
      expect(legalConsentKind(_profile()), LegalConsentKind.newConsent);
      expect(legalConsentKind(_profile(terms: 'old', privacy: 'old')), LegalConsentKind.updated);
    });
  });
}
