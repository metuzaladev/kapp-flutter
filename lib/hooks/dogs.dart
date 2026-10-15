import '../core/api/api_client.dart';
import '../core/photo_upload.dart';
import '../core/query/hooks.dart';
import '../core/query/query_client.dart';
import '../models/dogs.dart';
import '../models/json.dart';

class DogKeys {
  static const all = ['dogs'];
  static QueryKey photos(String dogId) => ['dogs', dogId, 'photos'];
}

class HealthKeys {
  static const all = ['health'];
  static QueryKey dog(String dogId) => ['health', 'dog', dogId];
  static const reminders = ['health', 'reminders'];
}

/// Photo URLs are signed for 15 minutes; stale after 5 minutes means a refetch on focus always
/// replaces links long before they expire (images stay cached by object path).
const signedUrlStale = Duration(minutes: 5);

QueryResult<List<Dog>> useMyDogs() =>
    useQuery(DogKeys.all, () async => listOf(await apiGet<List<Object?>>('/me/dogs'), Dog.fromJson));

/// Create (no dogId) or update; the dog list is small, refetching is cheap.
MutationHandle<Json, Dog> useSaveDog([String? dogId]) => useMutation<Json, Dog>(
  (input) async => Dog.fromJson(
    await apiSend<Json>(dogId != null ? 'PATCH' : 'POST', dogId != null ? '/me/dogs/$dogId' : '/me/dogs', input),
  ),
  onSuccess: (_, _) => queryClient.invalidateQueries(DogKeys.all),
);

MutationHandle<void, void> useDeleteDog(String dogId) => useMutation<void, void>(
  (_) => apiSend<void>('DELETE', '/me/dogs/$dogId'),
  // The dog's photos and health records are deleted with it (reminders change too).
  onSuccess: (_, _) {
    queryClient.invalidateQueries(DogKeys.all);
    queryClient.invalidateQueries(HealthKeys.all);
  },
);

QueryResult<List<DogPhoto>> useDogPhotos(String dogId) => useQuery(
  DogKeys.photos(dogId),
  () async => listOf(await apiGet<List<Object?>>('/me/dogs/$dogId/photos'), DogPhoto.fromJson),
  staleTime: signedUrlStale,
);

/// The whole three-step flow: re-encode on device → presigned PUT → server processes.
MutationHandle<PickedPhoto, DogPhoto> useAddPhoto(String dogId) => useMutation<PickedPhoto, DogPhoto>((picked) async {
  final key = await uploadPickedPhoto(
    picked,
    (body) async => PhotoUpload.fromJson(await apiSend<Json>('POST', '/me/dogs/$dogId/photos/uploads', body)),
  );
  return DogPhoto.fromJson(await apiSend<Json>('POST', '/me/dogs/$dogId/photos', {'uploadKey': key, 'caption': null}));
}, onSuccess: (_, _) => queryClient.invalidateQueries(DogKeys.photos(dogId)));

MutationHandle<String, void> useDeletePhoto(String dogId) => useMutation<String, void>(
  (photoId) => apiSend<void>('DELETE', '/me/dogs/$dogId/photos/$photoId'),
  // The deleted photo may have been the profile picture, so the dog list changes too.
  onSuccess: (_, _) {
    queryClient.invalidateQueries(DogKeys.photos(dogId));
    queryClient.invalidateQueries(DogKeys.all, exact: true);
  },
);

MutationHandle<String?, void> useSetProfilePhoto(String dogId) => useMutation<String?, void>(
  (photoId) => apiSend<void>('PUT', '/me/dogs/$dogId/profile-photo', {'photoId': photoId}),
  onSuccess: (_, _) => queryClient.invalidateQueries(DogKeys.all, exact: true),
);

QueryResult<List<HealthRecord>> useHealthRecords(String dogId) => useQuery(
  HealthKeys.dog(dogId),
  () async => listOf(await apiGet<List<Object?>>('/me/dogs/$dogId/health-records'), HealthRecord.fromJson),
);

QueryResult<List<HealthReminder>> useHealthReminders() => useQuery(
  HealthKeys.reminders,
  () async => listOf(await apiGet<List<Object?>>('/me/health-reminders'), HealthReminder.fromJson),
);

/// Create (no recordId) or update; invalidates the dog's records and the reminders.
MutationHandle<Json, HealthRecord> useSaveHealthRecord(String dogId, [String? recordId]) =>
    useMutation<Json, HealthRecord>(
      (input) async => HealthRecord.fromJson(
        await apiSend<Json>(
          recordId != null ? 'PATCH' : 'POST',
          recordId != null ? '/me/dogs/$dogId/health-records/$recordId' : '/me/dogs/$dogId/health-records',
          input,
        ),
      ),
      onSuccess: (_, _) => queryClient.invalidateQueries(HealthKeys.all),
    );

MutationHandle<String, void> useDeleteHealthRecord(String dogId) => useMutation<String, void>(
  (recordId) => apiSend<void>('DELETE', '/me/dogs/$dogId/health-records/$recordId'),
  onSuccess: (_, _) => queryClient.invalidateQueries(HealthKeys.all),
);
