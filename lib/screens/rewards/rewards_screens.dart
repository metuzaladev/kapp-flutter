import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/chip.dart';
import '../../components/icon.dart';
import '../../components/list_row.dart';
import '../../components/park_map.dart';
import '../../components/photo_tile.dart';
import '../../components/pills.dart';
import '../../components/pressable.dart';
import '../../components/screen.dart';
import '../../components/segmented_control.dart';
import '../../components/service_cards.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../components/text_field.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/i18n/i18n.dart';
import '../../core/logic/map_categories.dart';
import '../../core/logic/rewards.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/dialogs.dart';
import '../../hooks/account.dart';
import '../../hooks/device_location.dart';
import '../../hooks/services.dart';
import '../../models/explore.dart';
import '../../models/services.dart';
import '../../state/explore_view.dart';

/// Monospace for codes (invite and redemption), so "0" and "O" are told apart.
String get _mono => Platform.isIOS ? 'Menlo' : 'monospace';

String _delta(BuildContext context, RewardEntry entry) =>
    '${context.t('rewards.historyDelta', params: {'delta': '${entry.delta > 0 ? '+' : '−'}${formatNumber(entry.delta.abs())}'})} · ${formatNumericDate(entry.createdAt)}';

/// "+5" pill like the Figma Points Badge, with a server amount. Decorative: the row says it.
class _PlusPoints extends StatelessWidget {
  const _PlusPoints({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.only(left: Spacing.two, right: 12, top: 6, bottom: 6),
      decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(IconName.pawPrint, size: 16, color: c.brand),
          const SizedBox(width: 4),
          AppText(
            context.t('rewards.plus', params: {'points': formatNumber(points)}),
            type: TextType.label,
            color: c.accent,
          ),
        ],
      ),
    );
  }
}

/// Figma "Card / Balance": brand fill, "Saldo", level pill, the big number, progress, paw watermark.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});
  final RewardsSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final level = summary.level;
    final levelName = context.t(levelNameKey(level.id));
    final toNext = level.next != null
        ? context.t(
            'rewards.toNext',
            params: {'paws': pawsLabel(level.next!.pointsToGo), 'level': context.t(levelNameKey(level.next!.id))},
          )
        : context.t('rewards.topLevel');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(Radii.r24)),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -20,
            child: Opacity(opacity: 0.12, child: AppIcon(IconName.pawPrint, size: 176, color: c.onBrand)),
          ),
          Semantics(
            label: context.t(
              'rewards.balanceA11y',
              params: {
                'paws': pawsLabel(summary.balance),
                'level': levelName,
                'number': levelNumber(level.index),
                'next': toNext,
              },
            ),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Spacing.two,
                    runSpacing: Spacing.two,
                    children: [
                      AppText(context.t('rewards.balance'), type: TextType.label, color: c.onBrand),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.full),
                          border: Border.all(color: c.onBrand),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(IconName.trophy, size: 14, color: c.onBrand),
                            const SizedBox(width: 6),
                            AppText(
                              context.t(
                                'rewards.levelPill',
                                params: {'level': levelName, 'number': levelNumber(level.index)},
                              ),
                              type: TextType.caption,
                              color: c.onBrand,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.three),
                  Wrap(
                    spacing: Spacing.two,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      AppText(formatNumber(summary.balance), type: TextType.display, color: c.onBrand),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppText(
                          context.t('rewards.pawsWord', count: summary.balance),
                          type: TextType.heading,
                          color: c.onBrand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.three),
                  ProgressBar(value: level.progress, track: c.onBrand.withValues(alpha: 0.25), fill: c.onBrand),
                  const SizedBox(height: Spacing.three),
                  AppText(toNext, type: TextType.caption, color: c.onBrand),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma "Card / Streak" + "Streak Tile": the last seven Tallinn days as paws, today last.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary});
  final RewardsSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = streakDays(summary.streakLastDays, weekdayLetterIn(context.language.intlLocale));
    final perDay = pointsFor(summary, RewardReason.streak);
    final active = days.where((d) => d.active).length;
    return Container(
      padding: const EdgeInsets.all(Spacing.three),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.r24),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  summary.streakCurrent > 0
                      ? context.t('rewards.streak', count: summary.streakCurrent)
                      : context.t('rewards.streakNone'),
                  type: TextType.heading,
                ),
              ),
              if (perDay != null)
                AppText(
                  context.t('rewards.perDay', params: {'points': formatNumber(perDay)}),
                  type: TextType.caption,
                  themeColor: TextColor.muted,
                ),
            ],
          ),
          const SizedBox(height: Spacing.three),
          Semantics(
            label: context.t('rewards.weekA11y', count: active),
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final day in days)
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: day.active ? c.brand : c.background,
                          borderRadius: BorderRadius.circular(12),
                          border: day.active ? null : Border.all(color: c.border),
                        ),
                        alignment: Alignment.center,
                        child: AppIcon(IconName.pawPrint, size: 18, color: day.active ? c.onBrand : c.muted),
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        day.letter,
                        type: day.isToday ? TextType.label : TextType.caption,
                        themeColor: day.isToday ? TextColor.text : TextColor.muted,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends HookWidget {
  const _InviteCard();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final invite = useInvite();
    final claim = useClaimInvite();
    final code = useTextEditingController();
    final typed = useValueListenable(code).text;
    final error = useState<String?>(null);
    final claimed = useState(false);
    final data = invite.data;
    if (data == null) return invite.error != null ? FormError(errorMessage(invite.error)) : const SizedBox.shrink();

    Future<void> submitClaim() async {
      final value = code.text.trim().toUpperCase();
      if (!inviteCodePattern.hasMatch(value)) {
        error.value = I18n.instance.shared('validation.inviteCode');
        return;
      }
      error.value = null;
      try {
        await claim.mutateAsync(value);
        haptic(HapticReason.success);
        claimed.value = true;
        if (context.mounted) announce(context, context.t('rewards.invite.claimed'));
      } catch (e) {
        haptic(HapticReason.error);
        error.value = errorMessage(e);
      }
    }

    return Container(
      padding: const EdgeInsets.all(Spacing.three),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.r24),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(context.t('rewards.invite.title'), type: TextType.heading),
                const SizedBox(height: Spacing.one),
                AppText(
                  context.t('rewards.invite.body', params: {'paws': pawsLabel(data.points)}),
                  themeColor: TextColor.muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.three),
          Semantics(
            label: context.t('rewards.invite.codeA11y', params: {'code': data.code.split('').join(' ')}),
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Spacing.three),
              decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
              alignment: Alignment.center,
              child: SelectableText(
                data.code,
                style: textStyle(TextType.title, color: c.accent).copyWith(fontFamily: _mono, letterSpacing: 4),
              ),
            ),
          ),
          const SizedBox(height: Spacing.three),
          AppButton(
            label: context.t('rewards.invite.share'),
            trailingIcon: IconName.share,
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: context.t('rewards.invite.shareMessage', params: {'code': data.code})),
            ),
          ),
          const SizedBox(height: Spacing.three),
          if (claimed.value)
            Semantics(
              liveRegion: true,
              child: AppText(context.t('rewards.invite.claimed'), themeColor: TextColor.muted),
            )
          else ...[
            AppTextField(
              label: context.t('rewards.invite.claimLabel'),
              placeholder: context.t('rewards.invite.claimPlaceholder'),
              controller: code,
              capitalization: TextCapitalization.characters,
              autocorrect: false,
              maxLength: 8,
              error: error.value,
            ),
            const SizedBox(height: Spacing.two),
            AppButton(
              label: context.t('rewards.invite.claim'),
              variant: ButtonVariant.secondary,
              loading: claim.isPending,
              onPressed: typed.trim().isEmpty ? null : submitClaim,
            ),
          ],
        ],
      ),
    );
  }
}

/// Figma 09 / Rewards / Käpad (84:8169): balance and level, "Kasuta poes", the week's streak,
/// "Kuidas teenida" (amounts and limits from the server's rule table), badges, recent history, the
/// invite code and "Ausus ennekõike". Opening the screen also settles pending awards on the server.
class RewardsScreen extends HookWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rewards = useRewards();
    final history = useRewardHistory();
    final summary = rewards.data;
    final recent = (history.pages.firstOrNull?.items ?? const <RewardEntry>[]).take(4).toList();

    return AppScreen(
      navBar: true,
      title: context.t('rewards.title'),
      subtitle: context.t('rewards.subtitle'),
      onRefresh: () => refreshAll([rewards.refetch, history.refetch]),
      children: [
        const OfflineBanner(),
        if (rewards.error != null && summary == null)
          ErrorState(message: errorMessage(rewards.error), onRetry: rewards.refetch, retrying: rewards.isFetching),
        if (rewards.isPending && rewards.error == null) const SkeletonList(rows: 3, rowHeight: 120),
        if (summary != null) ...[
          Entering(child: _BalanceCard(summary: summary)),
          AppButton(
            label: context.t('rewards.useInShop'),
            variant: ButtonVariant.secondary,
            trailingIcon: IconName.arrowRight,
            onPressed: () => context.push('/shop'),
          ),
          Entering(index: 1, child: _StreakCard(summary: summary)),
          AppText(context.t('rewards.howToEarn'), type: TextType.heading, header: true),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.r24),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Column(
              children: [
                for (final (i, way) in summary.waysToEarn.indexed) ...[
                  if (i > 0) Divider(height: 0.5, thickness: 0.5, color: c.border),
                  Builder(
                    builder: (context) {
                      final title = context.t(reasonTitleKey(way.reason));
                      final body = way.dailyLimit != null
                          ? context.t(
                              'rewards.withLimit',
                              count: way.dailyLimit,
                              params: {'body': context.t(reasonBodyKey(way.reason))},
                            )
                          : context.t(reasonBodyKey(way.reason));
                      return Semantics(
                        label:
                            '$title, $body, ${context.t('rewards.plusA11y', params: {'paws': pawsLabel(way.points)})}',
                        excludeSemantics: true,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 68),
                          padding: const EdgeInsets.symmetric(horizontal: Spacing.three, vertical: 12),
                          child: Row(
                            children: [
                              AppIcon(reasonIcon[way.reason]!, size: 24, color: c.text),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(title, type: TextType.label),
                                    AppText(body, type: TextType.caption, themeColor: TextColor.muted),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _PlusPoints(points: way.points),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          AppText(context.t('rewards.badgesTitle'), type: TextType.heading, header: true),
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: Spacing.two,
              runSpacing: Spacing.two,
              children: [
                for (final badge in summary.badges)
                  SizedBox(
                    width: (box.maxWidth - Spacing.two) / 2,
                    child: Semantics(
                      label:
                          '${context.t(badgeNameKey(badge.id))}, ${context.t(badgeBodyKey(badge.id))}, ${badge.unlocked ? context.t('rewards.badgeUnlocked') : context.t('rewards.badgeProgress', params: {'progress': badge.progress, 'target': badge.target})}',
                      excludeSemantics: true,
                      child: Container(
                        padding: const EdgeInsets.all(Spacing.three),
                        decoration: BoxDecoration(
                          color: badge.unlocked ? c.soft : c.surface,
                          borderRadius: BorderRadius.circular(Radii.r16),
                          border: Border.all(color: badge.unlocked ? c.brand : c.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: badge.unlocked ? c.brand : c.background,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: AppIcon(
                                badge.unlocked ? badgeIcon[badge.id]! : IconName.lock,
                                size: 22,
                                color: badge.unlocked ? c.onBrand : c.muted,
                              ),
                            ),
                            const SizedBox(height: Spacing.two),
                            AppText(context.t(badgeNameKey(badge.id)), type: TextType.label),
                            const SizedBox(height: Spacing.one),
                            AppText(
                              context.t(badgeBodyKey(badge.id)),
                              type: TextType.caption,
                              themeColor: TextColor.muted,
                            ),
                            const SizedBox(height: Spacing.one),
                            ProgressBar(
                              value: badgeProgress(
                                unlocked: badge.unlocked,
                                progress: badge.progress,
                                target: badge.target,
                              ),
                              track: c.border,
                              fill: c.brand,
                              height: 6,
                            ),
                            const SizedBox(height: Spacing.one),
                            AppText(
                              badge.unlocked
                                  ? context.t('rewards.badgeUnlocked')
                                  : context.t(
                                      'rewards.badgeProgressShort',
                                      params: {'progress': badge.progress, 'target': badge.target},
                                    ),
                              type: TextType.caption,
                              themeColor: badge.unlocked ? TextColor.accent : TextColor.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AppText(context.t('rewards.historyTitle'), type: TextType.heading, header: true),
          if (history.isPending && history.error == null)
            const SkeletonList(rows: 2)
          else if (recent.isEmpty)
            AppText(context.t('rewards.historyEmpty'), themeColor: TextColor.muted)
          else ...[
            for (final entry in recent)
              ListRow(
                icon: reasonIcon[entry.reason],
                title: context.t(reasonTitleKey(entry.reason)),
                subtitle: _delta(context, entry),
              ),
            AppButton(
              label: context.t('rewards.historyAll'),
              variant: ButtonVariant.tertiary,
              onPressed: () => context.push('/rewards/history'),
            ),
          ],
          const _InviteCard(),
          InfoCard(title: context.t('rewards.honestyTitle'), body: context.t('rewards.honestyBody')),
        ],
      ],
    );
  }
}

/// Käpad history: every ledger entry, newest first (earned +, spent −, refunds). Not a Figma frame.
class RewardHistoryScreen extends HookWidget {
  const RewardHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = useRewardHistory();
    final items = [for (final p in history.pages) ...p.items];
    return AppScreen(
      navBar: true,
      title: context.t('rewards.historyTitle'),
      subtitle: context.t('rewards.historySubtitle'),
      onRefresh: history.refetch,
      children: [
        const OfflineBanner(),
        if (history.error != null && history.data == null)
          ErrorState(message: errorMessage(history.error), onRetry: history.refetch, retrying: history.isFetching),
        if (history.isPending && history.error == null) const SkeletonList(),
        if (history.data != null && items.isEmpty) EmptyState(title: context.t('rewards.historyEmpty')),
        for (final (i, entry) in items.indexed)
          Entering(
            index: i,
            child: ListRow(
              icon: reasonIcon[entry.reason],
              title: context.t(reasonTitleKey(entry.reason)),
              subtitle: _delta(context, entry),
            ),
          ),
        if (history.hasNextPage)
          AppButton(
            label: context.t('notifications.more'),
            variant: ButtonVariant.secondary,
            loading: history.isFetchingNextPage,
            onPressed: history.fetchNextPage,
          ),
      ],
    );
  }
}

/// Figma category tiles (Hooldus, Treening, Tervis). The photos are the bundled sample dogs:
/// illustrations of a service kind, never presented as a user or a partner.
const _serviceTiles = [
  (category: ServiceCategory.grooming, image: 'assets/images/sample-dogs/bella.jpg'),
  (category: ServiceCategory.training, image: 'assets/images/sample-dogs/charlie.jpg'),
  (category: ServiceCategory.vet, image: 'assets/images/sample-dogs/luna.jpg'),
];

const _productIcon = {
  ProductCategory.food: IconName.shoppingBag,
  ProductCategory.treats: IconName.cookie,
  ProductCategory.toys: IconName.sparkles,
  ProductCategory.accessories: IconName.dog,
  ProductCategory.care: IconName.droplet,
};

/// Figma "List Row / Käpakoda": photo, name, "Hooldus · Kadriorg · alates 12 €", "−15%".
class _PartnerRow extends StatelessWidget {
  const _PartnerRow({required this.partner});
  final ShopPartner partner;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final meta = [
      context.t('services.categories.${partner.category.name}'),
      partner.area,
      ?formatKm(partner.distanceKm),
      if (partner.priceFromCents != null) priceLabel(partner.priceFromCents!, true),
    ].join(' · ');
    return Pressable(
      semanticLabel:
          '${partner.name}, $meta, ${context.t('shop.discountA11y', params: {'percent': partner.pawDiscountPercent, 'paws': pawsLabel(partner.pointsCost)})}',
      semanticHint: context.t('shop.partnerHint'),
      onPressed: () => context.push('/services/${partner.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(Spacing.three),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.r16),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            if (partner.photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SignedImage(partner.photoUrl!, width: 48, height: 48),
              )
            else
              PhotoTile(name: partner.name, size: 48, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(partner.name, type: TextType.label),
                  AppText(meta, type: TextType.caption, themeColor: TextColor.muted),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DiscountPill(percent: partner.pawDiscountPercent),
          ],
        ),
      ),
    );
  }
}

Widget _productGrid(BuildContext context, List<Product> products) => LayoutBuilder(
  builder: (context, box) => Wrap(
    spacing: 14,
    runSpacing: 14,
    children: [
      for (final p in products)
        SizedBox(
          width: (box.maxWidth - 14) / 2,
          child: ProductCard(product: p, onPressed: () => context.push('/shop/${p.id}')),
        ),
    ],
  ),
);

/// Figma 09 / Marketplace / Pood (85:8362): Teenused / Tooted, the balance, category tiles, the
/// partners on a mini map, partners with paw discounts and partner products. No payments: points buy
/// a single-use discount code that the partner checks in person (docs/16).
class ShopScreen extends HookWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final location = useDeviceLocation();
    final shop = useShop(location.usingFallback ? null : location.origin);
    final tab = useState('services');
    final productCategory = useState<ProductCategory?>(null);
    final products = useProducts(productCategory.value);
    final balance = usePointsBalance();
    final data = shop.data;
    // The largest discount on offer, from the data (falls back to the rule's maximum while loading).
    final discounts = [
      ...?data?.partners.map((p) => p.pawDiscountPercent),
      ...?data?.products.map((p) => p.discountPercent),
    ];
    final maxDiscount = discounts.isEmpty ? maxDiscountPercent : discounts.reduce((a, b) => a > b ? a : b);

    void openMap() {
      // The Kaart tab opens on the map with the Teenused chip selected.
      focusMap(category: MapCategory.services);
      context.go('/map');
    }

    return AppScreen(
      navBar: true,
      title: context.t('shop.title'),
      subtitle: context.t('shop.subtitle'),
      onRefresh: () => refreshAll([shop.refetch, products.refetch]),
      children: [
        const OfflineBanner(),
        SegmentedControl<String>(
          semanticLabel: context.t('shop.title'),
          options: [
            (value: 'services', label: context.t('shop.tabServices')),
            (value: 'products', label: context.t('shop.tabProducts')),
          ],
          value: tab.value,
          onChanged: (v) {
            if (v != null) tab.value = v;
          },
        ),
        if (balance != null)
          Pressable(
            semanticLabel:
                '${context.t('shop.balance', params: {'paws': pawsLabel(balance)})}, ${context.t('shop.balanceSub', params: {'percent': maxDiscount})}',
            semanticHint: context.t('points.openHint'),
            onPressed: () => context.push('/rewards'),
            child: Container(
              padding: const EdgeInsets.all(Spacing.three),
              decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          context.t('shop.balance', params: {'paws': pawsLabel(balance)}),
                          type: TextType.heading,
                        ),
                        AppText(
                          context.t('shop.balanceSub', params: {'percent': maxDiscount}),
                          type: TextType.caption,
                          themeColor: TextColor.muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.three),
                  AppIcon(IconName.pawPrint, size: 28, color: c.brand),
                ],
              ),
            ),
          ),
        ListRow(
          icon: IconName.ticket,
          title: context.t('shop.myCodes'),
          subtitle: context.t('shop.myCodesSub'),
          onPressed: () => context.push('/redemptions'),
        ),
        if (shop.error != null && data == null)
          ErrorState(message: errorMessage(shop.error), onRetry: shop.refetch, retrying: shop.isFetching),
        if (shop.isPending && shop.error == null) const SkeletonList(rows: 3, rowHeight: 96),
        if (data != null && tab.value == 'services') ...[
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                for (final tile in _serviceTiles) ...[
                  Pressable(
                    semanticLabel: context.t('shop.tiles.${tile.category.name}'),
                    semanticHint: context.t('shop.tileHint'),
                    onPressed: () => context.push('/services?category=${tile.category.name}'),
                    child: Container(
                      width: 124,
                      height: 96,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.r16)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(tile.image, fit: BoxFit.cover),
                          Container(color: const Color(0x47000000)),
                          // White on a darkened photo (Figma); not a theme colour because the photo is the background.
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: AppText(
                                context.t('shop.tiles.${tile.category.name}'),
                                type: TextType.label,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: AppText(context.t('shop.nearbyMap'), type: TextType.heading, header: true)),
              Pressable(
                semanticLabel: context.t('shop.openMap'),
                semanticHint: context.t('shop.openMapHint'),
                onPressed: openMap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  child: AppText(context.t('shop.openMap'), type: TextType.label, color: c.accent),
                ),
              ),
            ],
          ),
          // The preview opens the map too; screen readers reach the same action through "Ava kaart".
          ExcludeSemantics(
            child: GestureDetector(
              onTap: openMap,
              child: MiniMap(
                center: location.origin,
                pins: [
                  for (final p in data.partners)
                    (id: p.id, lat: p.lat, lng: p.lng, kind: providerPlaceKind(p.category)),
                ],
              ),
            ),
          ),
          AppText(context.t('shop.popularServices'), type: TextType.heading, header: true),
          if (data.partners.isEmpty) EmptyState(title: context.t('shop.noPartners')),
          for (final partner in data.partners) _PartnerRow(partner: partner),
          if (data.products.isNotEmpty) ...[
            AppText(context.t('shop.partnerProducts'), type: TextType.heading, header: true),
            _productGrid(context, data.products.take(4).toList()),
            AppButton(
              label: context.t('shop.allProducts'),
              variant: ButtonVariant.tertiary,
              onPressed: () => tab.value = 'products',
            ),
          ],
        ],
        if (data != null && tab.value == 'products') ...[
          ChipRow(
            children: [
              IconChip(
                radio: true,
                icon: IconName.layers,
                label: context.t('shop.productCategories.all'),
                selected: productCategory.value == null,
                onPressed: () => productCategory.value = null,
              ),
              for (final cat in data.categories.where((cat) => cat.productCount > 0))
                IconChip(
                  radio: true,
                  icon: _productIcon[cat.id]!,
                  label: context.t('shop.productCategories.${cat.id.name}'),
                  selected: productCategory.value == cat.id,
                  onPressed: () => productCategory.value = cat.id,
                ),
            ],
          ),
          if (products.error != null && products.data == null)
            ErrorState(message: errorMessage(products.error), onRetry: products.refetch, retrying: products.isFetching),
          if (products.isPending && products.error == null) const SkeletonList(rows: 2, rowHeight: 200),
          if (products.data?.isEmpty ?? false) EmptyState(title: context.t('shop.noProducts')),
          _productGrid(context, products.data ?? const []),
        ],
        AppText(context.t('shop.noPayments'), type: TextType.caption, themeColor: TextColor.muted),
      ],
    );
  }
}

/// A partner product: price at the partner, the paw discount and "Lunasta X käpaga", which spends
/// the points for a single-use code (no payment in the app). All amounts come from the server.
class ProductScreen extends HookWidget {
  const ProductScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final query = useProduct(productId);
    final balance = usePointsBalance();
    final redeem = useRedeemOnce();
    final error = useState<String?>(null);
    final product = query.data;

    if (product == null) {
      return AppScreen(
        navBar: true,
        children: [
          if (query.error != null)
            ErrorState(message: errorMessage(query.error), onRetry: query.refetch, retrying: query.isFetching),
          if (query.isPending && query.error == null) const SkeletonList(rows: 2, rowHeight: 160),
        ],
      );
    }

    final short = balance != null ? product.pointsCost - balance : 0;

    void confirm() {
      error.value = null;
      showAlert(
        context,
        context.t('shop.confirmTitle'),
        message: context.t(
          'shop.confirmBody',
          count: redemptionValidDays,
          params: {
            'paws': pawsLabel(product.pointsCost),
            'percent': product.discountPercent,
            'partner': product.provider.name,
          },
        ),
        actions: [
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
          AlertAction(
            context.t('shop.confirmAction'),
            onPressed: () async {
              try {
                final redemption = await redeem.run(offerType: 'product', offerId: product.id);
                haptic(HapticReason.success);
                if (context.mounted) context.pushReplacement('/redemptions/${redemption.id}?fresh=1');
              } catch (e) {
                // 409 "Käppasid ei ole piisavalt: vaja 150, sul on 40" — already in the user's language.
                haptic(HapticReason.error);
                error.value = errorMessage(e);
              }
            },
          ),
        ],
      );
    }

    Widget row(Widget left, Widget right) => Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: Spacing.two),
        right,
      ],
    );

    return AppScreen(
      navBar: true,
      title: product.name,
      subtitle: '${product.provider.name} · ${product.provider.area}',
      children: [
        const OfflineBanner(),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r24)),
            child: product.imageUrl != null
                ? SignedImage(product.imageUrl!)
                : Center(child: AppIcon(IconName.shoppingBag, size: 56, color: c.brand)),
          ),
        ),
        if (product.description != null) AppText(product.description!),
        MergeSemantics(
          child: Container(
            padding: const EdgeInsets.all(Spacing.three),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.r16),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Column(
              children: [
                row(
                  AppText(context.t('shop.priceAtPartner'), themeColor: TextColor.muted),
                  AppText(formatPrice(product.priceCents), type: TextType.label),
                ),
                const SizedBox(height: Spacing.two),
                row(
                  Wrap(
                    spacing: Spacing.two,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppText(context.t('shop.priceWithPaws'), themeColor: TextColor.muted),
                      DiscountPill(percent: product.discountPercent),
                    ],
                  ),
                  AppText(formatPrice(product.discountedPriceCents), type: TextType.heading),
                ),
                const SizedBox(height: Spacing.two),
                row(
                  AppText(context.t('shop.cost'), themeColor: TextColor.muted),
                  AppText(pawsLabel(product.pointsCost), type: TextType.label),
                ),
              ],
            ),
          ),
        ),
        FormError(error.value),
        if (balance != null)
          AppText(
            short > 0
                ? context.t('shop.short', params: {'paws': pawsLabel(short)})
                : context.t('shop.youHave', params: {'paws': pawsLabel(balance)}),
            themeColor: short > 0 ? TextColor.danger : TextColor.muted,
          ),
        AppButton(
          label: context.t(
            'shop.redeem',
            count: product.pointsCost,
            params: {'value': formatNumber(product.pointsCost)},
          ),
          loading: redeem.isPending,
          onPressed: short > 0 ? null : confirm,
        ),
        InfoCard(
          title: context.t('shop.howTitle'),
          body: context.t('shop.howBody', count: redemptionValidDays),
        ),
      ],
    );
  }
}

/// "Minu koodid": every discount code, newest first, with its status. Not a Figma frame.
class RedemptionsScreen extends HookWidget {
  const RedemptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final list = useRedemptions();
    return AppScreen(
      navBar: true,
      title: context.t('redemptions.title'),
      subtitle: context.t('redemptions.subtitle'),
      onRefresh: list.refetch,
      children: [
        const OfflineBanner(),
        if (list.error != null && list.data == null)
          ErrorState(message: errorMessage(list.error), onRetry: list.refetch, retrying: list.isFetching),
        if (list.isPending && list.error == null) const SkeletonList(),
        if (list.data?.isEmpty ?? false)
          EmptyState(
            title: context.t('redemptions.empty'),
            actionLabel: context.t('redemptions.toShop'),
            onAction: () => context.push('/shop'),
          ),
        for (final (i, r) in (list.data ?? const <Redemption>[]).indexed)
          Entering(
            index: i,
            child: ListRow(
              icon: IconName.ticket,
              title: redemptionTitle(r),
              subtitle: [
                r.provider.name,
                r.status == RedemptionStatus.active
                    ? context.t('redemptions.validUntil', params: {'date': formatNumericDate(r.expiresAt)})
                    : context.t('redemptions.status.${r.status.name}'),
              ].join(' · '),
              onPressed: () => context.push('/redemptions/${r.id}'),
            ),
          ),
      ],
    );
  }
}

/// The code to show at the partner (after "Lunasta" or from "Minu koodid"): the big single-use code,
/// the partner, "Kehtib kuni: …", how to use it and — while unused — "Tühista ja tagasta käpad".
/// There is no single-code endpoint, so it reads the list.
class RedemptionScreen extends HookWidget {
  const RedemptionScreen({super.key, required this.redemptionId, this.fresh = false});
  final String redemptionId;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final list = useRedemptions();
    final cancel = useCancelRedemption();
    final error = useState<String?>(null);
    final r = list.data?.where((x) => x.id == redemptionId).firstOrNull;

    if (r == null) {
      return AppScreen(
        navBar: true,
        children: [
          if (list.error != null)
            ErrorState(message: errorMessage(list.error), onRetry: list.refetch, retrying: list.isFetching),
          if (list.isPending && list.error == null) const SkeletonList(rows: 2, rowHeight: 120),
        ],
      );
    }

    void confirmCancel() {
      haptic(HapticReason.warning);
      showAlert(
        context,
        context.t('redemptions.cancelTitle'),
        message: context.t('redemptions.cancelBody', params: {'paws': pawsLabel(r.pointsCost)}),
        actions: [
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
          AlertAction(
            context.t('redemptions.cancelAction'),
            style: AlertStyle.destructive,
            onPressed: () async {
              error.value = null;
              try {
                await cancel.mutateAsync(r.id);
                if (context.mounted) {
                  announce(context, context.t('redemptions.cancelled', params: {'paws': pawsLabel(r.pointsCost)}));
                }
              } catch (e) {
                haptic(HapticReason.error);
                error.value = errorMessage(e);
              }
            },
          ),
        ],
      );
    }

    final active = r.status == RedemptionStatus.active;
    final status = context.t('redemptions.status.${r.status.name}');
    return AppScreen(
      navBar: true,
      title: redemptionTitle(r),
      subtitle: r.provider.name,
      children: [
        const OfflineBanner(),
        if (fresh && active) const Align(alignment: Alignment.centerLeft, child: SuccessMark()),
        FormError(error.value),
        Semantics(
          label: context.t('redemptions.codeA11y', params: {'code': r.code.split('').join(' '), 'status': status}),
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(Spacing.four),
            decoration: BoxDecoration(
              color: active ? c.brand : c.surface,
              borderRadius: BorderRadius.circular(Radii.r24),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Column(
              children: [
                AppText(
                  context.t('redemptions.codeLabel'),
                  type: TextType.caption,
                  color: active ? c.onBrand : c.muted,
                ),
                const SizedBox(height: Spacing.two),
                SelectableText(
                  r.code,
                  textAlign: TextAlign.center,
                  style: textStyle(
                    TextType.hero,
                    color: active ? c.onBrand : c.muted,
                  ).copyWith(fontFamily: _mono, letterSpacing: 4),
                ),
                const SizedBox(height: Spacing.two),
                AppText(status, type: TextType.label, color: active ? c.onBrand : c.text),
                if (active) ...[
                  const SizedBox(height: Spacing.two),
                  AppText(
                    context.t('redemptions.validUntil', params: {'date': formatNumericDate(r.expiresAt)}),
                    type: TextType.caption,
                    color: c.onBrand,
                  ),
                ],
              ],
            ),
          ),
        ),
        InfoCard(
          title: context.t('redemptions.howTitle'),
          body: r.offerType == 'product'
              ? context.t('redemptions.howProduct', params: {'partner': r.provider.name})
              : context.t('redemptions.howBooking', params: {'partner': r.provider.name}),
        ),
        if (active && r.offerType == 'booking')
          AppButton(
            label: context.t('redemptions.bookNow'),
            onPressed: () => context.push('/services/${r.provider.id}'),
          ),
        if (active)
          AppButton(
            label: context.t('redemptions.cancelAction'),
            variant: ButtonVariant.secondary,
            loading: cancel.isPending,
            onPressed: confirmCancel,
          ),
        AppButton(
          label: context.t('redemptions.allCodes'),
          variant: ButtonVariant.tertiary,
          onPressed: () => context.push('/redemptions'),
        ),
      ],
    );
  }
}
