import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/photo_tile.dart';
import '../../components/pressable.dart';
import '../../components/screen.dart';
import '../../components/states.dart';
import '../../components/text.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/i18n/i18n.dart';
import '../../core/photo_upload.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/dialogs.dart';
import '../../hooks/dogs.dart';
import '../../models/dogs.dart';

const _columns = 3;
const _gap = Spacing.two;

/// Picks a photo from the camera or the library. A denied camera permission shows the system
/// settings alert (iOS asks only once); the library uses the system picker, which needs no permission.
Future<PickedPhoto?> pickPhoto(BuildContext context, ImageSource source) async {
  try {
    final file = await ImagePicker().pickImage(source: source, requestFullMetadata: false);
    return file == null ? null : PickedPhoto(path: file.path);
  } catch (_) {
    if (source == ImageSource.camera && context.mounted) {
      await showAlert(
        context,
        tr('photos.cameraDeniedTitle'),
        message: tr('photos.cameraDeniedBody'),
        actions: [
          AlertAction(tr('common.cancel'), style: AlertStyle.cancel),
          AlertAction(tr('common.openSettings'), onPressed: Geolocator.openAppSettings),
        ],
      );
    }
    return null;
  }
}

/// Same photo when the object path matches; signatures differ between responses.
bool _samePhoto(String a, String b) => photoCacheKey(a) == photoCacheKey(b);

/// Figma 04 / Dog / Photos: thumbnail grid, add from camera or library, tap or long press for actions.
class DogPhotosScreen extends HookWidget {
  const DogPhotosScreen({super.key, required this.dogId});
  final String dogId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dog = useMyDogs().data?.where((d) => d.id == dogId).firstOrNull;
    final photos = useDogPhotos(dogId);
    final add = useAddPhoto(dogId);
    final remove = useDeletePhoto(dogId);
    final setProfile = useSetProfilePhoto(dogId);
    final error = useState<String?>(null);
    final width = MediaQuery.sizeOf(context).width;
    final tile = ((width - Spacing.screen * 2 - _gap * (_columns - 1)) / _columns).floorToDouble();
    final full = (photos.data?.length ?? 0) >= maxPhotosPerDog;
    void onError(Object e) => error.value = errorMessage(e);

    Future<void> pick(ImageSource source) async {
      error.value = null;
      final picked = await pickPhoto(context, source);
      if (picked != null) add.mutate(picked, onError: onError);
    }

    void confirmDelete(DogPhoto photo) {
      haptic(HapticReason.warning);
      showAlert(
        context,
        context.t('photos.deleteTitle'),
        message: context.t('photos.deleteBody'),
        actions: [
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
          AlertAction(
            context.t('common.delete'),
            style: AlertStyle.destructive,
            onPressed: () => remove.mutate(photo.id, onError: onError),
          ),
        ],
      );
    }

    String dateOf(DogPhoto p) => formatDate(localIsoDate(DateTime.parse(p.createdAt).toLocal()));

    void openActions(DogPhoto photo, bool isProfile) {
      error.value = null;
      showActionMenu(
        context,
        title: context.t('photos.actionsTitle', params: {'date': dateOf(photo)}),
        actions: [
          isProfile
              ? AlertAction(
                  context.t('photos.removeProfile'),
                  onPressed: () => setProfile.mutate(null, onError: onError),
                )
              : AlertAction(
                  context.t('photos.setProfile'),
                  onPressed: () => setProfile.mutate(photo.id, onError: onError),
                ),
          AlertAction(context.t('common.delete'), style: AlertStyle.destructive, onPressed: () => confirmDelete(photo)),
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
        ],
      );
    }

    return AppScreen(
      navBar: true,
      // The dog's name is not declined, see docs/11 ("Freddy fotoalbum").
      title: dog != null ? context.t('photos.title', params: {'name': dog.name}) : context.t('photos.titleFallback'),
      subtitle: context.t('photos.subtitle'),
      onRefresh: photos.refetch,
      children: [
        const OfflineBanner(),
        FormError(error.value),
        if (photos.error != null && photos.data == null)
          ErrorState(message: errorMessage(photos.error), onRetry: photos.refetch, retrying: photos.isFetching),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: context.t('photos.camera'),
                variant: ButtonVariant.secondary,
                onPressed: add.isPending || full ? null : () => pick(ImageSource.camera),
              ),
            ),
            const SizedBox(width: Spacing.two),
            Expanded(
              child: AppButton(
                label: context.t('photos.library'),
                variant: ButtonVariant.secondary,
                onPressed: add.isPending || full ? null : () => pick(ImageSource.gallery),
              ),
            ),
          ],
        ),
        if (add.isPending)
          Semantics(liveRegion: true, child: AppText(context.t('photos.uploading'), themeColor: TextColor.muted)),
        if (full) AppText(context.t('photos.full', params: {'max': maxPhotosPerDog}), themeColor: TextColor.muted),
        if (photos.isPending && photos.error == null) SkeletonList(rows: 1, rowHeight: tile),
        if (photos.data?.isEmpty ?? false) EmptyState(title: context.t('photos.empty')),
        Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final (i, photo) in (photos.data ?? const <DogPhoto>[]).indexed)
              Builder(
                builder: (context) {
                  final isProfile =
                      dog?.profilePhoto != null && _samePhoto(dog!.profilePhoto!.thumbnailUrl, photo.thumbnailUrl);
                  return Entering(
                    index: i,
                    child: Pressable(
                      semanticLabel: context.t(
                        isProfile ? 'photos.a11yProfile' : 'photos.a11y',
                        params: {'date': dateOf(photo)},
                      ),
                      semanticHint: context.t('photos.hint'),
                      onPressed: () => openActions(photo, isProfile),
                      onLongPress: () => openActions(photo, isProfile),
                      child: Stack(
                        children: [
                          Container(
                            width: tile,
                            height: tile,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: c.soft,
                              borderRadius: BorderRadius.circular(Radii.r12),
                              border: Border.all(color: isProfile ? c.brand : Colors.transparent, width: 2),
                            ),
                            child: SignedImage(photo.thumbnailUrl),
                          ),
                          if (isProfile)
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.brand,
                                  borderRadius: BorderRadius.circular(Radii.full),
                                ),
                                child: AppText(context.t('photos.badge'), type: TextType.micro, color: c.onBrand),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
