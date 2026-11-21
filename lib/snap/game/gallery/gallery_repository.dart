import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


class GalleryRepository {
  GalleryRepository._();

  static final GalleryRepository instance = GalleryRepository._();

  static const String _folderName = 'snap_potos';

  //Lista observable de capturas
  final ValueNotifier<List<File>> images = ValueNotifier([]);

  Directory? _dir;
  bool _initialized = false;

  //Carga las capturas del disco
  Future<void> init() async {
    if(_initialized) return;
    _initialized = true;

    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory(path.join(docs.path, _folderName));
    if (!await _dir!.exists()){
      await _dir!.create(recursive: true);
    }
    await _loadExisting();
  }

  //arga las imagenes desde la carpeta
  Future<void> _loadExisting() async {
    if (_dir == null) return;

    //Ordena por nombre
    final entries = (await _dir!.list().toList())
    ..sort((a,b) => b.path.compareTo(a.path));

    final loaded = entries.whereType<File>().where((file) => file.path.toLowerCase().endsWith('.png')).toList();
    images.value = loaded;
  }

  Future<File> add(Uint8List bytes) async {
    if (_dir == null) await init();
    final name = 'snap_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path.join(_dir!.path, name));
    await file.writeAsBytes(bytes, flush: true);
    images.value = [file, ...images.value];
    return file;
  }

  Future<void> remove(File file) async {
    try{
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint("No se pudo borrar ${file.path}: error");
    }
    images.value = images.value.where((file) => file.path != file.path).toList();
  }

  String? get directoryPath => _dir?.path;

  void clear() {
    images.value = [];
  }

}