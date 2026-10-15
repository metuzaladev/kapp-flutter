import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// "Juhata kohale": opens Apple Maps on iOS and the default maps app on Android with walking
/// directions to a place. Shared by the park page and the "Lähim park" card (M11).
Future<void> openDirections({required String name, required double lat, required double lng}) async {
  final label = Uri.encodeComponent(name);
  final url = Platform.isIOS ? 'maps://?daddr=$lat,$lng&dirflg=w&q=$label' : 'geo:$lat,$lng?q=$lat,$lng($label)';
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
