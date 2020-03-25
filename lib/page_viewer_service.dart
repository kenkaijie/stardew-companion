import 'package:rxdart/rxdart.dart';
import 'package:stardewcompanion/bloc_base.dart';
import 'package:stardewcompanion/bookmarks_service.dart';


class PageStatus {
  bool isLoaded;
  bool isBookmarked;
  PageBookmark page;

  PageStatus(this.isLoaded, this.isBookmarked, this.page);

  factory PageStatus.empty() {
    return PageStatus(false, false, PageBookmark.empty());
  }
}

abstract class IPageViewerService extends BlocBase {
  ValueStream<PageStatus> bookmarkStateStream;

  Future<void> notifyPageLoading();
  Future<void> notifyPageLoadComplete(PageBookmark bookmark);
}

class PageViewerService implements IPageViewerService{
  PageStatus _currentStatus = PageStatus.empty();

  ValueStream<PageStatus> bookmarkStateStream;

  BehaviorSubject<PageStatus> _bookmarkStateSubject;

  final IBookmarksService _bookmarksService;

  PageViewerService(this._bookmarksService) {
    _bookmarkStateSubject = new BehaviorSubject<PageStatus>.seeded(_currentStatus);
    bookmarkStateStream = _bookmarkStateSubject.stream;
    _bookmarksService.bookmarksStream.listen(_onBookmarkChange);
  }

  void _onBookmarkChange(List<PageBookmark> event) {
    _currentStatus.isBookmarked = event.contains(_currentStatus.page);
    updateBookmarksStateStream(_currentStatus);
  }

  void updateBookmarksStateStream(PageStatus newState) {
    _bookmarkStateSubject.add(newState);
  }

  Future<void> notifyPageLoadComplete(PageBookmark bookmark) async {
    _currentStatus.page = bookmark;
    _currentStatus.isLoaded = true;
    _currentStatus.isBookmarked = await _bookmarksService.containsBookmark(bookmark);
    updateBookmarksStateStream(_currentStatus);
  }

  Future<void> notifyPageLoading() async {
    _currentStatus.page = PageBookmark.empty();
    _currentStatus.isBookmarked = false;
    _currentStatus.isLoaded = false;
    updateBookmarksStateStream(_currentStatus);
  }

  void dispose() {
    _bookmarkStateSubject.close();
  }
}
