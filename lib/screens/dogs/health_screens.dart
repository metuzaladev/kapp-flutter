import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/banners.dart';
import '../../components/button.dart';
import '../../components/list_row.dart';
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

const _sections = [
  (
    kind: HealthRecordKind.vaccination,
    title: 'health.vaccinations',
    add: 'health.addVaccination',
    empty: 'health.emptyVaccinations',
  ),
  (
    kind: HealthRecordKind.vetVisit,
    title: 'health.vetVisits',
    add: 'health.addVetVisit',
    empty: 'health.emptyVetVisits',
  ),
];

/// GET /me/health-reminders lists due dates within this many days (`REMINDER_WINDOW_DAYS`).
const reminderWindowDays = 30;

/// Figma 04 / Dog / Health ("Freddy tervis"): records by kind, add as a modal, delete with
/// confirmation. Owner only.
class DogHealthScreen extends HookWidget {
  const DogHealthScreen({super.key, required this.dogId});
  final String dogId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dog = useMyDogs().data?.where((d) => d.id == dogId).firstOrNull;
    final records = useHealthRecords(dogId);
    final remove = useDeleteHealthRecord(dogId);
    final error = useState<String?>(null);

    void edit({String? recordId, HealthRecordKind? kind}) => context.push(
      Uri(path: '/dogs/$dogId/health-edit', queryParameters: {'recordId': ?recordId, 'kind': ?kind?.wire}).toString(),
    );

    String subtitle(HealthRecord r) => [
      formatDate(r.date),
      ?r.clinic,
      if (r.nextDue != null) context.t('health.next', params: {'due': dueLabel(r.nextDue!)}),
    ].join(' · ');

    void confirmDelete(HealthRecord r) {
      haptic(HapticReason.warning);
      showAlert(
        context,
        context.t('health.deleteTitle', params: {'title': r.title}),
        message: context.t('health.deleteBody'),
        actions: [
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
          AlertAction(
            context.t('common.delete'),
            style: AlertStyle.destructive,
            onPressed: () => remove.mutate(r.id, onError: (e) => error.value = errorMessage(e)),
          ),
        ],
      );
    }

    return AppScreen(
      navBar: true,
      // The dog's name is not declined: Figma's "Freddy tervis" needs the genitive, see docs/11.
      title: dog != null ? context.t('health.title', params: {'name': dog.name}) : context.t('health.titleFallback'),
      subtitle: context.t('health.subtitle'),
      onRefresh: records.refetch,
      children: [
        const OfflineBanner(),
        FormError(error.value),
        Container(
          padding: const EdgeInsets.all(Spacing.three),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(context.t('health.introTitle'), type: TextType.label),
                const SizedBox(height: 2),
                AppText(context.t('health.introBody'), type: TextType.caption, themeColor: TextColor.muted),
              ],
            ),
          ),
        ),
        if (records.error != null && records.data == null)
          ErrorState(message: errorMessage(records.error), onRetry: records.refetch, retrying: records.isFetching),
        if (records.isPending && records.error == null) const SkeletonList(),
        if (records.data != null)
          for (final section in _sections)
            Builder(
              builder: (context) {
                final items = records.data!.where((r) => r.kind == section.kind).toList();
                return Padding(
                  padding: const EdgeInsets.only(top: Spacing.two),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppText(context.t(section.title), type: TextType.heading, header: true),
                      const SizedBox(height: Spacing.two),
                      if (items.isEmpty) ...[
                        AppText(context.t(section.empty), themeColor: TextColor.muted),
                        const SizedBox(height: Spacing.two),
                      ],
                      for (final (i, r) in items.indexed) ...[
                        Entering(
                          index: i,
                          child: ListRow(
                            title: r.title,
                            subtitle: subtitle(r),
                            alert: r.nextDue != null && isOverdue(r.nextDue!),
                            hint: context.t('health.rowHint'),
                            onPressed: () => edit(recordId: r.id),
                            onLongPress: () => confirmDelete(r),
                          ),
                        ),
                        const SizedBox(height: Spacing.two),
                      ],
                      AppButton(
                        label: context.t(section.add),
                        variant: ButtonVariant.secondary,
                        onPressed: () => edit(kind: section.kind),
                      ),
                    ],
                  ),
                );
              },
            ),
      ],
    );
  }
}

/// Per-kind texts: Figma "Health / Add Vaccination" and "Health / Vet Visit".
({String screen, String title, String placeholder, String save}) _kindText(HealthRecordKind kind) => switch (kind) {
  HealthRecordKind.vaccination => (
    screen: 'nav.vaccinationAdd',
    title: 'health.edit.vaccinationTitle',
    placeholder: 'health.edit.vaccinationPlaceholder',
    save: 'common.save',
  ),
  HealthRecordKind.vetVisit => (
    screen: 'nav.vetVisitAdd',
    title: 'health.edit.vetVisitTitle',
    placeholder: 'health.edit.vetVisitPlaceholder',
    save: 'health.edit.saveVetVisit',
  ),
};

/// "Lisa vaktsineerimine" / "Loomaarsti külastus" and editing (recordId) — a modal like dogs/edit.
class HealthEditScreen extends HookWidget {
  const HealthEditScreen({super.key, required this.dogId, this.recordId, this.kind});
  final String dogId;
  final String? recordId;
  final String? kind;

  @override
  Widget build(BuildContext context) {
    final records = useHealthRecords(dogId);
    final existing = records.data?.where((r) => r.id == recordId).firstOrNull;
    final initialKind =
        existing?.kind ?? (kind == 'vet_visit' ? HealthRecordKind.vetVisit : HealthRecordKind.vaccination);
    final title = recordId != null ? context.t('nav.healthRecordEdit') : context.t(_kindText(initialKind).screen);
    if (recordId != null && records.isPending) {
      return AppScreen(navBar: true, navTitle: title, children: const [SkeletonList(rows: 3, rowHeight: 72)]);
    }
    if (recordId != null && existing == null) {
      return AppScreen(navBar: true, navTitle: title, children: [FormError(context.t('health.edit.notFound'))]);
    }
    return _HealthForm(dogId: dogId, existing: existing, kind: initialKind, title: title);
  }
}

class _HealthForm extends HookWidget {
  const _HealthForm({required this.dogId, required this.existing, required this.kind, required this.title});
  final String dogId;
  final HealthRecord? existing;
  final HealthRecordKind kind;
  final String title;

  @override
  Widget build(BuildContext context) {
    final dog = useMyDogs().data?.where((d) => d.id == dogId).firstOrNull;
    final save = useSaveHealthRecord(dogId, existing?.id);
    final remove = useDeleteHealthRecord(dogId);
    final recordKind = useState(existing?.kind ?? kind);
    final titleField = useTextEditingController(text: existing?.title ?? '');
    final date = useTextEditingController(text: existing?.date ?? localIsoDate());
    final nextDue = useTextEditingController(text: existing?.nextDue ?? '');
    final clinic = useTextEditingController(text: existing?.clinic ?? '');
    final notes = useTextEditingController(text: existing?.notes ?? '');
    final errors = useState<FieldErrors>({});
    final formError = useState<String?>(null);
    final text = _kindText(recordKind.value);

    Future<void> submit() async {
      // The form always holds every field, so the create rules (incl. nextDue > date) validate edits
      // too; the PATCH then sends all fields and the server re-checks.
      final invalid = validateHealthRecord(
        title: titleField.text,
        date: date.text,
        nextDue: nextDue.text,
        clinic: clinic.text,
        notes: notes.text,
      );
      errors.value = invalid;
      formError.value = null;
      if (invalid.isNotEmpty) return;
      String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
      try {
        await save.mutateAsync({
          'kind': recordKind.value.wire,
          'title': titleField.text.trim(),
          'date': date.text.trim(),
          'nextDue': orNull(nextDue.text),
          'clinic': orNull(clinic.text),
          'notes': orNull(notes.text),
        });
        if (context.mounted) context.pop();
      } catch (e) {
        formError.value = errorMessage(e);
      }
    }

    void confirmDelete() {
      final record = existing;
      if (record == null) return;
      haptic(HapticReason.warning);
      showAlert(
        context,
        context.t('health.deleteTitle', params: {'title': record.title}),
        message: context.t('health.deleteBody'),
        actions: [
          AlertAction(context.t('common.cancel'), style: AlertStyle.cancel),
          AlertAction(
            context.t('common.delete'),
            style: AlertStyle.destructive,
            onPressed: () => remove.mutate(
              record.id,
              onSuccess: (_) {
                if (context.mounted) context.pop();
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
      subtitle: dog != null ? context.t('health.edit.subtitle', params: {'name': dog.name}) : null,
      children: [
        FormError(formError.value),
        AppText(context.t('health.edit.kind'), type: TextType.label),
        SegmentedControl<HealthRecordKind>(
          semanticLabel: context.t('health.edit.kind'),
          options: [
            (value: HealthRecordKind.vaccination, label: context.t('health.edit.vaccination')),
            (value: HealthRecordKind.vetVisit, label: context.t('health.edit.vetVisit')),
          ],
          value: recordKind.value,
          onChanged: (k) {
            if (k != null) recordKind.value = k;
          },
        ),
        AppTextField(
          label: context.t(text.title),
          placeholder: context.t(text.placeholder),
          controller: titleField,
          error: errors.value['title'],
        ),
        AppTextField(
          label: context.t('health.edit.date'),
          placeholder: context.t('health.edit.datePlaceholder'),
          controller: date,
          error: errors.value['date'],
          keyboardType: TextInputType.datetime,
        ),
        AppTextField(
          label: context.t('health.edit.nextDue'),
          placeholder: context.t('health.edit.datePlaceholder'),
          controller: nextDue,
          error: errors.value['nextDue'],
          keyboardType: TextInputType.datetime,
        ),
        AppText(
          context.t('health.edit.reminderHint', count: reminderWindowDays),
          type: TextType.caption,
          themeColor: TextColor.muted,
        ),
        AppTextField(
          label: context.t('health.edit.clinic'),
          placeholder: context.t('health.edit.clinicPlaceholder'),
          controller: clinic,
          error: errors.value['clinic'],
        ),
        AppTextField(
          label: context.t('health.edit.notes'),
          placeholder: context.t('health.edit.notesPlaceholder'),
          controller: notes,
          error: errors.value['notes'],
          maxLines: null,
          minLines: 3,
          maxLength: 2000,
        ),
        AppButton(
          label: existing != null ? context.t('common.save') : context.t(text.save),
          loading: save.isPending,
          onPressed: submit,
        ),
        if (existing != null)
          AppButton(
            label: context.t('health.edit.delete'),
            variant: ButtonVariant.tertiary,
            loading: remove.isPending,
            onPressed: confirmDelete,
          ),
      ],
    );
  }
}
