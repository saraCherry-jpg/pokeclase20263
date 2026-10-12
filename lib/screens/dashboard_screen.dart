/*
NOTA:
Es la interfaz del bashborad o el menu principal o el nucleo de la aplicación
en cual se tomará decisiónes a donde se va dirigir

unas de las rutas:
a) cerrar sesión --> dirige el login/Register
b) intercambio (pokemones)
c) capturados/colecionados (pokemon atrapados)
d) pokedex (listas generación y los detalles de las generaciones y pokemon) (que es lo que hicimos)
e) minijuegos (capturas, batalla y Tamagotchi) --> c/u tiene sus vistas

 */

import 'package:flutter/material.dart';

//los demas importados en el archivo de es intanciados de otros archivos...
import 'package:pokeclase20263/screens/auth_screen.dart';
import 'package:pokeclase20263/screens/generation_list_screen.dart';
import 'package:pokeclase20263/screens/minijuego_screen.dart';
import 'package:pokeclase20263/widgets/menu_card.dart';


//Variables globales (paletas de colores)
const _kPrimary = Color(0xFF5345AB);
const _kSecundary = Color(0xFFE5D36D);
const _kDark = Color(0xFF1E2240);


//________________________ Clase _______________________
class DashboardScreen extends StatelessWidget {
  const DashboardScreen ({super.key}); //constructor

  void _ir(BuildContext context, Widget pantalla){
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  //Diseño UX/ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            ),
          ),
        ],
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

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Hola entrenador!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900
                  ),
                ),

                const SizedBox(height: 4),
                const Text(
                  '¿Qué quieres hacer hoy?',
                  style: TextStyle(color: _kSecundary, fontSize: 15),
                ),

                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.9,

                    children: [
                      //Intercambio
                      MenuCard(
                        icono: Icons.swap_horiz_rounded,
                        titulo: 'Intercambio',
                        subtitulo: 'Cambia Pokemón con otros',
                        onTap: () => _ir(
                          context,
                          const ProximamenteScreen(
                            titulo: 'Intercambio',
                            icono: Icons.swap_horiz_rounded
                          ),
                        ),
                      ),

                      //Capturados
                      MenuCard(
                        icono: Icons.catching_pokemon,
                        titulo: 'Capturados',
                        subtitulo: 'Tu Colección',
                        onTap: () => _ir(
                          context,
                          const ProximamenteScreen(
                            titulo: 'Capturados',
                            icono: Icons.catching_pokemon
                          ),
                        ),
                      ),


                      //Pokedex
                      MenuCard(
                        icono: Icons.catching_pokemon,
                        titulo: 'Pokedex',
                        subtitulo: 'Explora las generaciones',
                        onTap: () => _ir(context, GenerationListScreen()), //Lista de las generaciones pokemon
                      ),


                      
                      //Minijuegos (Opciones: Capturas, Batallas y Tamagotchi)
                      MenuCard(
                        icono: Icons.sports_esports_rounded,
                        titulo: 'Minijuegos',
                        subtitulo: 'Captura, batalla y más',
                        onTap: () => _ir(context, const MinijuegoScreen()), //Lista de los minijuegos (llama el metodo/ clase)
                      ),
                      

                    ],

                  ),
                ),


              ],
            ),

          ),
        ),
      ),
    );
    
  }

  

}