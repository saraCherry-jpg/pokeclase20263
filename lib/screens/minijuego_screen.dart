/*
Nota:
Se muestra una lista de los minijuegos que tenemos disponibles:
a) Captura
b) Batalla
c) Tamagotchi

 */

import 'package:flutter/material.dart';
import 'package:pokeclase20263/widgets/menu_card.dart';


//Variables globales
const _kPrimary = Color(0xFF5345AB);
const _kSecundary = Color(0xFFE5D36D);
const _kDark = Color(0xFF1E2240);


//_____________________________ Clase Minijuegos: muestra un listado de opciones del minujuego _________________
class MinijuegoScreen extends StatelessWidget {
  const MinijuegoScreen({super.key}); //constructor 

  void _ir(BuildContext context, String titulo, IconData icono) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_)=> ProximamenteScreen(titulo: titulo, icono: icono))
    );
  }

// _______________________ Diseño de UX/ UI _________________________
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minijuego')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kDark, _kPrimary]

          ),
        ),

        //Genera las listas cada minijuego
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Elige tu aventura',
                style: TextStyle(
                  color: _kSecundary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold

                ),
              ),

              //___________ OPCION 1: Captura pokemon ________________
              const SizedBox(height: 16),
              MenuCard(
                horizontal: true,
                icono: Icons.view_in_ar_rounded,
                titulo: 'Captura AR',
                subtitulo: 'Atrapa los pokemones en relidad aumentada',
                onTap: () => _ir(context, 'Captura AR', Icons.view_in_ar_rounded)
              ),

              //_____________ OPCION 2: Batalla __________________
              const SizedBox(height: 16),
              MenuCard(
                horizontal: true,
                icono: Icons.flash_on_rounded,
                titulo: 'Batalla',
                subtitulo: 'Enfrenta a otros entrenadores',
                onTap: () => _ir(context, 'Batalla', Icons.flash_on_rounded)
              ),

              // _______________ OPCION 3: Tamagotchi ________________
              const SizedBox(height: 16),
              MenuCard(
                horizontal: true,
                icono: Icons.pets_rounded,
                titulo: 'Tamagotchi',
                subtitulo: 'Cuida a tu pokemon',
                onTap: () => _ir(context, 'Tamagotchi', Icons.pets_rounded)
              ),
            ],
          ),


        ),
      ),

    );

  }

  
}