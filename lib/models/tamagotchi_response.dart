/*
NOTA:
Es el modelo del minijuego del tamagotchi, respetando los endpoints
que los desarrolladores backend realizaron...

PD: La BD en pocas palabras
 */

import 'dart:convert';

class TamagotchiResponse {
  //Variables locales => CAMPOS
  final int id;
  final int idPokemonUser;
  final int idPokemon;
  final int hambre;
  final int energia;
  final int higiene;
  final int vidaActual;
  final int vidaTotal;
  final String estado;
  final bool vivo;
  final DateTime fechaAdopcion;

  
  //Constructor
  TamagotchiResponse({
    required  this.id,
    required this.idPokemonUser,
    required this.idPokemon,
    required this.hambre,
    required this.energia,
    required this.higiene,
    required this.vidaActual,
    required this.vidaTotal,
    required this.estado,
    required this.vivo,
    required this.fechaAdopcion,

  });

  //____________________ METODOS:  ____________________
  //Metodo para recibir directamente el Tamagotchi.body (String)
  factory TamagotchiResponse.fromRawJson(String str) => TamagotchiResponse.fromJson(json.decode(str));

  //Metodo para recibir el Map ya decodificado
  factory TamagotchiResponse.fromJson(Map<String, dynamic> json){
    return TamagotchiResponse(
      id: json['id'],
      idPokemonUser: json['idPokemonUser'],
      idPokemon: json['idPokemon'],
      hambre: json['hambre'],
      energia: json['energia'],
      higiene: json['higiene'],
      vidaActual: json['vidaActual'],
      vidaTotal: json['vidaTotal'],
      estado: json['estado'],
      vivo: json['vivo'],
      fechaAdopcion: DateTime.parse(json['fechaAdopcion']) //Trad. de fecha a String
    );
  }


  Map<String, dynamic> toJson() => {
    'id': id,
    'idPokemonUser': idPokemonUser,
    'idPokemon': idPokemon,
    'hambre': hambre,
    'energia': energia,
    'higiene': higiene,
    'vidaActual': vidaActual,
    'vidaTotal': vidaTotal,
    'estado': estado,
    'vivo': vivo,
    'fechaAdopcion': fechaAdopcion.toIso8601String()

  };


  //Metodo: todos los campos en vez de dar un arreglo..
  //te lo devuelve en forma de lista
  static List<TamagotchiResponse> listFromJson(String str) {
    final List data = json.decode(str);
    return data.map((e) => TamagotchiResponse.fromJson(e)).toList();
  }



}//Fin de la clase