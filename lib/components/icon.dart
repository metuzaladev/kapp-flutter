import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Lucide icons (ISC licence) bundled as SVG assets — one file per icon in assets/icons, the same
/// files as the React Native app. The strokes are white and a colour filter paints them, so one asset
/// serves every accent and both schemes. Add an icon: copy its SVG from lucide-static with
/// stroke="#FFFFFF" and add a value here.
enum IconName {
  arrowLeft('arrow-left'),
  arrowRight('arrow-right'),
  bell('bell'),
  bookmark('bookmark'),
  bookmarkFilled('bookmark-filled'),
  calendar('calendar'),
  camera('camera'),
  check('check'),
  chevronRight('chevron-right'),
  clock('clock'),
  coffee('coffee'),
  compass('compass'),
  cookie('cookie'),
  dog('dog'),
  droplet('droplet'),
  dumbbell('dumbbell'),
  ellipsis('ellipsis'),
  fence('fence'),
  flag('flag'),
  flame('flame'),
  footprints('footprints'),
  gift('gift'),
  heart('heart'),
  heartFilled('heart-filled'),
  house('house'),
  image('image'),
  info('info'),
  layers('layers'),
  list('list'),
  lock('lock'),
  mail('mail'),
  map('map'),
  mapPin('map-pin'),
  messageCircle('message-circle'),
  minus('minus'),
  navigation('navigation'),
  pawPrint('paw-print'),
  plus('plus'),
  scissors('scissors'),
  search('search'),
  share('share'),
  shield('shield'),
  shoppingBag('shopping-bag'),
  slidersHorizontal('sliders-horizontal'),
  sparkles('sparkles'),
  star('star'),
  starFilled('star-filled'),
  stethoscope('stethoscope'),
  store('store'),
  sun('sun'),
  ticket('ticket'),
  trash2('trash-2'),
  trees('trees'),
  trophy('trophy'),
  user('user'),
  users('users'),
  waves('waves'),
  x('x');

  const IconName(this.file);
  final String file;

  String get asset => 'assets/icons/$file.svg';
}

/// A Lucide icon (Figma "Icon / *"). Figma uses 14 (tags), 18 (chips, badges), 20 (pins), 24 (buttons).
///
/// Always decorative: the control around it carries the label (a screen reader would otherwise read
/// nothing useful). A meaningful standalone icon must be wrapped in a widget with a label.
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 18, required this.color});

  final IconName name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.asset(
        name.asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
