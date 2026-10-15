import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/icon.dart';
import '../../components/list_row.dart';
import '../../components/photo_tile.dart';
import '../../components/screen.dart';
import '../../components/segmented_control.dart';
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
import '../../hooks/dogs.dart';
import '../../models/dogs.dart';

String _details(BuildContext context, Dog dog) {
  final parts = [
    ?dog.breed,
    if (dog.birthDate != null) ageLabel(dog.birthDate!),
    if (dog.weightKg != null) formatKg(dog.weightKg!),
  ];
  return parts.isEmpty ? context.t('dogs.list.noDetails') : parts.join(' · ');
}

/// Figma 04 / Dogs / My Dogs: rounded-square photo and "Cardigan corgi · 5 kuud · 12 kg"; a row opens
/// the profile.
class MyDogsScreen extends HookWidget {
  const MyDogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final query = useMyDogs();
    final dogs = query.data;
    return AppScreen(
      navBar: true,
      title: context.t('dogs.list.title'),
      subtitle: context.t('dogs.list.subtitle'),
      onRefresh: query.refetch,
      children: [
        if (query.error != null && dogs == null)
          ErrorState(message: errorMessage(query.error), onRetry: query.refetch, retrying: query.isFetching),
        if (query.isPending && query.error == null) const SkeletonList(rows: 2),
        if (dogs?.isEmpty ?? false)
          EmptyState(title: context.t('dogs.list.emptyTitle'), body: context.t('dogs.list.emptyBody')),
        for (final (i, dog) in (dogs ?? const <Dog>[]).indexed)
          Entering(
            index: i,
            child: ListRow(
              title: dog.name,
              subtitle: _details(context, dog),
              showPhoto: true,
              photoUrl: dog.profilePhoto?.thumbnailUrl,
              photoName: dog.name,
              hint: context.t('dogs.list.openHint'),
              onPressed: () => context.push('/dogs/${dog.id}'),
            ),
          ),
        AppButton(
          label: context.t('dogs.list.add'),
          variant: ButtonVariant.secondary,
          onPressed: () => context.push('/dogs/edit'),
        ),
      ],
    );
  }
}

/// Figma 04 / Dog / Profile: picture, "Cardigan corgi · isane · 5 kuud", links to photos and health,
/// "Muuda profiili".
class DogProfileScreen extends HookWidget {
  const DogProfileScreen({super.key, required this.dogId});
  final String dogId;

  @override
  Widget build(BuildContext context) {
    final query = useMyDogs();
    final dogs = query.data;
    final dog = dogs?.where((d) => d.id == dogId).firstOrNull;
    final photos = useDogPhotos(dogId);
    final health = useHealthRecords(dogId);

    return AppScreen(
      navBar: true,
      navTitle: dog?.name,
      children: [
        const OfflineBanner(),
        if (query.error != null && dogs == null)
          ErrorState(message: errorMessage(query.error), onRetry: query.refetch, retrying: query.isFetching),
        if (query.isPending && query.error == null) const SkeletonList(rows: 2, rowHeight: 120),
        if (dogs != null && dog == null) FormError(context.t('dogs.profile.notFound')),
        if (dog != null) ..._profile(context, dog, photos.data?.length, health.data),
      ],
    );
  }

  List<Widget> _profile(BuildContext context, Dog dog, int? photoCount, List<HealthRecord>? records) {
    final c = context.c;
    final facts = [
      ?dog.breed,
      if (dog.sex != null) dogSexLabel(dog.sex!),
      if (dog.birthDate != null) ageLabel(dog.birthDate!),
      if (dog.weightKg != null) formatKg(dog.weightKg!),
    ];
    // The soonest upcoming (or overdue) due date, as a hint on the health row.
    final dues = [for (final r in records ?? const <HealthRecord>[]) ?r.nextDue]..sort();
    final nextDue = dues.firstOrNull;
    return [
      Entering(
        child: dog.profilePhoto != null
            ? Semantics(
                image: true,
                label: context.t('dogs.profile.photoA11y', params: {'name': dog.name}),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.r24),
                  child: AspectRatio(aspectRatio: 4 / 3, child: SignedImage(dog.profilePhoto!.url)),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.two),
                child: Center(child: PhotoTile(name: dog.name, size: 120, radius: 36)),
              ),
      ),
      AppText(dog.name, type: TextType.title, header: true),
      if (facts.isNotEmpty) AppText(facts.join(' · '), themeColor: TextColor.muted),
      if (dog.birthDate != null)
        AppText(
          context.t('dogs.profile.born', params: {'date': formatDate(dog.birthDate!)}),
          type: TextType.caption,
          themeColor: TextColor.muted,
        ),
      if (dog.temperament != null)
        Container(
          padding: const EdgeInsets.all(Spacing.three),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(context.t('dogs.profile.temperament'), type: TextType.caption, themeColor: TextColor.muted),
              const SizedBox(height: Spacing.one),
              AppText(dog.temperament!),
            ],
          ),
        ),
      ListRow(
        icon: IconName.camera,
        title: context.t('dogs.profile.photos'),
        subtitle: photoCount == null
            ? null
            : photoCount == 0
            ? context.t('dogs.profile.photosEmpty')
            : context.t('dogs.profile.photosCount', params: {'photos': photosLabel(photoCount)}),
        onPressed: () => context.push('/dogs/${dog.id}/photos'),
      ),
      ListRow(
        icon: IconName.stethoscope,
        title: context.t('dogs.profile.health'),
        subtitle: nextDue != null
            ? context.t('dogs.profile.nextDue', params: {'due': dueLabel(nextDue)})
            : context.t('dogs.profile.healthPrivate'),
        alert: nextDue != null && isOverdue(nextDue),
        onPressed: () => context.push('/dogs/${dog.id}/health'),
      ),
      AppButton(
        label: context.t('dogs.profile.edit'),
        variant: ButtonVariant.secondary,
        onPressed: () => context.push('/dogs/edit?dogId=${dog.id}'),
      ),
    ];
  }
}

/// Figma 04 / Dog / Edit Profile — also used for adding (no dogId). Presented as a modal. The form
/// mounts only once the dog is known, so its fields start with the right values.
class DogEditScreen extends HookWidget {
  const DogEditScreen({super.key, this.dogId});
  final String? dogId;

  @override
  Widget build(BuildContext context) {
    final query = useMyDogs();
    final existing = query.data?.where((d) => d.id == dogId).firstOrNull;
    final title = dogId != null ? context.t('nav.dogEdit') : context.t('nav.dogAdd');
    if (dogId != null && query.isPending) {
      return AppScreen(navBar: true, navTitle: title, children: const [SkeletonList(rows: 3, rowHeight: 72)]);
    }
    if (dogId != null && existing == null) {
      return AppScreen(navBar: true, navTitle: title, children: [FormError(context.t('dogs.profile.notFound'))]);
    }
    return _DogForm(dogId: dogId, existing: existing, title: title);
  }
}

class _DogForm extends HookWidget {
  const _DogForm({required this.dogId, required this.existing, required this.title});
  final String? dogId;
  final Dog? existing;
  final String title;

  @override
  Widget build(BuildContext context) {
    final save = useSaveDog(dogId);
    final remove = useDeleteDog(dogId ?? '');
    final name = useTextEditingController(text: existing?.name ?? '');
    final breed = useTextEditingController(text: existing?.breed ?? '');
    final birthDate = useTextEditingController(text: existing?.birthDate ?? '');
    final weight = useTextEditingController(text: existing?.weightKg?.toString().replaceAll('.', ',') ?? '');
    final temperament = useTextEditingController(text: existing?.temperament ?? '');
    final sex = useState<DogSex?>(existing?.sex);
    final errors = useState<FieldErrors>({});
    final formError = useState<String?>(null);

    Future<void> submit() async {
      final invalid = validateDog(
        name: name.text,
        breed: breed.text,
        birthDate: birthDate.text,
        weight: weight.text,
        temperament: temperament.text,
      );
      errors.value = invalid;
      formError.value = null;
      if (invalid.isNotEmpty) return;
      String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
      final w = weight.text.trim().replaceAll(',', '.');
      try {
        await save.mutateAsync({
          'name': name.text.trim(),
          'breed': orNull(breed.text),
          'sex': sex.value?.name,
          'birthDate': orNull(birthDate.text),
          'weightKg': w.isEmpty ? null : double.parse(w),
          'temperament': orNull(temperament.text),
        });
        if (context.mounted) context.pop();
      } catch (e) {
        formError.value = errorMessage(e);
      }
    }

    void confirmDelete() {
      // Destructive and irreversible: confirm with the system alert (HIG), destructive style.
      haptic(HapticReason.warning);
      showAlert(
        context,
        context.t('dogs.edit.deleteTitle', params: {'name': existing?.name ?? ''}),
        message: context.t('dogs.edit.deleteBody'),
        actions: [
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
          AlertAction(
            context.t('common.delete'),
            style: AlertStyle.destructive,
            // Back to the list: the profile underneath belongs to the dog that no longer exists.
            onPressed: () => remove.mutate(
              null,
              onSuccess: (_) {
                if (!context.mounted) return;
                // Close the form and the deleted dog's profile under it (dismissTo('/dogs')).
                final navigator = Navigator.of(context);
                navigator.pop();
                if (navigator.canPop()) navigator.pop();
              },
              onError: (e) => formError.value = errorMessage(e),
            ),
          ),
        ],
      );
    }

    return AppScreen(
      navBar: true,
      navTitle: title,
      title: context.t('dogs.edit.title'),
      subtitle: context.t('dogs.edit.subtitle'),
      children: [
        FormError(formError.value),
        AppTextField(
          label: context.t('dogs.edit.name'),
          controller: name,
          error: errors.value['name'],
          capitalization: TextCapitalization.words,
        ),
        AppTextField(
          label: context.t('dogs.edit.breed'),
          placeholder: context.t('dogs.edit.breedPlaceholder'),
          controller: breed,
          error: errors.value['breed'],
        ),
        AppText(context.t('dogs.edit.sex'), type: TextType.label),
        // Optional field: tapping the chosen side again clears it.
        SegmentedControl<DogSex>(
          semanticLabel: context.t('dogs.edit.sex'),
          allowDeselect: true,
          options: [
            (value: DogSex.male, label: context.t('dogs.edit.male')),
            (value: DogSex.female, label: context.t('dogs.edit.female')),
          ],
          value: sex.value,
          onChanged: (v) => sex.value = v,
        ),
        AppTextField(
          label: context.t('dogs.edit.birthDate'),
          placeholder: context.t('dogs.edit.datePlaceholder'),
          controller: birthDate,
          error: errors.value['birthDate'],
          keyboardType: TextInputType.datetime,
        ),
        AppTextField(
          label: context.t('dogs.edit.weight'),
          placeholder: context.t('dogs.edit.weightPlaceholder'),
          controller: weight,
          error: errors.value['weightKg'],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        AppTextField(
          label: context.t('dogs.edit.temperament'),
          placeholder: context.t('dogs.edit.temperamentPlaceholder'),
          controller: temperament,
          error: errors.value['temperament'],
          maxLines: null,
          minLines: 3,
          maxLength: 500,
        ),
        AppButton(
          label: dogId != null ? context.t('dogs.edit.save') : context.t('dogs.edit.add'),
          loading: save.isPending,
          onPressed: submit,
        ),
        if (dogId != null)
          AppButton(
            label: context.t('dogs.edit.delete'),
            variant: ButtonVariant.tertiary,
            loading: remove.isPending,
            onPressed: confirmDelete,
          ),
      ],
    );
  }
}
