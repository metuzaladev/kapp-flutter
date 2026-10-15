import 'i18n/i18n.dart';

/// Form validation on the device with the same rules as the shared Zod schemas the API uses
/// (`packages/shared/src/*.ts`), so most mistakes are caught without a round trip — the server still
/// validates again. Messages come from the shared tables in the active language (`issueText` +
/// `fieldErrors`), so they match the server's wording.
typedef FieldErrors = Map<String, String>;

/// A shared validation message, capitalised for showing under a field.
String issue(String key, [Map<String, Object?> params = const {}]) {
  final text = I18n.instance.shared(key, params);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

const passwordMin = 8;
const passwordMax = 128;

// The pragmatic e-mail check Zod 4 uses (`z.email()`): local@domain.tld without spaces.
final _email = RegExp(
  r"^(?!\.)(?!.*\.\.)([A-Za-z0-9_'+\-\.]*)[A-Za-z0-9_+-]@([A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$",
);

/// Trimmed, lower-cased e-mail or an error message.
String? emailError(String value) {
  final v = value.trim().toLowerCase();
  if (!_email.hasMatch(v)) return issue('validation.email');
  if (v.length > 254) return issue('validation.maxChars', {'max': 254});
  return null;
}

String? lengthError(String value, {int? min, int? max, String? minKey, String? requiredKey}) {
  final v = value.trim();
  if (requiredKey != null && v.isEmpty) return issue(requiredKey);
  if (min != null && v.length < min) return issue(minKey ?? 'validation.minChars', {'min': min});
  if (max != null && v.length > max) return issue('validation.maxChars', {'max': max});
  return null;
}

String? passwordError(String value) {
  if (value.length < passwordMin) return issue('validation.minChars', {'min': passwordMin});
  if (value.length > passwordMax) return issue('validation.maxChars', {'max': passwordMax});
  return null;
}

FieldErrors _collect(Map<String, String?> checks) => {
  for (final e in checks.entries)
    if (e.value != null) e.key: e.value!,
};

/// `signInInputSchema`
FieldErrors validateSignIn({required String email, required String password}) =>
    _collect({'email': emailError(email), 'password': password.isEmpty ? issue('validation.passwordRequired') : null});

/// `signUpInputSchema`: name 2–60, e-mail, password 8–128.
FieldErrors validateSignUp({required String name, required String email, required String password}) => _collect({
  'name': lengthError(name, min: 2, max: 60),
  'email': emailError(email),
  'password': passwordError(password),
});

/// `updateProfileInputSchema` (name, area ≤ 60, bio ≤ 300).
FieldErrors validateProfile({required String name, required String area, required String bio}) => _collect({
  'name': lengthError(name, min: 2, max: 60),
  'area': lengthError(area, max: 60),
  'bio': lengthError(bio, max: 300),
});

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

bool _validDate(String v) {
  if (!_isoDate.hasMatch(v)) return false;
  final d = DateTime.tryParse(v);
  return d != null && d.toIso8601String().startsWith(v);
}

String _today() => DateTime.now().toIso8601String().substring(0, 10);

/// `dogInputSchema`: name 1–40, breed ≤ 80, birth date not in the future and not older than 30
/// years, weight 0–120 kg, temperament ≤ 500.
FieldErrors validateDog({
  required String name,
  required String breed,
  required String birthDate,
  required String weight,
  required String temperament,
}) {
  String? birth;
  final b = birthDate.trim();
  if (b.isNotEmpty) {
    if (!_validDate(b)) {
      birth = issue('validation.dateFormat');
    } else if (b.compareTo(_today()) > 0) {
      birth = issue('validation.birthDateFuture');
    } else if (int.parse(b.substring(0, 4)) < DateTime.now().year - 30) {
      birth = issue('validation.checkYear');
    }
  }
  String? weightError;
  final w = weight.trim().replaceAll(',', '.');
  if (w.isNotEmpty) {
    final n = double.tryParse(w);
    if (n == null || n <= 0) {
      weightError = issue('validation.weightPositive');
    } else if (n > 120) {
      weightError = issue('validation.checkWeight');
    }
  }
  return _collect({
    'name': lengthError(name, max: 40, requiredKey: 'validation.nameRequired'),
    'breed': lengthError(breed, max: 80),
    'birthDate': birth,
    'weightKg': weightError,
    'temperament': lengthError(temperament, max: 500),
  });
}

/// `healthRecordInputSchema`: title 1–120, date (not in the future), next due after the date.
FieldErrors validateHealthRecord({
  required String title,
  required String date,
  required String nextDue,
  required String clinic,
  required String notes,
}) {
  String? dateError;
  if (!_validDate(date.trim())) {
    dateError = issue('validation.dateFormat');
  } else if (date.trim().compareTo(_today()) > 0) {
    dateError = issue('validation.dateFuture');
  }
  String? dueError;
  final due = nextDue.trim();
  if (due.isNotEmpty) {
    if (!_validDate(due)) {
      dueError = issue('validation.dateFormat');
    } else if (dateError == null && due.compareTo(date.trim()) <= 0) {
      dueError = issue('validation.nextDueAfterDate');
    }
  }
  return _collect({
    'title': lengthError(title, max: 120, requiredKey: 'validation.titleRequired'),
    'date': dateError,
    'nextDue': dueError,
    'clinic': lengthError(clinic, max: 120),
    'notes': lengthError(notes, max: 2000),
  });
}

/// "Märkasid probleemi?" (`parkReportInputSchema`) and the "Muu" reasons of user/post reports:
/// at least 10 characters so a moderator can act on it.
String? describeError(String text, {int min = 10, int max = 1000}) {
  final v = text.trim();
  if (v.length < min) return issue('validation.describeMin', {'min': min});
  if (v.length > max) return issue('validation.maxChars', {'max': max});
  return null;
}

/// Optional free text with a maximum.
String? optionalMaxError(String text, int max) =>
    text.trim().length > max ? issue('validation.maxChars', {'max': max}) : null;
