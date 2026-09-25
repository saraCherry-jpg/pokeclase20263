import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokeclase20263/models/generation_list_response.dart';
import 'package:pokeclase20263/providers/poke_api_provider.dart';
import 'package:pokeclase20263/screens/generation_detail_screen.dart';
import 'package:provider/provider.dart';

class GenerationListScreen extends StatelessWidget {
  const GenerationListScreen({super.key});

  // Numerales romanos para las generaciones (I a IX por ahora)
  static const List<String> _romanNumerals = [
    'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold( //es lo del mapeo
      appBar: AppBar(
        title: Center(child: const Text('Generaciones')),
      ),

      body: FutureBuilder<http.Response>(
        future: Provider.of<PokeApiProvider>(context, listen: false).getGenerations(),
        builder: (context, snapshot){
          if(snapshot.connectionState == ConnectionState.waiting){
            return const Center(child: CircularProgressIndicator(),);

          }else if(snapshot.hasError){
            return Center(child: Text('Error: ${snapshot.error}'),);

          }else if(!snapshot.hasData || snapshot.data!.statusCode != 200){
            return const Center(child: Text('Filed to load generations'),);

          }else{
            final generationListResponse = GenerationListResponse.fromJson(json.decode(snapshot.data!.body));
            return ListView.separated( //Formato de lista 
              padding: const EdgeInsets.all(12),
              itemCount: generationListResponse.results.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8,),
              itemBuilder:(context, index){

                final generation = generationListResponse.results[index];
                final roman = index < _romanNumerals.length ? _romanNumerals[index] : '${index + 1}'; //numeros romanos


                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile( //Apartir de aqui se hicieron los cambios 
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const Icon( //Icono de la POkebola 
                      Icons.catching_pokemon,
                      size: 32,
                    ),
                    title: Text(
                      'generation $roman',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16
                      ),
                    ),

                    subtitle: Text(
                      'generation ${index + 1}', //Aqui se numera las generaciones pokemon con numero decimal
                      style: const TextStyle(fontSize: 13),
                    ),

                    trailing: const Icon(Icons.chevron_right), //termina lo que se llego agregar:
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GenerationDetailScreen(generationId: index +1)
                        )
                      );
                    },
                  ),
                );
              },
            );
          }

        },
        
      )

    );
  }

}