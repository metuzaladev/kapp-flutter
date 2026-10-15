import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/logic/legal.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'text.dart';

/// The privacy policy / terms rendered from the shared Markdown blocks (M10, docs/17) — the same
/// source as the public web page, so the app and the store URL always say the same thing.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({super.key, required this.blocks});
  final List<LegalBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    TextSpan inline(List<LegalInline> content, TextStyle base) => TextSpan(
      style: base,
      children: [
        for (final part in content)
          TextSpan(
            text: part.text,
            style: TextStyle(
              fontWeight: part.bold ? FontWeight.w700 : null,
              color: part.href != null ? c.link : null,
              decoration: part.href != null ? TextDecoration.underline : null,
            ),
            recognizer: part.href == null
                ? null
                : (TapGestureRecognizer()
                    ..onTap = () => launchUrl(Uri.parse(part.href!), mode: LaunchMode.externalApplication)),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: blocks[i] is LegalHeading ? Spacing.three + Spacing.two : Spacing.three),
          switch (blocks[i]) {
            LegalHeading(:final level, :final content) => Semantics(
              header: true,
              child: Text.rich(
                inline(content, textStyle(level == 1 ? TextType.title : TextType.heading, color: c.text)),
              ),
            ),
            LegalParagraph(:final content) => Text.rich(inline(content, textStyle(TextType.body, color: c.text))),
            LegalList(:final items) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < items.length; j++) ...[
                  if (j > 0) const SizedBox(height: Spacing.two),
                  MergeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ExcludeSemantics(child: AppText('•', themeColor: TextColor.muted)),
                        const SizedBox(width: Spacing.two),
                        Expanded(child: Text.rich(inline(items[j], textStyle(TextType.body, color: c.text)))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          },
        ],
      ],
    );
  }
}
