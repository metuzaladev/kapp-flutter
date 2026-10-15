import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/chip.dart';
import '../../components/icon.dart';
import '../../components/park_map.dart';
import '../../components/place_post_card.dart';
import '../../components/pressable.dart';
import '../../components/screen.dart';
import '../../components/segmented_control.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../components/text_field.dart';
import '../../core/api/api_client.dart';
import '../../core/haptics.dart';
import '../../core/i18n/i18n.dart';
import '../../core/logic/explore.dart';
import '../../core/logic/map_categories.dart';
import '../../core/logic/rewards.dart';
import '../../core/logic/upload_order.dart';
import '../../core/photo_upload.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/dialogs.dart';
import '../../core/validation.dart';
import '../../hooks/device_location.dart';
import '../../hooks/explore.dart';
import '../../hooks/services.dart';
import '../../models/explore.dart';
import '../../state/explore_view.dart';

/// A single recommendation (map pin of kind `post`, a notification "Sinu soovitus on avaldatud", or a
/// feed card): the Place Post card with every photo and the full text.
class PlacePostScreen extends HookWidget {
  const PlacePostScreen({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context) {
    final query = usePlacePost(postId);
    final earned = pointsFor(useRewards().data, RewardReason.placePost);
    final actions = usePlacePostActions(context);
    final post = query.data;
    return AppScreen(
      navBar: true,
      onRefresh: query.refetch,
      children: [
        const OfflineBanner(),
        if (query.error != null && post == null)
          ErrorState(message: errorMessage(query.error), onRetry: query.refetch, retrying: query.isFetching),
        if (query.isPending && query.error == null) const SkeletonList(rows: 1, rowHeight: 480),
        if (post != null) ...[
          PlacePostCard(
            post: post,
            earnedPoints: earned,
            expanded: true,
            onShowOnMap: () => actions.showOnMap(post),
            onMore: () => actions.openMenu(post, onDeleted: () => context.pop()),
          ),
          if (post.isMine && post.status == PlacePostStatus.pending)
            InfoCard(
              title: context.t('explore.pendingInfoTitle'),
              body: earned != null
                  ? context.t('explore.pendingInfoBody', count: earned)
                  : context.t('explore.pendingInfoBodyNoPoints'),
            ),
        ],
      ],
    );
  }
}

/// "Minu soovitused" (Profile): the user's own recommendations with their status and the bookmarked
/// ones. Same cards as Avasta.
class MyPlacePostsScreen extends HookWidget {
  const MyPlacePostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = useState('mine');
    final mine = useMyPlacePosts(enabled: tab.value == 'mine');
    final saved = useSavedPlacePosts(enabled: tab.value == 'saved');
    final list = tab.value == 'mine' ? mine : saved;
    final posts = [for (final p in list.pages) ...p.items];
    final earned = pointsFor(useRewards().data, RewardReason.placePost);
    final actions = usePlacePostActions(context);

    return AppScreen(
      navBar: true,
      title: context.t('explore.mine.title'),
      subtitle: context.t('explore.mine.subtitle'),
      onRefresh: list.refetch,
      children: [
        const OfflineBanner(),
        SegmentedControl<String>(
          semanticLabel: context.t('explore.mine.title'),
          options: [
            (value: 'mine', label: context.t('explore.mine.tabMine')),
            (value: 'saved', label: context.t('explore.mine.tabSaved')),
          ],
          value: tab.value,
          onChanged: (v) {
            if (v != null) tab.value = v;
          },
        ),
        if (list.error != null && list.data == null)
          ErrorState(message: errorMessage(list.error), onRetry: list.refetch, retrying: list.isFetching),
        if (list.isPending && list.error == null) const SkeletonList(rows: 1, rowHeight: 420),
        if (list.data != null && posts.isEmpty)
          tab.value == 'mine'
              ? EmptyState(
                  title: context.t('explore.mine.emptyMine'),
                  actionLabel: context.t('explore.suggest'),
                  onAction: () => context.push('/suggest-place'),
                )
              : EmptyState(title: context.t('explore.mine.emptySaved')),
        for (final (i, post) in posts.indexed)
          Entering(
            key: ValueKey(post.id),
            index: i,
            child: PlacePostCard(
              post: post,
              earnedPoints: earned,
              onOpen: () => context.push('/place-posts/${post.id}'),
              onShowOnMap: () => actions.showOnMap(post),
              onMore: () => actions.openMenu(post),
            ),
          ),
        if (list.hasNextPage)
          AppButton(
            label: context.t('notifications.more'),
            variant: ButtonVariant.secondary,
            loading: list.isFetchingNextPage,
            onPressed: list.fetchNextPage,
          ),
      ],
    );
  }
}

/// "Teavita postitusest" — modal, the same shape as Safety / Report or Block. One report per person
/// and post; a repeated send returns the same report (docs/16).
class ReportPostScreen extends HookWidget {
  const ReportPostScreen({super.key, required this.postId, this.name});
  final String postId;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final report = useReportPlacePost(postId);
    final reason = useState('wrong_info');
    final details = useTextEditingController();
    final detailsError = useState<String?>(null);
    final formError = useState<String?>(null);
    final sent = useState(false);

    Future<void> submit() async {
      final text = details.text.trim();
      detailsError.value = reason.value == 'other' ? describeError(text) : optionalMaxError(text, 1000);
      formError.value = null;
      if (detailsError.value != null) return;
      try {
        await report.mutateAsync({'reason': reason.value, 'details': text.isEmpty ? null : text});
        haptic(HapticReason.success);
        sent.value = true;
      } catch (e) {
        haptic(HapticReason.error);
        formError.value = errorMessage(e);
      }
    }

    if (sent.value) {
      return AppScreen(
        navBar: true,
        navTitle: context.t('nav.reportPost'),
        title: context.t('safety.thanksTitle'),
        children: [
          InfoCard(title: context.t('explore.report.thanksTitle'), body: context.t('explore.report.thanksBody')),
          AppButton(label: context.t('common.close'), onPressed: () => context.pop()),
        ],
      );
    }

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.reportPost'),
      title: context.t('explore.report.title'),
      subtitle: name,
      children: [
        FormError(formError.value),
        AppText(context.t('explore.report.why'), type: TextType.heading),
        ChipWrap(
          children: [
            for (final r in placeReportReasons)
              AppChip(
                radio: true,
                label: context.t('explore.report.reasons.$r'),
                selected: reason.value == r,
                onPressed: () => reason.value = r,
              ),
          ],
        ),
        AppTextField(
          label: context.t('safety.what'),
          placeholder: context.t('explore.report.placeholder'),
          controller: details,
          error: detailsError.value,
          maxLines: null,
          minLines: 3,
          maxLength: 1000,
        ),
        InfoCard(title: context.t('safety.privateTitle'), body: context.t('safety.privateBody')),
        AppButton(label: context.t('safety.send'), loading: report.isPending, onPressed: submit),
      ],
    );
  }
}

const _tile = 104.0;

/// 5 decimals ≈ 1 m: a place needs its own point, not the ~100 m rounding used for "nearby" lists.
double _precise(double n) => (n * 100000).roundToDouble() / 100000;

const _pinKind = {
  PlaceCategory.cafe: PlaceKind.cafe,
  PlaceCategory.park: PlaceKind.park,
  PlaceCategory.beach: PlaceKind.beach,
  PlaceCategory.shop: PlaceKind.shop,
  PlaceCategory.other: PlaceKind.shop,
};

/// Figma 09 / Explore / Suggest Place (85:8637): photos (≤ 5), place name, location, category,
/// amenities, a short text, "Teenid 15 käppa" and "Postita". The post is `pending` until a moderator
/// approves it; then the server awards the points.
///
/// Location: a small map with a fixed centre pin the user drags under the place, starting at the
/// device position, plus "Kasuta minu asukohta" and a free-text address (no geocoder in the stack).
class SuggestPlaceScreen extends HookWidget {
  const SuggestPlaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final location = useDeviceLocation();
    final create = useCreatePlacePost();
    final points = pointsFor(useRewards().data, RewardReason.placePost);

    final photos = useState<List<PickedPhoto>>([]);
    final name = useTextEditingController();
    final address = useTextEditingController();
    final body = useTextEditingController();
    final category = useState<PlaceCategory?>(null);
    final amenities = useState<List<PlaceAmenity>>([]);
    final point = useState(location.origin);
    final pointChosen = useState(false);
    final recenter = useState(0);
    final locating = useState(false);
    final progress = useState<({int done, int total})?>(null);
    final errors = useState<FieldErrors>({});
    final formError = useState<String?>(null);

    // Until the user moves the pin (or taps "Kasuta minu asukohta") the point follows the device
    // position, which may arrive after the screen opened.
    final chosenPoint = pointChosen.value ? point.value : location.origin;
    final recenterKey = pointChosen.value
        ? 'chosen-${recenter.value}'
        : 'device-${location.origin.lat},${location.origin.lng}';

    Future<void> useMyLocation() async {
      formError.value = null;
      locating.value = true;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
          if (!context.mounted) return;
          await showAlert(
            context,
            context.t('location.deniedTitle'),
            message: context.t('suggest.locationDenied'),
            actions: [
              AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
              AlertAction(context.t('common.openSettings'), onPressed: Geolocator.openAppSettings),
            ],
          );
          return;
        }
        final here = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        point.value = (lat: _precise(here.latitude), lng: _precise(here.longitude));
        pointChosen.value = true;
        recenter.value++;
        haptic(HapticReason.selection);
      } catch (_) {
        formError.value = context.mounted ? context.t('suggest.locationFailed') : null;
      } finally {
        locating.value = false;
      }
    }

    Future<void> addPhotos(ImageSource source) async {
      final remaining = placePostMaxPhotos - photos.value.length;
      if (remaining <= 0) return;
      try {
        final picker = ImagePicker();
        final picked = source == ImageSource.camera
            ? [?await picker.pickImage(source: ImageSource.camera, requestFullMetadata: false)]
            : await picker.pickMultiImage(limit: remaining > 1 ? remaining : null, requestFullMetadata: false);
        photos.value = [
          ...photos.value,
          ...picked.map((f) => PickedPhoto(path: f.path)),
        ].take(placePostMaxPhotos).toList();
      } catch (_) {
        if (source == ImageSource.camera && context.mounted) {
          await showAlert(
            context,
            context.t('photos.cameraDeniedTitle'),
            message: context.t('suggest.cameraDenied'),
            actions: [
              AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
              AlertAction(context.t('common.openSettings'), onPressed: Geolocator.openAppSettings),
            ],
          );
        }
      }
    }

    void choosePhotoSource() => showActionMenu(
      context,
      title: context.t('suggest.addPhoto'),
      actions: [
        AlertAction(context.t('photos.camera'), onPressed: () => addPhotos(ImageSource.camera)),
        AlertAction(context.t('photos.library'), onPressed: () => addPhotos(ImageSource.gallery)),
        AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
      ],
    );

    void photoActions(int index) => showActionMenu(
      context,
      title: context.t('suggest.photoTitle', params: {'position': index + 1, 'total': photos.value.length}),
      actions: [
        if (index > 0)
          AlertAction(context.t('suggest.makeCover'), onPressed: () => photos.value = makeCover(photos.value, index)),
        AlertAction(
          context.t('suggest.removePhoto'),
          style: AlertStyle.destructive,
          onPressed: () => photos.value = [
            for (final (i, p) in photos.value.indexed)
              if (i != index) p,
          ],
        ),
        AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
      ],
    );

    Future<void> submit() async {
      formError.value = null;
      if (category.value == null) {
        errors.value = {'category': context.t('suggest.chooseCategory')};
        return;
      }
      if (!pointChosen.value && location.usingFallback) {
        errors.value = {'lat': context.t('suggest.choosePoint')};
        return;
      }
      // Same rules as the API's createPlacePostInputSchema.
      final invalid = <String, String>{
        'name': ?lengthError(name.text, min: placeNameMin, max: placeNameMax),
        'address': ?optionalMaxError(address.text, placeAddressMax),
        'body': ?optionalMaxError(body.text, placePostBodyMax),
        if (!isInEstonia(chosenPoint.lat, chosenPoint.lng)) 'lat': issue('validation.outsideEstonia'),
      };
      errors.value = invalid;
      if (invalid.isNotEmpty) return;
      String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
      try {
        await create.mutateAsync((
          input: {
            'name': name.text.trim(),
            'category': category.value!.name,
            'lat': chosenPoint.lat,
            'lng': chosenPoint.lng,
            'address': orNull(address.text),
            'amenities': amenities.value.map((a) => a.wire).toList(),
            'body': orNull(body.text),
          },
          photos: photos.value,
          onProgress: (done, total) => progress.value = (done: done, total: total),
        ));
        haptic(HapticReason.success);
        if (!context.mounted) return;
        announce(context, context.t('suggest.sent'));
        // Back to Avasta, where the new post waits at the top with "Ootab kinnitust".
        setExploreView(ExploreView.feed);
        context.pop();
      } catch (e) {
        haptic(HapticReason.error);
        formError.value = errorMessage(e);
      } finally {
        progress.value = null;
      }
    }

    final p = progress.value;
    final uploading = p != null && p.total > 0 && p.done < p.total;

    return AppScreen(
      navBar: true,
      navTitle: context.t('nav.suggestPlace'),
      title: context.t('suggest.title'),
      subtitle: context.t('suggest.subtitle'),
      children: [
        FormError(formError.value),
        SizedBox(
          height: _tile,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (final (i, photo) in photos.value.indexed) ...[
                Pressable(
                  semanticLabel: context.t(
                    i == 0 ? 'suggest.photoCoverA11y' : 'suggest.photoA11y',
                    params: {'position': i + 1, 'total': photos.value.length},
                  ),
                  semanticHint: context.t('suggest.photoHint'),
                  onPressed: () => photoActions(i),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.r24),
                        child: Image.file(File(photo.path), width: _tile, height: _tile, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: AppIcon(IconName.x, size: 14, color: c.text),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (photos.value.length < placePostMaxPhotos)
                Pressable(
                  semanticLabel: context.t('suggest.addPhoto'),
                  semanticHint: context.t('suggest.addPhotoHint', params: {'max': placePostMaxPhotos}),
                  onPressed: choosePhotoSource,
                  child: Container(
                    width: _tile,
                    height: _tile,
                    padding: const EdgeInsets.all(Spacing.one),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.r24),
                      border: Border.all(color: c.border, width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(IconName.camera, size: 24, color: c.text),
                        const SizedBox(height: Spacing.one),
                        AppText(
                          context.t('suggest.addPhoto'),
                          type: TextType.caption,
                          themeColor: TextColor.muted,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        AppText(
          context.t('suggest.photoNote', params: {'max': placePostMaxPhotos}),
          type: TextType.caption,
          themeColor: TextColor.muted,
        ),
        AppTextField(
          label: context.t('suggest.name'),
          placeholder: context.t('suggest.namePlaceholder'),
          controller: name,
          maxLength: placeNameMax,
          error: errors.value['name'],
        ),
        AppTextField(
          label: context.t('suggest.address'),
          placeholder: context.t('suggest.addressPlaceholder'),
          controller: address,
          maxLength: placeAddressMax,
          error: errors.value['address'],
        ),
        AppText(context.t('suggest.where'), type: TextType.heading, header: true),
        LocationPicker(
          value: chosenPoint,
          recenter: recenterKey,
          kind: category.value == null ? PlaceKind.park : _pinKind[category.value]!,
          onChanged: (next, byUser) {
            // Camera moves made by the app (load, recenter) are not a choice.
            if (!byUser) return;
            point.value = (lat: _precise(next.lat), lng: _precise(next.lng));
            pointChosen.value = true;
          },
        ),
        Semantics(
          liveRegion: true,
          child: AppText(
            errors.value['lat'] ?? context.t('suggest.whereHint'),
            type: TextType.caption,
            themeColor: errors.value['lat'] != null ? TextColor.danger : TextColor.muted,
          ),
        ),
        AppButton(
          label: context.t('suggest.useMyLocation'),
          variant: ButtonVariant.secondary,
          loading: locating.value,
          onPressed: useMyLocation,
        ),
        AppText(context.t('suggest.category'), type: TextType.heading, header: true),
        ChipWrap(
          children: [
            for (final key in suggestCategories)
              IconChip(
                radio: true,
                icon: placeCategoryIcon[key]!,
                label: context.t('explore.categories.${key.name}'),
                selected: category.value == key,
                onPressed: () {
                  category.value = key;
                  errors.value = {...errors.value}..remove('category');
                },
              ),
          ],
        ),
        if (errors.value['category'] != null)
          Semantics(
            liveRegion: true,
            child: AppText(errors.value['category']!, type: TextType.caption, themeColor: TextColor.danger),
          ),
        AppText(context.t('suggest.amenities'), type: TextType.heading, header: true),
        ChipWrap(
          children: [
            for (final key in PlaceAmenity.values)
              IconChip(
                icon: amenities.value.contains(key) ? IconName.check : IconName.plus,
                label: context.t('explore.amenities.${key.wire}'),
                selected: amenities.value.contains(key),
                onPressed: () => amenities.value = toggleAmenity(amenities.value, key),
              ),
          ],
        ),
        AppTextField(
          label: context.t('suggest.body'),
          placeholder: context.t('suggest.bodyPlaceholder'),
          controller: body,
          maxLength: placePostBodyMax,
          maxLines: null,
          minLines: 3,
          error: errors.value['body'],
        ),
        InfoCard(
          title: points != null
              ? context.t('suggest.earnTitle', count: points)
              : context.t('suggest.earnTitleNoPoints'),
          body: context.t('suggest.earnBody'),
        ),
        if (uploading)
          Semantics(
            liveRegion: true,
            child: AppText(
              context.t('suggest.uploading', params: {'done': p.done + 1, 'total': p.total}),
              themeColor: TextColor.muted,
            ),
          ),
        AppButton(label: context.t('suggest.submit'), loading: create.isPending, onPressed: submit),
      ],
    );
  }
}
