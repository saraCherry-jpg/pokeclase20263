import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokeclase20263/screens/dashboard_screen.dart';
import 'package:pokeclase20263/screens/pokemon_center_screen.dart';

enum _MenuDestination { home, pokemonCenter, exit }

class MenuButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onMenuOpened;
  final VoidCallback? onMenuClosed;

  const MenuButton({
    super.key,
    this.onPressed,
    this.onMenuOpened,
    this.onMenuClosed,
  });

  Future<void> _openMenu(BuildContext context) async {
    onMenuOpened?.call();
    final destination = await showDialog<_MenuDestination>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => SimpleDialog(
        key: const Key('navigation-menu'),
        backgroundColor: const Color(0xFF5345AB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5D36D), width: 4),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          for (final option in const {
            _MenuDestination.home: 'INICIO',
            _MenuDestination.pokemonCenter: 'CENTRO POKEMON',
            _MenuDestination.exit: 'SALIR',
          }.entries)
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              onPressed: () => Navigator.pop(dialogContext, option.key),
              child: Text(
                option.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NESFont',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
    onMenuClosed?.call();
    if (!context.mounted || destination == null) return;
    switch (destination) {
      case _MenuDestination.home:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (_) => false,
        );
      case _MenuDestination.pokemonCenter:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PokemonCenterScreen()),
          (route) => route.isFirst,
        );
      case _MenuDestination.exit:
        await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuSize = (MediaQuery.sizeOf(context).width * 0.40)
        .clamp(54.0, 66.0)
        .toDouble();
    return IconButton(
      onPressed: () {
        if (onPressed != null) {
          onPressed!();
          return;
        }
        _openMenu(context);
      },
      tooltip: 'Abrir menu',
      padding: EdgeInsets.zero,
      iconSize: menuSize,
      icon: SizedBox(
        width: menuSize,
        height: menuSize,
        child: Image.asset('assets/images/menu.png', fit: BoxFit.contain),
      ),
    );
  }
}
