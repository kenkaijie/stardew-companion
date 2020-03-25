import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import "package:sembast/sembast.dart";
import 'package:path/path.dart';
import 'package:stardewcompanion/bloc_base.dart';

abstract class IPersistentStoreService extends BlocBase {
  Future<Database> get dbClient;
}

class PersistentStoreService extends IPersistentStoreService {

  Database _dbClient;
  Future<Database> get dbClient async {
    if (_dbClient != null) {
      return _dbClient;
    }
    String dbPath = (await getApplicationDocumentsDirectory()).path;
    _dbClient = await _dbFactory.openDatabase(join(dbPath, storeName));
    return _dbClient;
  }

  final DatabaseFactory _dbFactory = databaseFactoryIo;
  final String storeName;

  PersistentStoreService(this.storeName);

  void dispose() {
    _dbClient.close();
  }

}
