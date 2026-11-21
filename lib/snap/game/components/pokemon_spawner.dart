import 'dart:math';

import 'package:flame/components.dart';
import 'package:pokeclase20263/snap/game/components/pokemon_actor.dart';
import 'package:pokeclase20263/snap/game/config/game_config.dart';
import 'package:pokeclase20263/snap/game/data/snap_pokemon.dart';
import 'package:pokeclase20263/snap/game/scene/spawn_slot.dart';

class PokemonSpawner extends Component{
  final World world;
  List<SnapPokemon> pool;
  final List<SpawnSlot> slots;
  final Random _random;

  PokemonSpawner({
    required this.world,
    required List<SnapPokemon> pool,
    required this.slots,
    Random? random,
  }) : pool = List.unmodifiable(pool),
      _random = random ?? Random() { _validatePool(this.pool); }

  void updatePool(List<SnapPokemon> newPool){
    final updatedPool = List<SnapPokemon>.unmodifiable(newPool);
    _validatePool(updatedPool);
    pool = updatedPool;
  }

  static void _validatePool(List<SnapPokemon> pool) {
    if (pool.isEmpty){
      throw ArgumentError.value(pool, 'pool', 'must not be empty');
    }

    if(pool.any(
      (pokemon) => !pokemon.spawnWeight.isFinite || pokemon.spawnWeight <= 0
    )){
      throw ArgumentError.value(pool, 'pool', 'all spawn weights must be positive and finite');
    }

    if (pool.map((pokemon) => pokemon.id).toSet().length != pool.length){
      throw ArgumentError.value(pool, 'pool', 'Poke,on Ids must be unique');
    }
  }

  bool enabled = true;
  double _countdown = GameConfig.firstSpawnDelay;
  int get activeCount => world.children.whereType<PokemonActor>().length;

  @override
  void update(double dt){
    super.update(dt);

    if(!enabled) return;

    _countdown -=  dt;
    if(_countdown > 0) return;

    _countdown = GameConfig.spawnIntervalMin + _random.nextDouble() * (GameConfig.spawnIntervalMax - GameConfig.spawnIntervalMin);
    if(activeCount < GameConfig.maxPokemonOnScreen) SpawnNow();
  }

  //Hace aparecer un pokemon
  PokemonActor? SpawnNow({SnapPokemon? def, SpawnSlot? slot}){
    final chosen = def ?? _pickDef();

    SpawnSlot? target = slot;
    if(target == null){
      final free = slots.where((s) => !s.occupied && (chosen.isFlying || !s.airOnly)).toList();
      if (free.isEmpty) return null;
      target = free[_random.nextInt(free.length)];
    }

    target.occupied = true;
    final actor = PokemonActor(pkmn: chosen, slot: target);
    world.add(actor);
    return actor;
  }

  SnapPokemon _pickDef(){
    final total = pool.fold<double>(0, (sum, d) => sum + d.spawnWeight);
    var roll = _random.nextDouble() * total;
    for (final item in pool){
      roll -= item.spawnWeight;
      if(roll <= 0) return item;
    }
    return pool.last;
  }
}