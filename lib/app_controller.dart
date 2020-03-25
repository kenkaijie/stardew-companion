import 'package:stardewcompanion/bloc_base.dart';
import 'package:stardewcompanion/bookmarks_service.dart';
import 'package:stardewcompanion/page_viewer_service.dart';
import 'package:stardewcompanion/persistent_store_service.dart';
import 'package:stardewcompanion/search_suggestions_service.dart';
import 'package:stardewcompanion/url_share_service.dart';

class AppController implements BlocBase {

  IPersistentStoreService _persistentStoreService;
  IBookmarksService bookmarksService;
  ISearchSuggestionsService searchSuggestionsService;
  IPageViewerService pageViewerService;
  IStringSharingService sharingService;

  AppController(){
    _persistentStoreService = new PersistentStoreService('persistent_store.db');
    bookmarksService = new BookmarksService(_persistentStoreService);
    searchSuggestionsService = new SearchSuggestionsService(_persistentStoreService, Duration(days: 7));
    pageViewerService = new PageViewerService(bookmarksService);
    sharingService = new StringSharingService();
  }

  @override
  void dispose() {
    // place in reverse order as constructor
    sharingService.dispose();
    pageViewerService.dispose();
    searchSuggestionsService.dispose();
    bookmarksService.dispose();
    _persistentStoreService.dispose();
  }

}
