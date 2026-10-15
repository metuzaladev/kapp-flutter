import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/chip.dart';
import '../../components/icon.dart';
import '../../components/photo_tile.dart';
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
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/dialogs.dart';
import '../../core/validation.dart';
import '../../hooks/account.dart';
import '../../hooks/device_location.dart';
import '../../hooks/dogs.dart';
import '../../hooks/services.dart';
import '../../models/services.dart';

/// Figma chips; "Muu" exists in the data model but has no providers, so it gets no chip.
const _categories = <ServiceCategory?>[null, ServiceCategory.grooming, ServiceCategory.training, ServiceCategory.vet];
const _categoryIcon = {
  null: IconName.layers,
  ServiceCategory.grooming: IconName.scissors,
  ServiceCategory.training: IconName.footprints,
  ServiceCategory.vet: IconName.stethoscope,
  ServiceCategory.other: IconName.sparkles,
};

/// Figma 06 / Services / Discover: category chips and providers nearest first. Pood's category tiles
/// open the list on a category (`?category=grooming`).
class ServicesScreen extends HookWidget {
  const ServicesScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  Widget build(BuildContext context) {
    final location = useDeviceLocation();
    final category = useState<ServiceCategory?>(
      ServiceCategory.values.where((c) => c.name == initialCategory).firstOrNull,
    );
    final providers = useProviders(category.value, location.origin);
    return AppScreen(
      navBar: true,
      title: context.t('services.title'),
      subtitle: context.t('services.subtitle'),
      onRefresh: providers.refetch,
      children: [
        const OfflineBanner(),
        ChipRow(
          children: [
            for (final key in _categories)
              IconChip(
                radio: true,
                icon: _categoryIcon[key]!,
                label: context.t('services.categories.${key?.name ?? 'all'}'),
                selected: category.value == key,
                onPressed: () => category.value = key,
              ),
          ],
        ),
        if (providers.error != null && providers.data == null)
          ErrorState(
            message: errorMessage(providers.error),
            onRetry: providers.refetch,
            retrying: providers.isFetching,
          ),
        if (providers.isPending && providers.error == null) const SkeletonList(rowHeight: 88),
        if (providers.data?.isEmpty ?? false) EmptyState(title: context.t('services.empty')),
        for (final (i, p) in (providers.data ?? const <ProviderSummary>[]).indexed)
          Entering(
            index: i,
            child: ProviderRow(provider: p),
          ),
        // Honest about the demo data (Figma: "… on disaini näidisandmed").
        AppText(
          '${context.t('services.demoNote')}${location.usingFallback ? ' ${context.t('services.distanceNote')}' : ''}',
          type: TextType.caption,
          themeColor: TextColor.muted,
        ),
      ],
    );
  }
}

/// Figma 06 / Service / Groomer: who they are, what they offer, "Vali sobiv aeg".
class ProviderScreen extends HookWidget {
  const ProviderScreen({super.key, required this.providerId});
  final String providerId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final query = useProvider(providerId);
    final provider = query.data;
    // null = not chosen yet; the cheapest (first) service is preselected so one tap books.
    final chosen = useState<String?>(null);
    final selectedId = chosen.value ?? provider?.services.firstOrNull?.id;

    if (provider == null) {
      return AppScreen(
        navBar: true,
        children: [
          if (query.error != null)
            ErrorState(message: errorMessage(query.error), onRetry: query.refetch, retrying: query.isFetching),
          if (query.isPending && query.error == null) const SkeletonList(rows: 3, rowHeight: 80),
        ],
      );
    }

    final rating = provider.ratingAverage == null
        ? null
        : '${context.t('services.rating', params: {'rating': formatRating(provider.ratingAverage!)})} · ${reviewsLabel(provider.ratingCount)}';

    return AppScreen(
      navBar: true,
      title: provider.name,
      subtitle: '${context.t('services.kindTitle.${provider.category.name}')} · ${provider.area}',
      children: [
        const OfflineBanner(),
        // Decorative: the provider's name and description say who they are.
        if (provider.photoUrl != null)
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.r16),
              child: AspectRatio(aspectRatio: 16 / 9, child: SignedImage(provider.photoUrl!)),
            ),
          ),
        if (provider.tagline != null) AppText(provider.tagline!, type: TextType.heading),
        if (provider.description != null) AppText(provider.description!),
        if (provider.address != null || rating != null)
          AppText([?provider.address, ?rating].join(' · '), type: TextType.caption, themeColor: TextColor.muted),
        if (provider.services.isEmpty) AppText(context.t('provider.noServices'), themeColor: TextColor.muted),
        for (final service in provider.services)
          Builder(
            builder: (context) {
              final selected = service.id == selectedId;
              final meta = context.t(
                'provider.serviceMeta',
                params: {
                  'duration': formatDuration(service.durationMinutes),
                  'price': priceLabel(service.priceCents, service.priceIsFrom),
                },
              );
              return Pressable(
                semanticLabel: [service.name, meta, ?service.description].join(', '),
                semanticHint: context.t('provider.serviceHint'),
                checked: selected,
                onPressed: () {
                  haptic(HapticReason.selection);
                  chosen.value = service.id;
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.all(Spacing.three),
                  decoration: BoxDecoration(
                    color: selected ? c.soft : c.surface,
                    borderRadius: BorderRadius.circular(Radii.r16),
                    border: Border.all(color: selected ? c.brand : c.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(service.name, type: TextType.label),
                            AppText(meta, type: TextType.caption, themeColor: TextColor.muted),
                            if (service.description != null) AppText(service.description!, type: TextType.caption),
                          ],
                        ),
                      ),
                      const SizedBox(width: Spacing.three),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? c.brand : c.border, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: selected
                            ? Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        AppButton(
          label: context.t('provider.chooseTime'),
          onPressed: selectedId == null
              ? null
              : () => context.push(
                  Uri(path: '/book', queryParameters: {'providerId': provider.id, 'serviceId': selectedId}).toString(),
                ),
        ),
        AppText(context.t('services.demoNote'), type: TextType.caption, themeColor: TextColor.muted),
      ],
    );
  }
}

/// Whether a zone's clock differs from the phone's right now (then the booking says which zone).
bool _differsFromDevice(String timeZone) {
  try {
    return tz.TZDateTime.now(tz.getLocation(timeZone)).timeZoneOffset != DateTime.now().timeZoneOffset;
  } catch (_) {
    return false;
  }
}

/// Figma 06 / Booking / Select Time — a modal: date and free time, which dogs, a note, the
/// informational price, the paw discount (M9b) and "Kinnita broneering". No payment in the app.
class BookScreen extends HookWidget {
  const BookScreen({super.key, required this.providerId, required this.serviceId, this.preset});
  final String providerId;
  final String serviceId;

  /// A time chosen in the map's provider sheet.
  final String? preset;

  @override
  Widget build(BuildContext context) {
    final provider = useProvider(providerId);
    final slots = useServiceSlots(serviceId);
    final dogs = useMyDogs().data;
    final create = useCreateBooking();
    // M9b "Kasuta käppi": an unused booking code for this provider is reused (e.g. after a slot was
    // taken), otherwise a new one is redeemed right before booking.
    final partner = useShop(null).data?.partners.where((p) => p.id == providerId).firstOrNull;
    final openCode = useRedemptions().data
        ?.where(
          (r) =>
              r.offerType == 'booking' &&
              r.status.name == 'active' &&
              r.provider.id == providerId &&
              r.bookingId == null,
        )
        .firstOrNull;
    final balance = usePointsBalance();
    final redeem = useRedeemOnce();
    final usePaws = useState(false);
    final canUsePaws = partner != null && (openCode != null || (balance != null && balance >= partner.pointsCost));
    final service = provider.data?.services.where((s) => s.id == serviceId).firstOrNull;

    final date = useState<String?>(null);
    final startsAt = useState<String?>(preset);
    final chosenDogs = useState<List<String>?>(null);
    final note = useTextEditingController();
    final error = useState<String?>(null);
    final booked = useState<Booking?>(null);

    if (booked.value != null) return _Confirmed(booking: booked.value!);

    final days = slots.data?.days ?? const <SlotDay>[];
    // Until the user picks, open the first day that has a free time.
    final presetDay = preset == null
        ? null
        : days.where((d) => d.slots.any((s) => s.startsAt == preset)).firstOrNull?.date;
    final shownDate =
        date.value ?? presetDay ?? days.where((d) => d.slots.isNotEmpty).firstOrNull?.date ?? days.firstOrNull?.date;
    // A time that vanished after a refetch (someone booked it) is no longer selected.
    final selectedStart = days.any((d) => d.slots.any((s) => s.startsAt == startsAt.value)) ? startsAt.value : null;
    final selectedDogs = chosenDogs.value ?? (dogs?.length == 1 ? [dogs!.first.id] : <String>[]);
    final timeZone = slots.data?.timeZone ?? provider.data?.timeZone ?? 'Europe/Tallinn';

    void toggleDog(String id) {
      final next = selectedDogs.contains(id) ? selectedDogs.where((x) => x != id).toList() : [...selectedDogs, id];
      chosenDogs.value = next.length > maxBookingDogs ? next.sublist(next.length - maxBookingDogs) : next;
    }

    Future<void> submit() async {
      if (selectedStart == null) {
        error.value = context.t('booking.chooseTime');
        return;
      }
      if (selectedDogs.isEmpty) {
        error.value = issue('validation.chooseDog');
        return;
      }
      final noteError = optionalMaxError(note.text, bookingNoteMax);
      if (noteError != null) {
        error.value = noteError;
        return;
      }
      error.value = null;
      try {
        final redemptionId = usePaws.value && canUsePaws
            ? (openCode ?? await redeem.run(offerType: 'booking', offerId: providerId)).id
            : null;
        booked.value = await create.mutateAsync({
          'serviceId': serviceId,
          'startsAt': selectedStart,
          'dogIds': selectedDogs,
          'note': note.text.trim().isEmpty ? null : note.text.trim(),
          'redemptionId': redemptionId,
        });
        haptic(HapticReason.success);
      } catch (e) {
        // 409 (taken meanwhile): the hook refetches the free times, the stale one disappears.
        haptic(HapticReason.error);
        error.value = errorMessage(e);
      }
    }

    final category = provider.data?.category.name ?? 'other';
    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.book'),
      title: context.t('booking.title.$category'),
      subtitle: provider.data?.name,
      children: [
        FormError(
          error.value ??
              (provider.error != null
                  ? errorMessage(provider.error)
                  : slots.error != null
                  ? errorMessage(slots.error)
                  : null),
        ),
        if (service != null)
          AppText(
            context.t(
              'booking.serviceLine',
              params: {'service': service.name, 'duration': formatDuration(service.durationMinutes)},
            ),
            type: TextType.label,
          ),
        if (slots.isPending && slots.error == null) const SkeletonList(rows: 2, rowHeight: 44),
        if (slots.data != null && days.every((d) => d.slots.isEmpty))
          AppText(context.t('booking.noSlots'), themeColor: TextColor.muted),
        if (days.isNotEmpty)
          SlotPicker(
            days: days,
            timeZone: timeZone,
            date: shownDate,
            onDateChanged: (d) {
              date.value = d;
              startsAt.value = null;
            },
            startsAt: selectedStart,
            onStartChanged: (s) => startsAt.value = s,
          ),
        if (_differsFromDevice(timeZone))
          AppText(
            context.t('booking.timeZoneNote', params: {'zone': timeZone}),
            type: TextType.caption,
            themeColor: TextColor.muted,
          ),
        AppText(context.t('booking.who'), type: TextType.heading),
        if (dogs?.isEmpty ?? false) ...[
          AppText(context.t('booking.noDogs'), themeColor: TextColor.muted),
          AppButton(
            label: context.t('booking.addDog'),
            variant: ButtonVariant.secondary,
            onPressed: () => context.push('/dogs/edit'),
          ),
        ],
        if (dogs != null && dogs.isNotEmpty)
          ChipRow(
            children: [
              for (final dog in dogs)
                IconChip(
                  icon: IconName.pawPrint,
                  label: dog.name,
                  selected: selectedDogs.contains(dog.id),
                  onPressed: () => toggleDog(dog.id),
                ),
            ],
          ),
        AppTextField(
          label: context.t('booking.note'),
          placeholder: context.t('booking.notePlaceholder'),
          controller: note,
          maxLength: bookingNoteMax,
          maxLines: null,
          minLines: 2,
        ),
        if (service != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                context.t('booking.price', params: {'price': priceLabel(service.priceCents, service.priceIsFrom)}),
                type: TextType.heading,
              ),
              const SizedBox(height: Spacing.one),
              AppText(
                '${context.t('booking.priceNote')} ${context.t('booking.cancelRule', count: bookingCutoffMinutes ~/ 60)}',
                type: TextType.caption,
                themeColor: TextColor.muted,
              ),
            ],
          ),
        if (partner != null) ...[
          SwitchRow(
            label: context.t('booking.usePaws', params: {'percent': partner.pawDiscountPercent}),
            hint: openCode != null
                ? context.t('booking.usePawsCode', params: {'code': openCode.code})
                : balance != null && balance < partner.pointsCost
                ? context.t(
                    'booking.usePawsShort',
                    params: {'cost': pawsLabel(partner.pointsCost), 'balance': pawsLabel(balance)},
                  )
                : context.t('booking.usePawsCost', params: {'cost': pawsLabel(partner.pointsCost)}),
            value: usePaws.value && canUsePaws,
            disabled: !canUsePaws,
            onChanged: (v) => usePaws.value = v,
          ),
          if (usePaws.value && canUsePaws && service != null)
            AppText(
              context.t('booking.usePawsNote', params: {'percent': partner.pawDiscountPercent}),
              type: TextType.caption,
              themeColor: TextColor.muted,
            ),
        ],
        AppButton(
          label: context.t('booking.submit'),
          loading: create.isPending || redeem.isPending,
          onPressed: service == null || (dogs?.isEmpty ?? false) ? null : submit,
        ),
      ],
    );
  }
}

/// After booking: Figma 06 / Booking / Confirmed — success mark, "Kohtumiseni!", the booking card.
class _Confirmed extends StatelessWidget {
  const _Confirmed({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    void leave(String path) {
      // The router outlives this screen, which is popped first (router.dismissAll()).
      final router = GoRouter.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (path == '/') {
        router.go('/');
      } else {
        unawaited(router.push(path));
      }
    }

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.book'),
      children: [
        const Align(alignment: Alignment.centerLeft, child: SuccessMark()),
        AppText(context.t('booking.confirmed.title'), type: TextType.title, header: true),
        AppText(context.t('booking.confirmed.subtitle'), themeColor: TextColor.muted),
        Entering(index: 2, child: BookingCard(booking: booking)),
        // The discounted price is the server's (informational: paid at the provider).
        if (booking.discount != null)
          AppText(
            context.t(
              'booking.discounted',
              params: {
                'price': formatPrice(booking.discount!.discountedPriceCents),
                'percent': booking.discount!.discountPercent,
              },
            ),
            type: TextType.label,
          ),
        AppText(context.t('booking.confirmed.info'), type: TextType.caption, themeColor: TextColor.muted),
        AppButton(label: context.t('booking.confirmed.viewBookings'), onPressed: () => leave('/bookings')),
        AppButton(
          label: context.t('booking.confirmed.home'),
          variant: ButtonVariant.secondary,
          onPressed: () => leave('/'),
        ),
      ],
    );
  }
}

/// Figma 06 / Bookings / My Bookings: "Tulevased" / "Varasemad", cancel with a confirmation.
class BookingsScreen extends HookWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = useState('upcoming');
    final list = useBookings(scope.value);
    final cancel = useCancelBooking();
    final dogCount = useMyDogs().data?.length ?? 0;

    void confirmCancel(Booking booking) {
      // Destructive and not undoable (the time may be booked by someone else), so ask first (HIG).
      haptic(HapticReason.warning);
      showAlert(
        context,
        context.t('bookings.cancelTitle'),
        message: context.t(
          'bookings.cancelBody',
          params: {'service': booking.service.name, 'provider': booking.provider.name, 'when': bookingWhen(booking)},
        ),
        actions: [
          AlertAction(context.t('bookings.keep'), style: AlertStyle.cancel),
          AlertAction(
            context.t('bookings.cancelConfirm'),
            style: AlertStyle.destructive,
            onPressed: () => cancel.mutate(booking.id),
          ),
        ],
      );
    }

    return AppScreen(
      navBar: true,
      title: context.t('bookings.title'),
      subtitle: context.t('bookings.subtitle', count: dogCount),
      onRefresh: list.refetch,
      children: [
        const OfflineBanner(),
        SegmentedControl<String>(
          options: [
            (value: 'upcoming', label: context.t('bookings.upcoming')),
            (value: 'past', label: context.t('bookings.past')),
          ],
          value: scope.value,
          onChanged: (v) {
            if (v != null) scope.value = v;
          },
        ),
        if (list.error != null && list.data == null)
          ErrorState(message: errorMessage(list.error), onRetry: list.refetch, retrying: list.isFetching),
        if (cancel.error != null) FormError(errorMessage(cancel.error)),
        if (list.isPending && list.error == null) const SkeletonList(rows: 2, rowHeight: 96),
        if (list.data?.isEmpty ?? false)
          EmptyState(title: context.t(scope.value == 'upcoming' ? 'bookings.emptyUpcoming' : 'bookings.emptyPast')),
        for (final (i, b) in (list.data ?? const <Booking>[]).indexed)
          Entering(
            index: i,
            child: BookingCard(
              booking: b,
              onCancel: () => confirmCancel(b),
              cancelling: cancel.isPending && cancel.variables == b.id,
            ),
          ),
        AppButton(
          label: context.t('bookings.findService'),
          variant: ButtonVariant.secondary,
          onPressed: () => context.push('/services'),
        ),
      ],
    );
  }
}
