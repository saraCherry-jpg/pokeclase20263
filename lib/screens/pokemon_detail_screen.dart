/*
En esta parte del archivo va ser clave en como se va a dirigir el proyecto..
para que muestre a los pokemones con sus decripciones/ caracteristicas y sonido como se escucha cada pokemon, etc..


objetivo: Lo que crea que sea necesario para mostrar la vista y datos
LA DIFERENCIA va ser la interfaz () - lo que se aplico es estetica de pokedex con un fondo animado
*/

//Librerias
import 'dart:convert'; //json.decode() convieerte el texto crudo a la API
import 'dart:math' as math; //calcula los angulos de rotación pokebolas
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart'; //los widgets
import 'package:http/http.dart' as http; //cliente http

//archivos del mismo proyecto 
import 'package:pokeclase20263/models/pokemon_detail_response.dart';
import 'package:pokeclase20263/providers/poke_api_provider.dart';
import 'package:provider/provider.dart';

//______________________________ Variables globales de Diseño de UI/UX _______________________ 
//paleta de colores (Main.dart)
const _KPrimary = Color(0xFF5345AB);
const _KSecondary = Color(0xFFE5D36D);
const _KDark = Color(0xFF1E2240);


//colores por tipo elemental - fondo de la pantalla
const Map<String, Color> KTypeColors = { //Map : es un diccionario que traduce || contexto a aplicar: los elementos por color
  'fire': Color(0xFFEE8130),
  'water': Color(0xFF6390F0),
  'grass': Color(0xFF7AC74C),
  'electric': Color(0xFFF7D02C),
  'ice': Color(0xFF96D9D6),
  'fighting': Color(0xFFC22E28),
  'poison': Color(0xFFA33EA1),
  'ground': Color(0xFFE2BF65),
  'flying': Color(0xFFA98FF3),
  'psychic': Color(0xFFF95587),
  'bug': Color(0xFFA6B91A),
  'rock': Color(0xFFB6A136),
  'ghost': Color(0xFF735797),
  'dragon': Color(0xFF6F35FC),
  'dark': Color(0xFF705746),
  'steel': Color(0xFFB7B7CE),
  'fairy': Color(0xFFD685AD),
  'normal': Color(0xFFA8A77A),

};


//__________________ Clase para definir al pokemon al seleccionar: se referencia con la ID ___________
class PokemonDetailScreen extends StatefulWidget { //StatelessWidget: aplica para cuando jalas datos
  final int pokemonId;
  final String pokemonName;

  //constructor
  const PokemonDetailScreen({super.key, required this.pokemonId, required this.pokemonName});

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
  
}
  /*
  NOTA: cada que veas el metodo createState() se requiere un StatefulWidget.

  ¿Porque no aplicamos StatelesWidget y mejor aplicamos el Statefulwidget? Simplemente porque necesita recordar cosas
  mientras el usuario interactua con la aplicación y principalmente con algunos de los componentes (botones, animación, audio, etc..)
  eso permite liberar recursos cuando desaparece.

  Poseen memoria propia y un ciclo de vida (initstate -> dispose).
  */



//___________   Nueva clase: apartado de Audio __________________________
class _PokemonDetailScreenState extends State<PokemonDetailScreen> with SingleTickerProviderStateMixin{ //with SingleTickerProviderStateMixin: actua como el proveedor de un Ticket
  final AudioPlayer _audioPlayer = AudioPlayer(); //para el audio                                      //que puede necesitar en animaciones
  bool _playingCry = false;
  late final Future<http.Response> _PokemonFuture; //Variable para que nos ajuste la carga de reproducir el sonido de c/pokemon
  late final AnimationController _bgController; //variable para la animación de fondo

  //Para la animación background
  @override
  void initState() { //En esta parte el initState() ejecuta una vez y toma dos acciones:
    super.initState();
    _PokemonFuture = Provider.of<PokeApiProvider>(context, listen: false).getPokemonDetail(widget.pokemonId); //1. dispara la peticion del http.
    _bgController = AnimationController( //2. ejecuta la animación
      vsync: this, //Ticket del provee mixin
      duration: const Duration(seconds: 10),
    )..repeat();

  }

  //Para el audio 
  @override
  void dispose() { //Cierra ()
    _audioPlayer.dispose(); //audio para los pokemones
    _bgController.dispose(); //background animación
    super.dispose();
  }

  //____________________ Metodo async: audio ______________
  Future<void> _playCry() async {
    setState(() => _playingCry = true);
    final url =
      'https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/${widget.pokemonId}.ogg'; //enlace de la API del reproductor del eefecto de sonido del pokemon (id)

    try{
      await _audioPlayer.play(UrlSource(url));

    }catch (_){
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el sonido')),
        );
      }

    } finally {
      if(mounted) setState(() => _playingCry = false);
    }

  }

  /*
  NOTA: En la parte de la exception del metodo Asynic que si llega a fallar no reproduce el sonido
  por alguna falla en ese caso sin internet, manda a imorimir un mensaje de la falla.
  */


  //Para ver los detalles del pokemon
  @override
  Widget build(BuildContext context) { //Widget: es un bloqueo para tener una buena organización para la vista
    return Scaffold( //Scaffold: material visual para herrmientas flotantes
      body: FutureBuilder<http.Response>(
        future: _PokemonFuture,
        builder: (context, snapshot) {

          //Verifica la petición de la captura de información 
          if(snapshot.connectionState == ConnectionState.waiting){
            return const Center(child:  CircularProgressIndicator()); //Aqui 

          }else if(snapshot.hasError){
            return const Center(child: Text('Failed to load Pokemon detail'));

          }else if(!snapshot.hasData || snapshot.data!.statusCode != 200){
            return const Center(child: Text('failed to load pokemon detail'));

          }else{
            final pokemon = PokemonDetailResponse.fromJson(json.decode(snapshot.data!.body)); //texto crudo (JSON) de la respuesta
            final types = pokemon.types;
            final primaryType = types.isNotEmpty ? types.first : 'normal';
            final bgColor = KTypeColors[primaryType] ?? _KPrimary;

            //______________ ESTRUCTURA VISUAL ______________
            //Animación cuando muestras el diferente tipo de pokemon (electrico, fuego, agua, planta, etc..)
            return AnimatedContainer(
              duration: const Duration(microseconds: 400), //Se le puede modificar los segundos
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bgColor, bgColor.withOpacity(0.6)],
                )
              ),

              //Aqui agreamos: fondo de pokebolas detras de la pokedex 
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer( //ocupa la pantalla y puedes segior tocando el boton de producir el sonido c/pokemon
                      child: _pokeballBackground(animation: _bgController), //Llama un metodo
                    ),
                  ),


                  //El contenido real, donde se ubica la tarjeta pokedex
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: _buildPokedexFrame(pokemon, types),
                            ),
                          ),
                        ),  
                      ],
                    ),
                  ),
                ],

              )
            );
          }
        },
      ),
    );
  }


  //__________ Metodo: Dispositivo Pokedex y Sprites del Pokemon _________
  Widget _buildPokedexFrame(PokemonDetailResponse pokemon, List<String> types){

    //1. Apartir de aqui construye/dibuja el dispositivo
    return Container(
      width: 300,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFCC1F2A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),

      //dibuja el boton del lado derecho 
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22, 
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.shade300,
                  border: Border.all(color: Colors.black87, width: 3),
                ),
              ),

              //Dibuja la parte de la "bocina"
              const SizedBox(width: 8),
              Container(
                height: 6,
                width: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF8A1319),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              //Dibuja los botones del lado derecho
              const Spacer(),
              _dot(_KSecondary), //metodos auxiliares del encabezado y llama metodo
              const SizedBox(width: 6),
              _dot(Colors.green),
            ],
          ),

          //dibuja la pantalla
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0E4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black87, width: 4),
            ),

            //apartado de las descripciones
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.pokemonName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _KDark,
                      ),
                    ),

                    //descripción general
                    Text(
                      '#${widget.pokemonId.toString().padLeft(3, '0')}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),

                //Parte del bloque a modificar/ ajustes pokemon-pantalla:
                const SizedBox(height: 8),
                Container(
                  height: 140, //90 //Cambias el tamaño del la "pantalla" donde estan ubicados los pokemones
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),

                  //Sprite del pokemon: Recordemos que lo trajimos del enlace de la API knaskdnaskl
                  child: Center(
                    child: Image.network(
                      pokemon.imageUrl,
                      height: 110, //Aqui cambias el tamaño del pokemon
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),

                //diseña el boton de la categoria: fuego, agua, tierra, etc..
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: types.
                    map((t) => Chip(
                      label: Text(
                        t,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                      ),
                      backgroundColor: KTypeColors[t] ?? _KPrimary, //tipo pokemon que reafirma que es tipo normal
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    )).
                    toList(),
                ),

                //mas decrpicion
                const SizedBox(height: 10),
                _buildStatsCard(pokemon), //construye el recuadro de las estadisticas, por ende se manda a llamar este metodo
                const SizedBox(height: 6),
                Text(
                  'Altra: ${pokemon.height} m   peso: ${pokemon.weight} kg',
                  style: const TextStyle(fontSize: 11, color: _KDark),

                ),

                //apartado del audio 
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _playingCry ? null : _playCry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _KPrimary,
                      foregroundColor: Colors.white,

                    ),
                    
                    icon: _playingCry 
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white, 
                        ),
                      )
                      :const Icon(Icons.volume_up, size: 18),
                      label: const Text('Reproducir cry'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

  }//Fin del metodo del BuildPokedex



  //__________ Metodo para la carta/ tarjeta pokemon ______________
  /*En ese construye el recuadro ambar con las estadisticas*/
  Widget _buildStatsCard(PokemonDetailResponse pokemon){
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _KSecondary.withOpacity(0.25),
        border: Border.all(color: _KSecondary, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estadisticas', style: TextStyle(fontSize: 10, color: _KDark)),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 4,
            children: pokemon.stats.entries.
            map((e) => Text(
              '${e.key}: ${e.value}',
              style: const TextStyle(fontSize: 11, color: _KDark),
            ))
            .toList()

          ),
        ],
      ),
    );

  }//Fin del metodo de la carta


  //Metodo auxiliar de los circulos chiquitos en las cuales llamaron al metodo
  Widget _dot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );  

}


//_____________ Nueva clase: background animado de las pokebolas ________________
class _pokeballBackground extends StatelessWidget{ //StatelessWidget: no maneja estado propio
  final Animation<double> animation;
  const _pokeballBackground({required this.animation}); //constructor

  //posicion vertical (del 0.0 al 1.0) desfase de arranque y tamaño de la pokebola
  static const List<double> _verticalPositions = [0.08, 0.22, 0.4, 0.55, 0.7, 0.85, 0.95];
  static const List<double> _phaseOffsets = [0.0, 0.15, 0.32, 0.48, 0.6, 0.78, 0.9];
  static const List<double> _sizes = [34, 50, 26, 44, 32, 56, 38];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {

        return AnimatedBuilder(
          animation: animation,
          builder: (context, _){

            return Stack(
              children: List.generate(_verticalPositions.length, (i){
                final progress = (animation.value + _phaseOffsets[i]) % 1.0;
                final size = _sizes[i];
                final left = progress * (constraints.maxWidth + size) - size;
                final top = _verticalPositions[i] * constraints.maxHeight;
                final spin = math.pi / 4 + (animation.value + _phaseOffsets[i]) * 2 * math.pi;

                return Positioned(
                  left: left,
                  top: top,
                  child: Transform.rotate(
                    angle: spin,
                    child: Opacity(
                      opacity: 0.16,
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: _PokeballPainter(), //llama el metodo...

                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
} //Fin de la clase


// _________ NUeva clase: Acceso directo del cnavas para dibujar la pokebola _________
class _PokeballPainter extends CustomPainter{
  @override
  void paint(Canvas canvas, Size size) { 
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.09;

    final fillPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

    //mitad superior rellena
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height / 2 )); //limita el area (mitad para abajo)
    canvas.drawCircle(center, radius - strokeWidth / 2, fillPaint); //mitad para arriba
    canvas.restore(); //restaura estado de canvas

    //Contornos:
    canvas.drawCircle(center, radius - strokeWidth / 2, strokePaint); //completo
    canvas.drawLine(Offset(0, size.height / 2 ), Offset(size.width, size.height / 2), strokePaint); //divisora
    //boton central
    canvas.drawCircle(center, radius * 0.22, fillPaint);
    canvas.drawCircle(center, radius * 0.22, strokePaint);

    
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false; 
  //No será necesario que ejecute el paint () (recaulcular el dibujo inecesariamente)
  
}//Fin de la clase