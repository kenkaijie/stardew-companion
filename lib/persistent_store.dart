import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import "package:sembast/sembast.dart";
import 'package:path/path.dart';

class PersistentStore {

  // Singleton pattern

  static final PersistentStore _persistentStore = new PersistentStore._internal();
  PersistentStore._internal();
  static PersistentStore get instance => _persistentStore;

  // Member

  // database client, lazy load
  static Database _dbClient;
  Future<Database> get dbClient async {
    if (_dbClient != null) {
      return _dbClient;
    }
    String dbPath = (await getApplicationDocumentsDirectory()).path;
    _dbClient = await _dbFactory.openDatabase(join(dbPath, 'persistent_store.db'));
    return _dbClient;
  }

  static final DatabaseFactory _dbFactory = databaseFactoryIo;
  static final StoreRef<int, Map<String, dynamic>> _bookmarksStore = intMapStoreFactory.store('bookmarks');
  static Map<int, Map<String, dynamic>> _bookmarksCache = new Map<int, Map<String, dynamic>>();

  Future<void> addBookmark(String item) async {
    await _bookmarksStore.add(await dbClient, {'pageTitle': item});
  }

  Future<void> deleteBookmark(String item) async {
    final query = Finder(
      filter: Filter.equals('pageTitle', item)
    );
    await _bookmarksStore.delete(await dbClient, finder: query);
  }

  Future<List<String>> getStoredBookmarks() async {
    List<String> bookmarks = new List<String>();
    final query = Finder(
        filter: Filter.notNull('pageTitle'),
        sortOrders: [SortOrder('pageTitle')]
    );
    var records = await _bookmarksStore.find(await dbClient, finder: query);

    records.forEach((record) {
      _bookmarksCache.addAll({record.key: {'pageTitle': record.value['pageTitle']}});
      bookmarks.add(record.value['pageTitle']);
    });

    return bookmarks;
  }

}