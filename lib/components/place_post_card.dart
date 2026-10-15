import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/format.dart';
import '../core/haptics.dart';
import '../core/i18n/i18n.dart';
import '../core/logic/explore.dart';
import '../core/query/hooks.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import '../core/ui/dialogs.dart';
import '../hooks/explore.dart';
import '../models/explore.dart';
import '../state/explore_view.dart';
import 'icon.dart';
import 'park_cards.dart';
import 'photo_tile.dart';
import 'pressable.dart';
import 'text.dart';

/// What the post card's buttons do, shared by the Avasta feed, the post page and "Minu soovitused":
/// "Kaardil" switches the Kaart tab to the map centred on the place; "…" offers the safety flows for
/// others' posts (report the post, report the author) and deletion for the author's own.
class PlacePostActions {
  PlacePostActions(this.context, this._remove);
  final BuildContext context;
  final MutationHandle<String, void> _remove;

  void showOnMap(PlacePost post) {
    focusMap(lat: post.lat, lng: post.lng, category: mapCategoryForPost(post.category));
    context.go('/map');
  }

  void _confirmDelete(PlacePost post, VoidCallback? onDeleted) {
    haptic(HapticReason.warning);
    showAlert(
      context,
      tr('explore.delete.title'),
      message: tr('explore.delete.body', params: {'name': post.name}),
      actions: [
        AlertAction(tr('common.cancel'), style: AlertStyle.cancel),
        AlertAction(
          tr('common.delete'),
          style: AlertStyle.destructive,
          onPressed: () => _remove.mutate(
            post.id,
            onSuccess: (_) => onDeleted?.call(),
            onError: (e) => showAlert(context, tr('explore.delete.failed'), message: errorMessage(e)),
          ),
        ),
      ],
    );
  }

  void openMenu(PlacePost post, {VoidCallback? onDeleted}) {
    if (post.isMine) {
      showActionMenu(
        context,
        title: post.name,
        actions: [
          AlertAction(
            tr('explore.delete.action'),
            style: AlertStyle.destructive,
            onPressed: () => _confirmDelete(post, onDeleted),
          ),
          AlertAction(tr('common.cancel'), style: AlertStyle.cancel),
        ],
      );
      return;
    }
    showActionMenu(
      context,
      title: post.name,
      actions: [
        AlertAction(
          tr('explore.report.action'),
          onPressed: () => context.push(
            Uri(path: '/report-post', queryParameters: {'postId': post.id, 'name': post.name}).toString(),
          ),
        ),
        AlertAction(
          tr('explore.report.author', params: {'name': post.authorFirstName}),
          onPressed: () => context.push(
            Uri(
              path: '/report-user',
              queryParameters: {'userId': post.authorId, 'name': post.authorFirstName},
            ).toString(),
          ),
        ),
        AlertAction(tr('common.cancel'), style: AlertStyle.cancel),
      ],
    );
  }
}

PlacePostActions usePlacePostActions(BuildContext context) {
  final remove = useDeletePlacePost();
  return PlacePostActions(context, remove);
}

/// Small status pill: "Ootab kinnitust" (pending) / "Tagasi lükatud" (rejected) / "+15" earned.
class _Pill extends StatelessWidget {
  const _Pill({this.icon, required this.label, required this.soft});
  final IconName? icon;
  final String label;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: soft ? c.soft : c.background,
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[AppIcon(icon!, size: 14, color: soft ? c.brand : c.muted), const SizedBox(width: 4)],
          Text(label, style: textStyle(TextType.caption, color: soft ? c.accent : c.muted)),
        ],
      ),
    );
  }
}

/// Figma "Feed / Place Post" (58:152): author, photo with the category pill, place name, location,
/// amenity chips, text and the action row (heart + count, bookmark, "Kaardil").
class PlacePostCard extends HookWidget {
  const PlacePostCard({
    super.key,
    required this.post,
    this.earnedPoints,
    this.onOpen,
    required this.onShowOnMap,
    required this.onMore,
    this.expanded = false,
  });

  final PlacePost post;

  /// Points an approved recommendation earned (server rule table); shown on own approved posts.
  final int? earnedPoints;

  /// Opens the post (feed); omitted on the detail screen itself.
  final VoidCallback? onOpen;
  final VoidCallback onShowOnMap;
  final VoidCallback onMore;

  /// Detail screen: every photo and the full text.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final like = useTogglePostReaction(PostReaction.like);
    final save = useTogglePostReaction(PostReaction.save);
    final category = context.t('explore.categories.${post.category.name}');
    final location = [?post.address, ?formatKm(post.distanceKm)].join(' · ');
    final amenities = [for (final a in post.amenities) context.t('explore.amenities.${a.wire}')];
    final photos = expanded ? post.photos : post.photos.take(1).toList();
    final approved = post.status == PlacePostStatus.approved;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photos.isNotEmpty)
          Stack(
            children: [
              Column(
                children: [
                  for (final (i, photo) in photos.indexed) ...[
                    if (i > 0) const SizedBox(height: 2),
                    AspectRatio(aspectRatio: 340 / 230, child: SignedImage(photo.url)),
                  ],
                ],
              ),
              Positioned(
                top: 14,
                left: 14,
                child: CategoryPill(category: post.category, label: category),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.three, 14, Spacing.three, Spacing.two),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photos.isEmpty) ...[
                CategoryPill(category: post.category, label: category),
                const SizedBox(height: 10),
              ],
              AppText(post.name, type: TextType.title),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 10),
                AppText(location, type: TextType.caption, themeColor: TextColor.muted),
              ],
              if (post.amenities.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (i, a) in post.amenities.indexed)
                      Container(
                        padding: const EdgeInsets.only(left: 8, right: 10, top: 5, bottom: 5),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(Radii.full),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(amenityIcon[a]!, size: 14, color: c.text),
                            const SizedBox(width: 4),
                            AppText(amenities[i], type: TextType.caption),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (post.body != null) ...[
                const SizedBox(height: 10),
                AppText(post.body!, maxLines: expanded ? null : 4),
              ],
            ],
          ),
        ),
      ],
    );

    final openLabel = [
      post.name,
      category,
      if (location.isNotEmpty) location,
      if (amenities.isNotEmpty) amenities.join(', '),
    ].join(', ');
    final when = formatAgo(post.createdAt);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12, left: Spacing.three, right: Spacing.two),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: context.t('explore.post.byline', params: {'name': post.authorFirstName, 'when': when}),
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        PhotoTile(name: post.authorFirstName, size: 36, radius: 12),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                post.isMine ? context.t('explore.post.you') : post.authorFirstName,
                                type: TextType.label,
                                maxLines: 1,
                              ),
                              AppText(
                                context.t('explore.post.meta', params: {'when': when}),
                                type: TextType.caption,
                                themeColor: TextColor.muted,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (post.status == PlacePostStatus.pending)
                  _Pill(icon: IconName.clock, label: context.t('explore.post.pending'), soft: false),
                if (post.status == PlacePostStatus.rejected)
                  _Pill(icon: IconName.x, label: context.t('explore.post.rejected'), soft: false),
                if (post.isMine && approved && earnedPoints != null && earnedPoints! > 0)
                  Semantics(
                    label: context.t('explore.post.earned', count: earnedPoints),
                    excludeSemantics: true,
                    child: _Pill(
                      icon: IconName.pawPrint,
                      label: context.t('explore.post.earnedShort', params: {'points': formatNumber(earnedPoints!)}),
                      soft: true,
                    ),
                  ),
                Pressable(
                  semanticLabel: context.t('explore.post.more'),
                  onPressed: onMore,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: AppIcon(IconName.ellipsis, size: 22, color: c.muted)),
                  ),
                ),
              ],
            ),
          ),
          if (onOpen != null)
            Pressable(
              semanticLabel: openLabel,
              semanticHint: context.t('explore.post.openHint'),
              onPressed: onOpen,
              child: body,
            )
          else
            body,
          Padding(
            padding: const EdgeInsets.only(left: Spacing.two, right: Spacing.two, bottom: Spacing.two),
            child: Row(
              children: [
                Pressable(
                  semanticLabel: post.liked ? context.t('explore.post.unlike') : context.t('explore.post.like'),
                  semanticHint: context.t('explore.post.likes', count: post.likeCount),
                  selected: post.liked,
                  onPressed: approved
                      ? () {
                          haptic(HapticReason.selection);
                          like.mutate((postId: post.id, on: !post.liked));
                        }
                      : null,
                  child: _action([
                    AppIcon(
                      post.liked ? IconName.heartFilled : IconName.heart,
                      size: 22,
                      color: post.liked ? c.brand : c.text,
                    ),
                    AppText(formatNumber(post.likeCount), type: TextType.label),
                  ]),
                ),
                const SizedBox(width: Spacing.two),
                Pressable(
                  semanticLabel: post.saved ? context.t('explore.post.unsave') : context.t('explore.post.save'),
                  selected: post.saved,
                  onPressed: approved
                      ? () {
                          haptic(HapticReason.selection);
                          save.mutate((postId: post.id, on: !post.saved));
                        }
                      : null,
                  child: _action([
                    AppIcon(
                      post.saved ? IconName.bookmarkFilled : IconName.bookmark,
                      size: 22,
                      color: post.saved ? c.brand : c.text,
                    ),
                  ]),
                ),
                const Spacer(),
                Pressable(
                  semanticLabel: context.t('explore.post.onMap'),
                  semanticHint: context.t('explore.post.onMapHint'),
                  onPressed: onShowOnMap,
                  child: _action([
                    AppIcon(IconName.mapPin, size: 18, color: c.accent),
                    AppText(context.t('explore.post.onMap'), type: TextType.label, color: c.accent),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(List<Widget> children) => Container(
    constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
    padding: const EdgeInsets.symmetric(horizontal: Spacing.two),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(width: 6), w],
      ],
    ),
  );
}
