import "package:rxdart/rxdart.dart";
import 'package:sembast/sembast.dart';
import 'package:stardewcompanion/bloc_base.dart';
import 'package:stardewcompanion/persistent_store_service.dart';

class PageBookmark {
  final String pageTitle;
  PageBookmark(this.pageTitle);

  Map<String, dynamic> toMap() {
    return {'pageTitle': pageTitle};
  }

  factory PageBookmark.empty() {
    return PageBookmark(null);
  }

  @override
  int get hashCode => pageTitle.hashCode;

  @override
  bool operator ==(other) {
    return other is PageBookmark && pageTitle == other.pageTitle;
  }
}

abstract class IBookmarksService extends BlocBase {
  ValueStream<List<PageBookmark>> get bookmarksStream;

  Future<List<PageBookmark>> get bookmarks;

  Future<void> addBookmark(PageBookmark bookmark);

  Future<void> removeBookmark(PageBookmark bookmark);

  Future<bool> containsBookmark(PageBookmark bookmark);
}

class BookmarksService implements IBookmarksService {

  final IPersistentStoreService _persistentStore;

  ValueStream<List<PageBookmark>> bookmarksStream;

  BehaviorSubject<List<PageBookmark>> _bookmarksSubject;

  /* Sembast based impl */
  bool _isBookmarksCached = false;
  final StoreRef<int, Map<String, dynamic>> _bookmarksStore = intMapStoreFactory.store('bookmarks');
  final Map<int, PageBookmark> __bookmarksMapCache = new Map<int, PageBookmark>();
  Future<Map<int, PageBookmark>> get _bookmarksMap async {
    if (!_isBookmarksCached) {
      final query = Finder(
          filter: Filter.notNull('pageTitle'),
          sortOrders: [SortOrder('pageTitle')]
      );
      var records = await _bookmarksStore.find(
          await _persistentStore.dbClient, finder: query);

      records.forEach((RecordSnapshot<int, Map<String, dynamic>> record) {
        __bookmarksMapCache.addAll(
            {record.key: PageBookmark(record.value['pageTitle'])});
      });
      _isBookmarksCached = true;
    }
    return __bookmarksMapCache;
  }

  Future<List<PageBookmark>> get bookmarks async {
    return (await _bookmarksMap).values.toList();
  }

  BookmarksService(this._persistentStore) {
    _bookmarksSubject = new BehaviorSubject.seeded([]);
    _bookmarksSubject.onListen = () async {
      _updateBookmarksStream(await _bookmarksMap);
    };
    bookmarksStream = _bookmarksSubject.stream;
  }

  void _updateBookmarksStream(Map<int, PageBookmark> newBookmarks) {
    _bookmarksSubject.add(newBookmarks.values.toList());
  }

  Future<void> addBookmark(PageBookmark bookmark) async {
    if (bookmark != PageBookmark.empty()) {
      Map<String, dynamic> dbEntry = bookmark.toMap();
      int key = await _bookmarksStore.add(
          await _persistentStore.dbClient, dbEntry);
      (await _bookmarksMap)[key] = bookmark;
      _updateBookmarksStream(await _bookmarksMap);
    }
  }

  Future<void> removeBookmark(PageBookmark bookmark) async {
    final query = Finder(
        filter: Filter.equals('pageTitle', bookmark.pageTitle)
    );
    var keys = await _bookmarksStore.findKeys(await _persistentStore.dbClient, finder: query);
    await Future.forEach(keys, (int key) async {
      await _bookmarksStore.record(key).delete(await _persistentStore.dbClient);
      (await _bookmarksMap).remove(key);
    });
    _updateBookmarksStream(await _bookmarksMap);
  }

  Future<bool> containsBookmark(PageBookmark bookmark) async {
    return (await bookmarks).contains(bookmark);
  }

  void dispose() {
    _bookmarksSubject.close();
  }

}
