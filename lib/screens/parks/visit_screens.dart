import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/chip.dart';
import '../../components/icon.dart';
import '../../components/list_row.dart';
import '../../components/pressable.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../components/text_field.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/i18n/i18n.dart';
import '../../core/query/hooks.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/dialogs.dart';
import '../../core/validation.dart';
import '../../hooks/community.dart';
import '../../hooks/device_location.dart';
import '../../hooks/dogs.dart';
import '../../hooks/parks.dart';
import '../../hooks/visits.dart';
import '../../models/visits.dart';
import '../../state/park_filters.dart';

/// Figma 03 / Visit / Check In — modal: which dogs, how long. After checking in, the "Visit / Active"
/// confirmation replaces the form (not dismissed automatically, so screen-reader users hear it).
class CheckInScreen extends HookWidget {
  const CheckInScreen({super.key, required this.parkId, this.parkName});
  final String parkId;
  final String? parkName;

  @override
  Widget build(BuildContext context) {
    final dogsQuery = useMyDogs();
    final dogs = dogsQuery.data;
    final checkIn = useCheckIn();
    // null = "user has not chosen yet"; then one dog is preselected so check-in is a single tap.
    final chosen = useState<List<String>?>(null);
    final selected = chosen.value ?? (dogs?.length == 1 ? [dogs!.first.id] : <String>[]);
    final duration = useState(60);
    final error = useState<String?>(null);
    final done = useState<ActiveCheckIn?>(null);

    void toggle(String id) =>
        chosen.value = selected.contains(id) ? selected.where((x) => x != id).toList() : [...selected, id];

    Future<void> submit() async {
      if (selected.isEmpty) {
        error.value = issue('validation.chooseDog');
        return;
      }
      error.value = null;
      try {
        done.value = await checkIn.mutateAsync({
          'parkId': parkId,
          'dogIds': selected,
          'durationMinutes': duration.value,
        });
        haptic(HapticReason.success);
        if (context.mounted) announce(context, context.t('checkIn.done'));
      } catch (e) {
        haptic(HapticReason.error);
        error.value = errorMessage(e);
      }
    }

    final result = done.value;
    if (result != null) {
      return AppScreen(
        navBar: true,
        navTitle: context.t('nav.checkIn'),
        children: [
          const Align(alignment: Alignment.centerLeft, child: SuccessMark()),
          AppText(context.t('home.activeTitle'), type: TextType.title, header: true),
          AppText(result.park.name, type: TextType.label),
          AppText(
            context.t(
              'home.activeDogs',
              params: {'dogs': result.dogs.map((d) => d.name).join(', '), 'time': formatTime(result.expiresAt)},
            ),
            themeColor: TextColor.muted,
          ),
          AppButton(label: context.t('checkIn.seeFriends'), onPressed: () => context.pop()),
        ],
      );
    }

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.checkIn'),
      title: context.t('checkIn.title'),
      subtitle: parkName,
      children: [
        FormError(error.value),
        if (dogsQuery.isPending) const SkeletonList(rows: 1, rowHeight: 44),
        if (dogs != null && dogs.isEmpty) ...[
          AppText(context.t('checkIn.noDogs'), themeColor: TextColor.muted),
          AppButton(
            label: context.t('checkIn.addDog'),
            variant: ButtonVariant.secondary,
            onPressed: () => context.push('/dogs/edit'),
          ),
        ],
        if (dogs != null && dogs.isNotEmpty) ...[
          AppText(context.t('checkIn.who'), type: TextType.heading),
          ChipRow(
            children: [
              for (final dog in dogs)
                IconChip(
                  icon: IconName.pawPrint,
                  label: dog.name,
                  selected: selected.contains(dog.id),
                  onPressed: () => toggle(dog.id),
                ),
            ],
          ),
          AppText(context.t('checkIn.duration'), type: TextType.heading),
          ChipWrap(
            children: [
              for (final m in checkInDurations)
                AppChip(
                  radio: true,
                  label: formatDurationShort(m),
                  selected: duration.value == m,
                  onPressed: () => duration.value = m,
                ),
            ],
          ),
          AppText(
            '${context.t('checkIn.expiry', count: duration.value)} ${context.t('checkIn.privacy')}',
            type: TextType.caption,
            themeColor: TextColor.muted,
          ),
          AppButton(label: context.t('checkIn.submit'), loading: checkIn.isPending, onPressed: submit),
        ],
      ],
    );
  }
}

const _daysShown = 7;
const _firstHour = 6;
const _lastHour = 22;
const _durations = [30, 60, 90, 120];

/// Figma 03 / Visit / Plan — modal. Chips instead of a date picker: plans are "today 17:00", not
/// exact. Opened from "Kutsu parki" on a friend's profile, the saved plan is sent to the friend.
class PlanVisitScreen extends HookWidget {
  const PlanVisitScreen({super.key, required this.parkId, this.parkName, this.inviteUserId});
  final String parkId;
  final String? parkName;
  final String? inviteUserId;

  @override
  Widget build(BuildContext context) {
    final plan = usePlanVisit();
    final invite = useSendInvitation();
    final days = useMemoized(() {
      final now = DateTime.now();
      return [for (var i = 0; i < _daysShown; i++) DateTime(now.year, now.month, now.day + i)];
    });
    final day = useState(0);
    final hour = useState<int?>(null);
    final duration = useState(60);
    final note = useTextEditingController();
    final error = useState<String?>(null);

    // Today only offers hours that have not started yet.
    final nowHour = DateTime.now().hour;
    final hours = [
      for (var h = _firstHour; h <= _lastHour; h++)
        if (day.value > 0 || h > nowHour) h,
    ];

    Future<void> submit() async {
      if (hour.value == null) {
        error.value = context.t('plan.chooseTime');
        return;
      }
      final d = days[day.value];
      final start = DateTime(d.year, d.month, d.day, hour.value!);
      final end = start.add(Duration(minutes: duration.value));
      final noteError = optionalMaxError(note.text, 200);
      if (noteError != null) {
        error.value = noteError;
        return;
      }
      error.value = null;
      try {
        final saved = await plan.mutateAsync({
          'parkId': parkId,
          'startsAt': start.toUtc().toIso8601String(),
          'endsAt': end.toUtc().toIso8601String(),
          'note': note.text.trim().isEmpty ? null : note.text.trim(),
        });
        haptic(HapticReason.success);
        if (!context.mounted) return;
        if (inviteUserId != null) {
          // The invitation is an ordinary message in the sender's language, so the friend can reply.
          final message = await invite.mutateAsync((
            userId: inviteUserId!,
            body: context.t(
              'invite.message',
              params: {'park': saved.park.name, 'day': formatDay(saved.startsAt), 'from': formatTime(saved.startsAt)},
            ),
          ));
          if (!context.mounted) return;
          // Close the modals (router.dismissAll()) and open the conversation with the invitation.
          final router = GoRouter.of(context);
          Navigator.of(context).popUntil((route) => route.isFirst);
          unawaited(router.push('/messages/${message.conversationId}'));
          return;
        }
        context.pop();
      } catch (e) {
        haptic(HapticReason.error);
        error.value = errorMessage(e);
      }
    }

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.planVisit'),
      title: context.t('plan.title'),
      subtitle: context.t('plan.subtitle'),
      children: [
        FormError(error.value),
        if (parkName != null) AppText(parkName!, type: TextType.label),
        AppText(context.t('plan.date'), type: TextType.heading),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (i, d) in days.indexed) ...[
                if (i > 0) const SizedBox(width: Spacing.two),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 96),
                  child: AppChip(
                    label: formatDay(d.toIso8601String()),
                    selected: day.value == i,
                    onPressed: () {
                      day.value = i;
                      hour.value = null;
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        AppText(context.t('plan.time'), type: TextType.heading),
        if (hours.isEmpty) AppText(context.t('plan.tooLate'), themeColor: TextColor.muted),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: Spacing.two,
            runSpacing: Spacing.two,
            children: [
              for (final h in hours)
                ConstrainedBox(
                  // Four per row; minWidth so "17:00" at 160 % text size grows instead of being clipped.
                  constraints: BoxConstraints(minWidth: (box.maxWidth - 3 * Spacing.two) / 4),
                  child: AppChip(label: formatHour(h), selected: hour.value == h, onPressed: () => hour.value = h),
                ),
            ],
          ),
        ),
        AppText(context.t('plan.duration'), type: TextType.heading),
        ChipWrap(
          children: [
            for (final m in _durations)
              AppChip(
                radio: true,
                label: formatDurationShort(m),
                selected: duration.value == m,
                onPressed: () => duration.value = m,
              ),
          ],
        ),
        AppTextField(
          label: context.t('plan.note'),
          placeholder: context.t('plan.notePlaceholder'),
          controller: note,
          maxLength: 200,
        ),
        AppButton(label: context.t('plan.submit'), loading: plan.isPending || invite.isPending, onPressed: submit),
      ],
    );
  }
}

/// Figma 03 / Visit / Add Review — modal. Writing again replaces the previous review.
class ReviewScreen extends HookWidget {
  const ReviewScreen({super.key, required this.parkId, this.parkName});
  final String parkId;
  final String? parkName;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final submitReview = useSubmitReview(parkId);
    final rating = useState(0);
    final body = useTextEditingController();
    final error = useState<String?>(null);

    Future<void> submit() async {
      if (rating.value < 1) {
        error.value = context.t('review.chooseRating');
        return;
      }
      final bodyError = optionalMaxError(body.text, 1000);
      if (bodyError != null) {
        error.value = bodyError;
        return;
      }
      error.value = null;
      try {
        await submitReview.mutateAsync({
          'rating': rating.value,
          'body': body.text.trim().isEmpty ? null : body.text.trim(),
        });
        haptic(HapticReason.success);
        if (!context.mounted) return;
        announce(context, context.t('review.saved'));
        context.pop();
      } catch (e) {
        haptic(HapticReason.error);
        error.value = errorMessage(e);
      }
    }

    void setRating(int n) {
      if (n != rating.value) haptic(HapticReason.selection);
      rating.value = n;
    }

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.review'),
      title: context.t('review.title'),
      subtitle: parkName,
      children: [
        FormError(error.value),
        AppText(context.t('review.hint'), themeColor: TextColor.muted),
        // One adjustable element for screen readers (swipe up/down changes the rating, HIG) instead of
        // five separate star buttons; touch users still tap a star.
        Semantics(
          label: context.t('review.ratingLabel'),
          value: context.t('review.ratingA11y', params: {'rating': rating.value}),
          onIncrease: () => setRating((rating.value + 1).clamp(1, 5)),
          onDecrease: () => setRating((rating.value - 1).clamp(1, 5)),
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var n = 1; n <= 5; n++)
                  Pressable(
                    semanticLabel: context.t('review.star', count: n),
                    onPressed: () => setRating(n),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Center(
                        child: AppIcon(
                          rating.value >= n ? IconName.starFilled : IconName.star,
                          size: 34,
                          color: rating.value >= n ? c.brand : c.border,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        AppTextField(
          label: context.t('review.experience'),
          placeholder: context.t('review.experiencePlaceholder'),
          controller: body,
          maxLines: null,
          minLines: 3,
          maxLength: 1000,
        ),
        AppButton(label: context.t('review.submit'), loading: submitReview.isPending, onPressed: submit),
      ],
    );
  }
}

/// Figma 03 / Park / Report Issue — modal; confirmation replaces the form after sending.
class ReportParkScreen extends HookWidget {
  const ReportParkScreen({super.key, required this.parkId, this.parkName});
  final String parkId;
  final String? parkName;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final report = useReportPark(parkId);
    final description = useTextEditingController();
    final fieldError = useState<String?>(null);
    final error = useState<String?>(null);

    Future<void> submit() async {
      fieldError.value = describeError(description.text);
      if (fieldError.value != null) return;
      try {
        await report.mutateAsync({'description': description.text.trim()});
      } catch (e) {
        error.value = errorMessage(e);
      }
    }

    if (report.isSuccess) {
      return AppScreen(
        navBar: true,
        navTitle: context.t('nav.report'),
        title: context.t('report.thanksTitle'),
        subtitle: context.t('report.thanksBody'),
        children: [AppButton(label: context.t('common.close'), onPressed: () => context.pop())],
      );
    }

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.report'),
      title: context.t('report.title'),
      subtitle: parkName,
      children: [
        FormError(error.value),
        AppText(context.t('report.examples'), themeColor: TextColor.muted),
        AppTextField(
          label: context.t('report.what'),
          placeholder: context.t('report.whatPlaceholder'),
          controller: description,
          error: fieldError.value,
          maxLines: null,
          minLines: 3,
          maxLength: 1000,
        ),
        Container(
          padding: const EdgeInsets.all(Spacing.three),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(context.t('report.calmTitle'), type: TextType.label),
                const SizedBox(height: 2),
                AppText(context.t('report.calmBody'), type: TextType.caption, themeColor: TextColor.muted),
              ],
            ),
          ),
        ),
        AppButton(label: context.t('report.submit'), loading: report.isPending, onPressed: submit),
      ],
    );
  }
}

/// "Kutsu parki" from a friend's profile: pick a park (favourites first, then nearby), then the usual
/// plan-visit modal; after saving it, the plan is sent to the friend as a message.
class InviteParkScreen extends HookWidget {
  const InviteParkScreen({super.key, required this.userId, this.name});
  final String userId;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final location = useDeviceLocation();
    final nearbyQuery = useNearbyParks(location.origin, useStore(parkFilters));
    final favoritesQuery = useFavoriteParks();
    final nearby = nearbyQuery.data ?? const [];
    final favorites = favoritesQuery.data ?? const [];
    final loading = nearbyQuery.isPending || favoritesQuery.isPending;
    final favoriteIds = favorites.map((p) => p.id).toSet();
    final parks = [...favorites, ...nearby.where((p) => !favoriteIds.contains(p.id))];

    return AppScreen(
      navBar: true,
      title: context.t('invite.title', params: {'name': name ?? ''}),
      subtitle: context.t('invite.subtitle'),
      children: [
        if (loading && parks.isEmpty) const SkeletonList(),
        if (!loading && parks.isEmpty) EmptyState(title: context.t('map.empty')),
        for (final (i, park) in parks.indexed)
          Entering(
            index: i,
            child: ListRow(
              title: park.name,
              subtitle: favoriteIds.contains(park.id) ? context.t('invite.favorite') : formatKm(park.distanceKm),
              onPressed: () => context.push(
                Uri(
                  path: '/plan-visit',
                  queryParameters: {'parkId': park.id, 'parkName': park.name, 'inviteUserId': userId},
                ).toString(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Figma 03 / Visits / History, plus the user's upcoming plans.
class VisitsScreen extends HookWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final history = useVisitHistory();
    final plans = usePlannedVisits();
    final cancel = useCancelPlan();
    BoxDecoration card() => BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.r16),
      border: Border.all(color: c.border, width: 0.5),
    );

    return AppScreen(
      navBar: true,
      title: context.t('visits.title'),
      subtitle: context.t('visits.subtitle'),
      onRefresh: () => refreshAll([history.refetch, plans.refetch]),
      children: [
        const OfflineBanner(),
        if (cancel.error != null) FormError(errorMessage(cancel.error)),
        AppText(context.t('visits.planned'), type: TextType.heading, header: true),
        if (plans.isPending) const SkeletonList(rows: 1),
        // Figma "Empty State / Meetups". A plan starts from a park, so the action opens the map.
        if (plans.data?.isEmpty ?? false)
          EmptyState(
            title: context.t('visits.plannedEmptyTitle'),
            body: context.t('visits.plannedEmptyBody'),
            actionLabel: context.t('visits.plannedEmptyAction'),
            onAction: () => context.go('/map'),
          ),
        for (final (i, p) in (plans.data ?? const <PlannedVisit>[]).indexed)
          Entering(
            index: i,
            child: Container(
              padding: const EdgeInsets.all(Spacing.three),
              decoration: card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(p.park.name, type: TextType.label),
                        AppText(
                          '${formatDay(p.startsAt)} · ${formatTime(p.startsAt)}–${formatTime(p.endsAt)}',
                          type: TextType.caption,
                          themeColor: TextColor.muted,
                        ),
                        if (p.note != null) AppText(p.note!, type: TextType.caption),
                      ],
                    ),
                  ),
                  AppButton(
                    label: context.t('visits.cancelPlan'),
                    variant: ButtonVariant.tertiary,
                    onPressed: cancel.isPending ? null : () => cancel.mutate(p.id),
                  ),
                ],
              ),
            ),
          ),
        AppText(context.t('visits.done'), type: TextType.heading, header: true),
        if (history.error != null && history.data == null)
          ErrorState(message: errorMessage(history.error), onRetry: history.refetch, retrying: history.isFetching),
        if (history.isPending && history.error == null) const SkeletonList(),
        if (history.data?.isEmpty ?? false)
          EmptyState(
            title: context.t('visits.empty'),
            actionLabel: context.t('visits.emptyAction'),
            onAction: () => context.go('/map'),
          ),
        for (final (i, v) in (history.data ?? const <VisitHistoryItem>[]).indexed)
          Entering(
            index: i,
            child: Container(
              padding: const EdgeInsets.all(Spacing.three),
              decoration: card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: Spacing.two,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AppText(v.park.name, type: TextType.label),
                            AppText(
                              formatDuration(v.durationMinutes),
                              type: TextType.caption,
                              themeColor: TextColor.muted,
                            ),
                          ],
                        ),
                        AppText(
                          '${formatDay(v.startedAt)} · ${formatTime(v.startedAt)} · ${v.dogs.isEmpty ? '—' : v.dogs.map((d) => d.name).join(', ')}',
                          type: TextType.caption,
                          themeColor: TextColor.muted,
                        ),
                      ],
                    ),
                  ),
                  if (!v.hasReview)
                    AppButton(
                      label: context.t('visits.addReview'),
                      variant: ButtonVariant.tertiary,
                      onPressed: () => context.push(
                        Uri(
                          path: '/review',
                          queryParameters: {'parkId': v.park.id, 'parkName': v.park.name},
                        ).toString(),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
