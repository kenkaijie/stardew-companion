import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import "package:sembast/sembast.dart";
import 'package:path/path.dart';
import 'package:rxdart/rxdart.dart';

class PageBookmark {
  final String pageTitle;
  PageBookmark(this.pageTitle);

  Map<String, dynamic> toMap() {
    return {'pageTitle': pageTitle};
  }

  @override
  int get hashCode => pageTitle.hashCode;

  @override
  bool operator ==(other) {
    return other is PageBookmark && pageTitle == other.pageTitle;
  }
}

class SearchSuggestions {

  final int cachedTimestamp;
  final List<String> suggestions;

  Map<String, dynamic> toMap() {
    return {'cachedTimestamp': cachedTimestamp, 'suggestions': suggestions};
  }

  factory SearchSuggestions.fromMap(Map<String, dynamic> map) {
    return SearchSuggestions(map['cachedTimestamp'], map['suggestions'].toList().cast<String>());
  }

  SearchSuggestions(this.cachedTimestamp, this.suggestions);

  static final SearchSuggestions empty = SearchSuggestions(0, []);
}

class PersistentStore {

  // Singleton pattern

  static final PersistentStore _persistentStore = new PersistentStore._internal();
  static PersistentStore get instance => _persistentStore;

  PersistentStore._internal() {
    bookmarksStreamController.onListen = getStoredBookmarks;
    searchSuggestionsController.onListen = getSearchSuggestions;
  }


  // Bookmarks Store
  bool _isBookmarksCached = false;

  Database _dbClient;
  Future<Database> get dbClient async {
    if (_dbClient != null) {
      return _dbClient;
    }
    String dbPath = (await getApplicationDocumentsDirectory()).path;
    _dbClient = await _dbFactory.openDatabase(join(dbPath, 'persistent_store.db'));
    return _dbClient;
  }

  final DatabaseFactory _dbFactory = databaseFactoryIo;
  final StoreRef<int, Map<String, dynamic>> _bookmarksStore = intMapStoreFactory.store('bookmarks');
  Map<int, PageBookmark> _bookmarksCache = new Map<int, PageBookmark>();
  final BehaviorSubject<Map<int, PageBookmark>> bookmarksStreamController = new BehaviorSubject<Map<int, PageBookmark>>.seeded({});

  Future<void> addBookmark(PageBookmark item) async {
    Map<String, dynamic> dbEntry =  item.toMap();
    int key = await _bookmarksStore.add(await dbClient, dbEntry);
    _bookmarksCache[key] = item;
    bookmarksStreamController.add(_bookmarksCache);
  }

  Future<void> deleteBookmark(PageBookmark item) async {
    final query = Finder(
      filter: Filter.equals('pageTitle', item.pageTitle)
    );
    var keys = await _bookmarksStore.findKeys(await dbClient, finder: query);
    await Future.forEach(keys, (int key) async {
      await _bookmarksStore.record(key).delete(await dbClient);
      _bookmarksCache.remove(key);
    });
    bookmarksStreamController.add(_bookmarksCache);
  }

  Future<bool> containsBookmark(PageBookmark item) async {
    return _bookmarksCache.containsValue(item);
  }

  Future<void> getStoredBookmarks() async {
    if (!_isBookmarksCached) {
      _isBookmarksCached = true;
      final query = Finder(
          filter: Filter.notNull('pageTitle'),
          sortOrders: [SortOrder('pageTitle')]
      );
      var records = await _bookmarksStore.find(await dbClient, finder: query);

      records.forEach((RecordSnapshot<int, Map<String, dynamic>> record) {
        _bookmarksCache.addAll(
            {record.key: PageBookmark(record.value['pageTitle'])});
      });
    }
    bookmarksStreamController.add(_bookmarksCache);
  }

  // SearchTerms Store
  final StoreRef<int, Map<String, dynamic>> searchTermsStore = intMapStoreFactory.store('searchSuggestions');

  // for accessors, the search suggestions should only ever store the latest, along with a time stamp

  SearchSuggestions _searchSuggestionsCache = SearchSuggestions.empty;
  final BehaviorSubject<SearchSuggestions> searchSuggestionsController = new BehaviorSubject<SearchSuggestions>();
  bool _isSearchSuggestionsCached = false;

  Future<void> updateSearchSuggestions(SearchSuggestions newSuggestions) async {
    await searchTermsStore.add(await dbClient, newSuggestions.toMap());
    // refresh the Cache, note clearing of the database will happen on next startup (via the get)
    _searchSuggestionsCache = newSuggestions;
    searchSuggestionsController.add(_searchSuggestionsCache);
  }
  
  Future<void> getSearchSuggestions() async {
    if (!_isSearchSuggestionsCached) {
      _isSearchSuggestionsCached = true;
      final query = Finder(
        // just really need something to get all values
        filter: Filter.notNull('cachedTimestamp'),
        sortOrders: [SortOrder('cachedTimestamp', false)]
      );

      var records = await searchTermsStore.find(await dbClient, finder: query);

      // if we happen to have more than 1 cache, just delete all except the first
      await Future.forEach(records, (RecordSnapshot<int, Map<String, dynamic>> record) async {
        if (record != records.first) {
          await searchTermsStore.record(record.key).delete(await dbClient);
        } else {
          _searchSuggestionsCache = SearchSuggestions.fromMap(record.value);
        }
      });
    }
    searchSuggestionsController.add(_searchSuggestionsCache);
  }

  void dispose() {
    bookmarksStreamController.close();
    searchSuggestionsController.close();
  }

}