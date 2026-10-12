import 'package:flutter/material.dart';

//Paletas de colores (variables globales)
const _kPrimary = Color(0xFF5345AB);
const _kSecundary = Color(0xFFE5D36D);
const _kDark = Color(0xFF1E2240);


//Tarjeta del menu:n vertical: cuadricula || horizontal: lista
class MenuCard extends StatelessWidget {
  //variables locales
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final bool horizontal;

  //constructor
  const MenuCard ({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.horizontal = false

  });
  
  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(22) ;

    final insignia = Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
      child: Icon(icono, color: _kSecundary, size: 30),
    );

    final textos = [
      Text(
        titulo,
        style: const TextStyle(
          color: _kDark,
          fontSize: 16,
          fontWeight: FontWeight.w800
        ),
      ),

      const SizedBox(height: 4),
      Text(
        subtitulo,
        textAlign: horizontal ? TextAlign.start : TextAlign.center,
        style: TextStyle(color: _kDark.withValues(alpha: 0.6), fontSize: 12),
      ),
    ];

    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: borde,
        side: const BorderSide(color: _kSecundary, width: 2)
      ),

      child: InkWell(
        borderRadius: borde,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: horizontal ? Row(
            children: [
              insignia,
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: textos
                ),
              ),
              
              const Icon(Icons.chevron_right_rounded, color: _kPrimary),
            ],

          ) 
          : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [insignia, const SizedBox(height: 12), ...textos],
          ),

        ), 
      ),
    );

  }
}


//______________________ Nueva clase pantalla temporal: seleciones que aun no existe __________________
class ProximamenteScreen extends StatelessWidget {
  final String titulo;
  final IconData icono;


  //Constructor
  const ProximamenteScreen ({
    super.key,
    required this.titulo,
    required this.icono,

  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kDark, _kPrimary],
          ),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 80,
              color: _kSecundary,
            ),

            const SizedBox(height: 16),
            const Text(
              'Proximamente',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2
              ),
            ),
          ],
        ),
      ),
    );
  }

  
}
