/*
NOTA:
Va ser la vista interactiva del minijuego del tamagotchi, respetando los endpoints
que los desarrolladores backend realizaron...
 */


//Librerias
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:pokeclase20263/models/tamagotchi_response.dart';
import 'package:pokeclase20263/providers/poke_api_provider.dart';
import 'package:provider/provider.dart';



//______________________ Clase: ________________
class TamagotchiScreen extends StatefulWidget {
  const TamagotchiScreen({super.key}); //constructor

  @override
  State<TamagotchiScreen> createState() => _TamagotchiScreenState(); //llama clase privada

}


//_____________________ Clase privada _________________
class  _TamagotchiScreenState extends State<TamagotchiScreen> {
  //TEMPORAL: No hay pantalla de "Mis pokemones capturados/ colección"
  //así que probamos con un idPokemonUser fijo a mano.

  static const int _idPokemonUserPruebas = 12;
  final AudioPlayer _audioPlayer = AudioPlayer(); //para audio o effecto de sonidos
  late Future<TamagotchiResponse> _tamagotchiFuture; //peticiones del usuario

  @override
  void initState(){
    super.initState();
    _cargarTamagotchi(); //llama metodo
  }


  //Para el audio
  @override
  void dispose(){
    _audioPlayer.dispose();
    super.dispose();
  }


  // ____________________ carga o recarga el Tamagotchi desde el backend (Metodos) _______________
  void _cargarTamagotchi() {
    final token = context.read<AuthProvider>().token ?? '';
    final provider = context.read<PokeApiProvider>();

    setState(() {
      _tamagotchiFuture = provider.getTamagotchi(token).then((response){
        final lista = TamagotchiResponse.listFromJson(response.body);

        //para la prueba, tomamos el primero que exista
        return lista.first;
      });
      
    });
  }


  // _____________________ Dispara una actividad y refresca el estado __________________
  Future<void> _realizarActividad(int id, String tipo) async {  //creear una clase privada
    final token = context.read<AuthProvider>().token ?? '';
    final provider = context.read<PokeApiProvider>();

    final response = await provider.realizarActividadTamagotchi(id,tipo,token); //llama metodo
    //Verificamos 
    if(response.statusCode == 200){
      setState(() {
        _tamagotchiFuture = Future.value(
          TamagotchiResponse.fromRawJson(response.body)

        );
      });
    }
  }


  //_____________________ reproduce el cry del pokemon (parecido al pokemon detail screen) ______________
  Future<void> _reproducirCry(int idPokemon) async { //crear una clase privada
    final url = 'https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/$idPokemon.ogg';
    await _audioPlayer.play(UrlSource(url));

  }

  //Para los Sprites de los pokemones
  String _spriteUrl(int idPokemon) =>  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$idPokemon.png';

  //_________________ Diseño UI/ UX ________________
  @override
  Widget build(BuildContext context) {
    final ColorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: ColorScheme.surface,
      appBar: AppBar(title: const Text('Mi Tamagotchi')),
      body: FutureBuilder<TamagotchiResponse>(
        future: _tamagotchiFuture,
        builder: (context, snapshot) {

          //VERIFICA:Si hay algun pokemon para criar
          if(snapshot.connectionState == ConnectionState.waiting){
            return const Center(child: CircularProgressIndicator());

          }else if(snapshot.hasError){
            return Center(child: Text('Error: ${snapshot.error}'));
        
          }else if(!snapshot.hasData){
            return const Center(child: Text('No hay pokemon por criar'));
          }

          final t = snapshot.data!;

          //estado de vivo o muerto del pokemon
          if(!t.vivo){
            return _TamagotchiMuertoView(onVolver: _cargarTamagotchi);

            //NOTA: LLama una CLASE PRIV.
          }

          //_____ Recarga _______
          return RefreshIndicator(
            onRefresh: () async => _cargarTamagotchi(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                //____________ sprite + cry ___________
                Center(
                  child: GestureDetector(
                    onTap: () => _reproducirCry(t.idPokemon),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ColorScheme.secondaryContainer.withOpacity(0.35)
                      ),

                      child: Image.network(
                        _spriteUrl(t.idPokemon), //imagen sacada de internet
                        width: 160,
                        height: 160,
                        fit: BoxFit.contain,

                        errorBuilder: (context, error, stackTrace) => Icon(Icons.catching_pokemon, size: 120, color: ColorScheme.secondary),
                      ),
                    ),
                  ),

                ),

                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Estado: ${t.estado}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ColorScheme.primary
                    )
                  ),
                ),

                const SizedBox(height: 20),
                //______________ Barras de necesidades basicas de crianza _____________
                _BarraEstado(label: 'vida', valor: t.vidaActual, total: t.vidaTotal, color: Colors.redAccent),
                _BarraEstado(label: 'Hambre', valor: t.hambre, total: 100, color: Colors.orangeAccent),
                _BarraEstado(label: 'Energía', valor: t.energia, total: 100, color: Colors.blueAccent),
                _BarraEstado(label: 'Higiene', valor: t.higiene, total: 100, color: Colors.greenAccent),


                const SizedBox(height: 24),
                //________________ botones de actividades ____________
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,

                  //____________________ actividades / opciones _______
                  children: [
                    _BotonActividad( //llama las clases privadas
                      icon: Icons.restaurant,
                      label: 'Comer',
                      onPressed: () => _realizarActividad(t.id, 'Comer'),
                    ),

                    _BotonActividad(
                      icon: Icons.bedtime,
                      label: 'Dormir',
                      onPressed: () => _realizarActividad(t.id, 'Dormir'),
                    ),

                    _BotonActividad(
                      icon: Icons.bathtub,
                      label: 'Bañar',
                      onPressed: () => _realizarActividad(t.id, 'Bañar'),
                    ),

                    _BotonActividad(
                      icon: Icons.healing,
                      label: 'Curar',
                      onPressed: () => _realizarActividad(t.id, 'Curar'),
                    ),
                  ],
                ),

              ],
            ),

          );

          
        },
      ),

    );
  }

}


// ______________________ Nueva clase (privada): barra de estados _________________
class _BarraEstado extends StatelessWidget {
  final String label;
  final int valor;
  final int total;
  final Color color;

  //Constructor
  const _BarraEstado({
    required this.label,
    required this.valor,
    required this.total,
    required this.color
  });


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $valor/$total'),
          const SizedBox(height: 4),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: valor / total,
              minHeight: 10,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],

      ),
    );
  }
}


//______________________ Nueva Clase (Privada): boton de actividad _______________
class _BotonActividad extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  //constructor
  const _BotonActividad ({
    required this.icon,
    required this.label,
    required this.onPressed

  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label)
    );
  }
}


// __________________________ Nueva Clase (privado): Tamagotchi murió __________________
class _TamagotchiMuertoView extends StatelessWidget {
  final VoidCallback onVolver;
  
  //constructor
  const _TamagotchiMuertoView({required this.onVolver});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sentiment_very_dissatisfied, size: 80, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Tu Pokemon dejo de continuar...'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onVolver, child: const Text('volver a intentar'))

        ],
      ),
    );
  }
}


