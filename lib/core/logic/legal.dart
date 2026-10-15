import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/profile.dart';
import '../i18n/i18n.dart';

/// Privacy policy and terms of use (M10, docs/17). The texts and versions come from
/// `packages/shared/src/legal` (exported to assets/data/legal.json), so the app, the API's public page
/// and the React Native app always show the same content.
enum LegalDocument { privacy, terms }

/// Current versions; loaded from the asset at start-up (must match the API's LEGAL_VERSIONS).
({String privacy, String terms}) legalVersions = (privacy: '2026-10-05', terms: '2026-10-05');
Map<String, Object?> _markdown = const {};

Future<void> loadLegal({AssetBundle? bundle}) async {
  final json = jsonDecode(await (bundle ?? rootBundle).loadString('assets/data/legal.json')) as Map<String, Object?>;
  final versions = json['versions']! as Map<String, Object?>;
  legalVersions = (privacy: versions['privacy']! as String, terms: versions['terms']! as String);
  _markdown = json['markdown']! as Map<String, Object?>;
}

String legalMarkdown(LegalDocument document, Language language) =>
    ((_markdown[document.name] as Map<String, Object?>?)?[language.name] as String?) ?? '';

List<LegalBlock> legalBlocks(LegalDocument document, Language language) =>
    parseLegalMarkdown(legalMarkdown(document, language));

/// Has the user accepted the current versions? Null (never accepted) counts as outdated.
bool legalAcceptanceCurrent(LegalAcceptance accepted) =>
    accepted.termsVersion == legalVersions.terms && accepted.privacyVersion == legalVersions.privacy;

class LegalInline {
  const LegalInline(this.text, {this.bold = false, this.href});
  final String text;
  final bool bold;

  /// Only http(s) and mailto links are kept.
  final String? href;

  @override
  bool operator ==(Object other) =>
      other is LegalInline && other.text == text && other.bold == bold && other.href == href;

  @override
  int get hashCode => Object.hash(text, bold, href);

  @override
  String toString() => 'LegalInline($text, bold: $bold, href: $href)';
}

sealed class LegalBlock {
  const LegalBlock();
}

class LegalHeading extends LegalBlock {
  const LegalHeading(this.level, this.content);
  final int level;
  final List<LegalInline> content;
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.content);
  final List<LegalInline> content;
}

class LegalList extends LegalBlock {
  const LegalList(this.items);
  final List<List<LegalInline>> items;
}

final _safeLink = RegExp(r'^(https?://|mailto:)', caseSensitive: false);
final _inline = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)\s]+)\)');

/// The tiny Markdown subset of the legal texts (port of `packages/shared/src/legal/markdown.ts`):
/// `#`–`###` headings, paragraphs, `- ` lists, `**bold**` and `[text](https://…|mailto:…)`.
List<LegalInline> parseInline(String text) {
  final out = <LegalInline>[];
  var last = 0;
  for (final m in _inline.allMatches(text)) {
    if (m.start > last) out.add(LegalInline(text.substring(last, m.start)));
    if (m.group(1) != null) {
      out.add(LegalInline(m.group(1)!, bold: true));
    } else if (m.group(2) != null && m.group(3) != null) {
      out.add(_safeLink.hasMatch(m.group(3)!) ? LegalInline(m.group(2)!, href: m.group(3)) : LegalInline(m.group(2)!));
    }
    last = m.end;
  }
  if (last < text.length) out.add(LegalInline(text.substring(last)));
  return out;
}

List<LegalBlock> parseLegalMarkdown(String markdown) {
  final blocks = <LegalBlock>[];
  var paragraph = <String>[];
  var list = <String>[];

  void flush() {
    if (paragraph.isNotEmpty) blocks.add(LegalParagraph(parseInline(paragraph.join(' '))));
    if (list.isNotEmpty) blocks.add(LegalList(list.map(parseInline).toList()));
    paragraph = [];
    list = [];
  }

  for (final raw in markdown.replaceAll(RegExp(r'\r\n?'), '\n').split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }
    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      flush();
      blocks.add(LegalHeading(heading.group(1)!.length, parseInline(heading.group(2)!)));
      continue;
    }
    final item = RegExp(r'^[-*]\s+(.*)$').firstMatch(line);
    if (item != null) {
      if (paragraph.isNotEmpty) flush();
      list.add(item.group(1)!);
      continue;
    }
    if (list.isNotEmpty) flush();
    paragraph.add(line);
  }
  flush();
  return blocks;
}

/// Plain text of inline content (accessibility labels, tests).
String inlineText(List<LegalInline> content) => content.map((c) => c.text).join();
