import 'dart:convert';
import 'package:flutter/foundation.dart';

class GenerationListResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<GenerationItem> results;


  //Constructor
  GenerationListResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results
  });

  // _________________________________ METODOS ___________________________
  //Metodo para recibir directamente el response.body (String)
  factory GenerationListResponse.fromRawJson(String str) =>
  GenerationListResponse.fromJson(json.decode(str));


  //Metodo para recibir el Map ya decodificado
  factory GenerationListResponse.fromJson(Map<String, dynamic>
  json) {
    var list = json['results'] as List? ?? [];
    List<GenerationItem> resultList = list.map((i) =>
    GenerationItem.fromJson(i)).toList();

    //Retornar
    return GenerationListResponse (
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previos'],
      results: resultList
    );
  }
  
} //Fi de la clase List_Response



// _____________________ Nueva clase ____________________________
class GenerationItem{
  final String name;
  final String url;

  //Constructor
  GenerationItem({
    required this.name,
    required this.url
  });

  //_____________________________ Metodos ______________________
  //Metodo para recibir directamente el Item.body (String)
  factory GenerationItem.fromRawJson(String str) =>
  GenerationItem.fromJson(json.decode(str));

  //Metodo para recibir el Map ya decodificado
  factory GenerationItem.fromJson(Map<String, dynamic> json){
    return GenerationItem(
      name : json['name'] ?? '',
      url: json['url'] ?? ''
    );
  }
  Map<String, dynamic> toJson() => {
    "name": name,
    "url": url
  };

  //Extraer el id de la generación directamente desde la URL
  int get id {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return int.parse(segments.last);
  }



}