import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import '../models/dogs.dart';
import 'api/api_client.dart';
import 'i18n/i18n.dart';

/// Device side of the photo upload (docs/10-koerad-ja-tervis.md). Images go straight to object
/// storage with a presigned URL; they never pass through our API (64 KB body limit).

/// A photo chosen with image_picker (camera or library).
class PickedPhoto {
  const PickedPhoto({required this.path, this.width, this.height});
  final String path;
  final double? width;
  final double? height;
}

/// Larger than the server's 1600 px so its re-encode still has detail; keeps uploads ~0.5–1.5 MB.
const _maxUploadSide = 2048;
const _uploadTimeout = Duration(seconds: 60);

/// Re-encodes the picked photo as a JPEG of at most 2048 px. iPhones shoot HEIC, which the server's
/// image library cannot decode, and a 12 MP original would be a slow upload on mobile data. The
/// server still re-encodes and strips all metadata — this step is about format and size.
Future<Uint8List> preparePhoto(PickedPhoto source) async {
  final bytes = await FlutterImageCompress.compressWithFile(
    source.path,
    minWidth: _maxUploadSide,
    minHeight: _maxUploadSide,
    quality: 85,
    format: CompressFormat.jpeg,
    keepExif: false,
  );
  if (bytes == null) throw ApiRequestError(tr('errors.uploadFailed'), 400);
  if (bytes.length > maxPhotoBytes) {
    throw ApiRequestError(tr('errors.photoTooLarge', params: {'max': maxPhotoBytes ~/ 1024 ~/ 1024}), 400);
  }
  return bytes;
}

/// PUTs the bytes to the presigned URL with exactly the signed headers.
Future<void> uploadToStorage(PhotoUpload upload, Uint8List bytes) async {
  final http.Response res;
  try {
    res = await http.put(Uri.parse(upload.url), headers: upload.headers, body: bytes).timeout(_uploadTimeout);
  } catch (_) {
    throw ApiRequestError(tr('errors.uploadNetwork'), 0);
  }
  // Storage answers in XML, not in our { error, message } shape — map it to one safe text.
  if (res.statusCode < 200 || res.statusCode >= 300) throw ApiRequestError(tr('errors.uploadFailed'), res.statusCode);
}

/// One upload for any feature (dog photos, place posts): re-encode → ask our API for a presigned PUT
/// (the caller names the endpoint) → PUT the bytes. Returns the upload key the create request lists.
Future<String> uploadPickedPhoto(
  PickedPhoto picked,
  Future<PhotoUpload> Function(Map<String, Object> body) requestUpload,
) async {
  final bytes = await preparePhoto(picked);
  final upload = await requestUpload({'contentType': 'image/jpeg', 'byteSize': bytes.length});
  await uploadToStorage(upload, bytes);
  return upload.uploadKey;
}
