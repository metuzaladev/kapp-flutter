import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/format.dart';
import '../core/i18n/i18n.dart';
import '../core/theme/tokens.dart';
import '../hooks/device_location.dart';
import 'button.dart';
import 'icon.dart';
import 'map_tiles.dart';
import 'screen.dart';
import 'states.dart';

/// Figma "Permissions / Location" (6:252), full screen on the Kaart tab before the map: map preview,
/// three benefit rows (incl. the privacy promise), "Luba asukoht" and "Mitte praegu". Explaining
/// before the system dialog is an HIG recommendation; iOS shows that dialog only once.
class LocationPrompt extends StatelessWidget {
  const LocationPrompt({
    super.key,
    required this.status,
    required this.canAskAgain,
    required this.onRequest,
    required this.onDismiss,
  });

  final LocationStatus status;
  final bool canAskAgain;
  final VoidCallback onRequest;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final denied = status == LocationStatus.denied && !canAskAgain;
    return AppScreen(
      title: denied ? context.t('location.deniedTitle') : context.t('location.title'),
      subtitle: denied ? context.t('location.deniedBody') : context.t('location.body'),
      children: [
        const MapPreview(dogsLabel: dogsLabel),
        if (!denied) ...[
          FeatureRow(
            icon: IconName.mapPin,
            title: context.t('location.benefitParksTitle'),
            body: context.t('location.benefitParksBody'),
          ),
          FeatureRow(
            icon: IconName.users,
            title: context.t('location.benefitFriendsTitle'),
            body: context.t('location.benefitFriendsBody'),
          ),
          FeatureRow(
            icon: IconName.shield,
            title: context.t('location.benefitPrivacyTitle'),
            body: context.t('location.benefitPrivacyBody'),
          ),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (denied)
              AppButton(label: context.t('common.openSettings'), onPressed: Geolocator.openAppSettings)
            else
              AppButton(label: context.t('location.allow'), onPressed: onRequest),
            const SizedBox(height: Spacing.one),
            AppButton(label: context.t('location.notNow'), variant: ButtonVariant.tertiary, onPressed: onDismiss),
          ],
        ),
      ],
    );
  }
}
