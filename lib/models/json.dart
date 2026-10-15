/// JSON helpers for the API models. The API validates every response shape with the shared Zod
/// schemas (`packages/shared`), so the app reads fields directly and fails loudly on a contract
/// change instead of guessing.
typedef Json = Map<String, Object?>;

Json asJson(Object? value) => value as Json;

List<Json> asJsonList(Object? value) => (value as List<Object?>).cast<Json>();

List<T> listOf<T>(Object? value, T Function(Json json) parse) => asJsonList(value).map(parse).toList();

List<String> stringList(Object? value) => (value as List<Object?>).cast<String>();

double toDouble(Object? value) => (value as num).toDouble();

double? toDoubleOrNull(Object? value) => (value as num?)?.toDouble();

int toInt(Object? value) => (value as num).toInt();

int? toIntOrNull(Object? value) => (value as num?)?.toInt();
