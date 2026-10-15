import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/format.dart';
import '../core/i18n/i18n.dart';
import '../core/logic/explore.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import '../hooks/services.dart';
import '../models/explore.dart';
import '../models/services.dart';
import 'button.dart';
import 'chip.dart';
import 'icon.dart';
import 'photo_tile.dart';
import 'pills.dart';
import 'pressable.dart';
import 'states.dart';
import 'text.dart';

/// "teisipäev, 6. oktoober, 10.00–11.00" in the provider's zone.
String bookingWhen(Booking booking) => tr(
  'bookings.when',
  params: {
    'date': formatDateIn(booking.startsAt, booking.timeZone),
    'from': formatTimeIn(booking.startsAt, booking.timeZone),
    'to': formatTimeIn(booking.endsAt, booking.timeZone),
  },
);

/// One booking in "Minu broneeringud" and on the success screen.
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, this.onCancel, this.cancelling = false});
  final Booking booking;

  /// Shown only while the server says the booking can still be cancelled.
  final VoidCallback? onCancel;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dogs = booking.dogs.map((d) => d.name).join(', ');
    final statusColor = switch (booking.status) {
      BookingStatus.cancelled => TextColor.danger,
      BookingStatus.confirmed => TextColor.text,
      BookingStatus.completed => TextColor.muted,
    };
    return Container(
      padding: const EdgeInsets.all(Spacing.three),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.r16),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppText(
                  dogs.isNotEmpty
                      ? context.t('booking.confirmed.card', params: {'dogs': dogs, 'service': booking.service.name})
                      : booking.service.name,
                  type: TextType.label,
                ),
              ),
              const SizedBox(width: Spacing.two),
              AppText(
                context.t('bookings.status.${booking.status.name}'),
                type: TextType.caption,
                themeColor: statusColor,
              ),
            ],
          ),
          const SizedBox(height: Spacing.one),
          AppText(bookingWhen(booking), type: TextType.caption),
          const SizedBox(height: Spacing.one),
          AppText(
            [
              booking.provider.name,
              booking.provider.address ?? booking.provider.area,
              priceLabel(booking.priceCents, booking.priceIsFrom),
            ].join(' · '),
            type: TextType.caption,
            themeColor: TextColor.muted,
          ),
          if (booking.note != null) ...[
            const SizedBox(height: Spacing.one),
            AppText(context.t('bookings.note', params: {'note': booking.note}), type: TextType.caption),
          ],
          if (booking.status == BookingStatus.confirmed && onCancel != null) ...[
            const SizedBox(height: Spacing.one),
            if (booking.cancellable) ...[
              AppText(
                context.t(
                  'bookings.cancelUntil',
                  params: {
                    'date': formatDateIn(booking.cancelUntil, booking.timeZone),
                    'time': formatTimeIn(booking.cancelUntil, booking.timeZone),
                  },
                ),
                type: TextType.caption,
                themeColor: TextColor.muted,
              ),
              AppButton(
                label: context.t('bookings.cancel'),
                variant: ButtonVariant.tertiary,
                loading: cancelling,
                onPressed: onCancel,
              ),
            ] else
              AppText(context.t('bookings.cancelClosed'), type: TextType.caption, themeColor: TextColor.muted),
          ],
        ],
      ),
    );
  }
}

/// Figma "Product Card" (58:136): photo, name, price and the paw discount. The whole card opens the
/// product ("Lunasta X käpaga" lives there).
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onPressed});
  final Product product;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      semanticLabel: context.t(
        'shop.productA11y',
        params: {
          'name': product.name,
          'price': formatPrice(product.priceCents),
          'percent': product.discountPercent,
          'partner': product.provider.name,
        },
      ),
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
              child: product.imageUrl != null
                  ? SignedImage(product.imageUrl!)
                  : Center(child: AppIcon(IconName.shoppingBag, size: 36, color: c.brand)),
            ),
          ),
          const SizedBox(height: Spacing.two),
          AppText(product.name, type: TextType.label, maxLines: 2),
          const SizedBox(height: Spacing.one),
          Wrap(
            spacing: Spacing.two,
            runSpacing: Spacing.one,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppText(formatPrice(product.priceCents), type: TextType.label),
              DiscountPill(percent: product.discountPercent),
            ],
          ),
        ],
      ),
    );
  }
}

/// Figma "Services / Discover" provider card: "Käpakoda · koerte hooldus" over
/// "Kadriorg · 1,2 km · alates 35 € · ★ 4,9". Opens the provider screen.
class ProviderRow extends StatelessWidget {
  const ProviderRow({super.key, required this.provider});
  final ProviderSummary provider;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final title = context.t(
      'services.rowTitle',
      params: {'name': provider.name, 'kind': context.t('services.kind.${provider.category.name}')},
    );
    final price = provider.priceFromCents == null ? null : priceLabel(provider.priceFromCents!, true);
    final rating = provider.ratingAverage == null
        ? null
        : context.t('services.rating', params: {'rating': formatRating(provider.ratingAverage!)});
    final meta = [provider.area, ?formatKm(provider.distanceKm), ?price, ?rating].join(' · ');
    final ratingA11y = provider.ratingAverage == null
        ? null
        : context.t(
            'services.ratingA11y',
            params: {'rating': formatRating(provider.ratingAverage!), 'reviews': reviewsLabel(provider.ratingCount)},
          );
    final label = [title, provider.area, ?formatKm(provider.distanceKm), ?price, ?ratingA11y].join(', ');
    return Pressable(
      semanticLabel: label,
      onPressed: () => context.push('/services/${provider.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(Spacing.three),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.r16),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(title, type: TextType.label),
                  if (provider.tagline != null) ...[
                    const SizedBox(height: 2),
                    AppText(provider.tagline!, type: TextType.caption),
                  ],
                  const SizedBox(height: 2),
                  AppText(meta, type: TextType.caption, themeColor: TextColor.muted),
                ],
              ),
            ),
            AppIcon(IconName.chevronRight, size: 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}

/// Figma "Booking / Select Time": date chips (a week, scrolls sideways) and the free times of the
/// chosen day. Only times the server offered are shown; days without free times stay visible
/// (dimmed) so a closed Monday does not look like a bug.
class SlotPicker extends StatelessWidget {
  const SlotPicker({
    super.key,
    required this.days,
    required this.timeZone,
    required this.date,
    required this.onDateChanged,
    required this.startsAt,
    required this.onStartChanged,
  });

  final List<SlotDay> days;
  final String timeZone;
  final String? date;
  final ValueChanged<String> onDateChanged;
  final String? startsAt;
  final ValueChanged<String> onStartChanged;

  @override
  Widget build(BuildContext context) {
    final selectedDay = days.where((d) => d.date == date).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(context.t('booking.date'), type: TextType.heading),
        const SizedBox(height: Spacing.three),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (i, d) in days.indexed) ...[
                if (i > 0) const SizedBox(width: Spacing.two),
                Opacity(
                  opacity: d.slots.isEmpty ? 0.5 : 1,
                  child: ConstrainedBox(
                    // minWidth, not width: Russian day names must not be cut off.
                    constraints: const BoxConstraints(minWidth: 96),
                    child: AppChip(
                      label: formatDayChip(d.date),
                      selected: d.date == date,
                      onPressed: () => onDateChanged(d.date),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.three),
        AppText(context.t('booking.time'), type: TextType.heading),
        const SizedBox(height: Spacing.three),
        if (selectedDay != null && selectedDay.slots.isEmpty)
          AppText(context.t('booking.dayFull'), themeColor: TextColor.muted),
        if (selectedDay != null)
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: Spacing.two,
              runSpacing: Spacing.two,
              children: [
                for (final slot in selectedDay.slots)
                  ConstrainedBox(
                    // Four per row like the plan-visit hours; minWidth so large text grows the chip.
                    constraints: BoxConstraints(minWidth: (box.maxWidth - 3 * Spacing.two) / 4),
                    child: AppChip(
                      label: formatTimeIn(slot.startsAt, timeZone),
                      selected: slot.startsAt == startsAt,
                      onPressed: () => onStartChanged(slot.startsAt),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Figma 09 / Explore / Map + provider sheet (81:7764): tapping a service or clinic pin opens this
/// card over the map — photo, name, category · area, rating, the next free times, the paw-discount
/// hint and Teenused / Broneeri.
class ProviderSheet extends HookWidget {
  const ProviderSheet({super.key, required this.providerId, required this.onClose});
  final String providerId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final provider = useProvider(providerId);
    final service = provider.data?.services.firstOrNull;
    final slots = useServiceSlots(service?.id);
    // Partners come with the shop overview (cached for Pood too); no location → by name.
    final partner = useShop(null).data?.partners.where((p) => p.id == providerId).firstOrNull;
    final balance = usePointsBalance();
    final chosen = useState<String?>(null);
    final p = provider.data;
    final timeZone = slots.data?.timeZone ?? p?.timeZone ?? 'Europe/Tallinn';
    final free = nextFreeSlots([for (final d in slots.data?.days ?? const <SlotDay>[]) d.slots.map((s) => s.startsAt)]);
    final selected = chosen.value != null && free.contains(chosen.value) ? chosen.value : free.firstOrNull;
    String slotLabel(String iso) {
      final text = '${formatDay(iso)} ${formatTimeIn(iso, timeZone)}';
      return text[0].toUpperCase() + text.substring(1);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.screen, Spacing.two, Spacing.screen, Spacing.four),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.r32)),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, -4))],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: Spacing.three),
              if (provider.error != null)
                ErrorState(
                  message: errorMessage(provider.error),
                  onRetry: provider.refetch,
                  retrying: provider.isFetching,
                ),
              if (p == null && provider.isPending) const SkeletonList(rows: 2, rowHeight: 72),
              if (p != null) ...[
                MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 40),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(18)),
                          child: p.photoUrl != null
                              ? SignedImage(p.photoUrl!)
                              : Center(
                                  child: AppIcon(
                                    p.category == ServiceCategory.vet ? IconName.stethoscope : IconName.scissors,
                                    size: 28,
                                    color: c.brand,
                                  ),
                                ),
                        ),
                        const SizedBox(width: Spacing.three),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(p.name, type: TextType.title),
                              AppText(
                                [context.t('services.kindTitle.${p.category.name}'), p.area].join(' · '),
                                type: TextType.caption,
                                themeColor: TextColor.muted,
                              ),
                              AppText(
                                [
                                  if (p.ratingAverage != null)
                                    '${context.t('services.rating', params: {'rating': formatRating(p.ratingAverage!)})} · ${reviewsLabel(p.ratingCount)}',
                                  if (p.priceFromCents != null) priceLabel(p.priceFromCents!, true),
                                ].join(' · '),
                                type: TextType.caption,
                                themeColor: TextColor.muted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (service != null) ...[
                  const SizedBox(height: Spacing.three),
                  AppText(context.t('mapSheet.freeTimes'), type: TextType.heading, header: true),
                  const SizedBox(height: Spacing.three),
                  if (slots.isPending) const SkeletonList(rows: 1, rowHeight: 44),
                  if (slots.data != null && free.isEmpty)
                    AppText(context.t('booking.noSlots'), themeColor: TextColor.muted),
                  ChipWrap(
                    children: [
                      for (final iso in free)
                        AppChip(
                          radio: true,
                          label: slotLabel(iso),
                          selected: iso == selected,
                          onPressed: () => chosen.value = iso,
                        ),
                    ],
                  ),
                ],
                if (partner != null) ...[
                  const SizedBox(height: Spacing.three),
                  InfoCard(
                    title: context.t('mapSheet.discountTitle', params: {'percent': partner.pawDiscountPercent}),
                    body: balance != null
                        ? context.t(
                            'mapSheet.discountBodyBalance',
                            params: {'cost': pawsLabel(partner.pointsCost), 'balance': pawsLabel(balance)},
                          )
                        : context.t('mapSheet.discountBody', params: {'cost': pawsLabel(partner.pointsCost)}),
                  ),
                ],
                const SizedBox(height: Spacing.three),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: context.t('mapSheet.services'),
                        variant: ButtonVariant.secondary,
                        onPressed: () => context.push('/services/${p.id}'),
                      ),
                    ),
                    const SizedBox(width: Spacing.two),
                    Expanded(
                      flex: 3,
                      child: AppButton(
                        label: selected != null
                            ? context.t('mapSheet.bookAt', params: {'time': formatTimeIn(selected, timeZone)})
                            : context.t('mapSheet.book'),
                        onPressed: service == null
                            ? null
                            : () => context.push(
                                Uri(
                                  path: '/book',
                                  queryParameters: {'providerId': p.id, 'serviceId': service.id, 'startsAt': ?selected},
                                ).toString(),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Positioned(
            top: -Spacing.two,
            right: -Spacing.three,
            child: Pressable(
              semanticLabel: context.t('common.close'),
              onPressed: onClose,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(child: AppIcon(IconName.x, size: 22, color: c.muted)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
