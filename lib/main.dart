import 'dart:async';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter/material.dart';
import 'package:stardewcompanion/app_controller.dart';
import 'package:stardewcompanion/bloc_provider.dart';
import 'package:stardewcompanion/page_viewer_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'bookmarks_service.dart';
import 'search_delegate.dart';
import 'search_suggestions_service.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppController>(
      bloc: new AppController(),
      child: MaterialApp(
        title: 'Stardew Valley Companion',
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
        ),
        home: MainPage(title: 'Stardew Valley Companion'),
      )
    );
  }
}

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  WebViewController _webViewController;

  String getURLFromPageTitle(String pageTitle) {
    return 'https://stardewvalleywiki.com/$pageTitle';
  }

  String getPageTitleFromURL(String url) {
    return url.split("https://stardewvalleywiki.com/").last;
  }

  Future<void> navigateTo(String url) async {
    if (_webViewController != null) {
      await _webViewController.loadUrl(url);
    }
  }

  Future<void> navigateToPage(String selected, String rawQuery) async {
    if (selected.startsWith("Search")) {
      await navigateTo("https://stardewvalleywiki.com/mediawiki/index.php?search=$rawQuery&fulltext=search");
    } else {
      await navigateTo(getURLFromPageTitle(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            Container(
              padding: EdgeInsets.only(
                top: 25.0,
              ),
              child: Builder(builder: (BuildContext context) {
                return WebView(
                  initialUrl: getURLFromPageTitle("Stardew_Valley_Wiki"),
                  javascriptMode: JavascriptMode.disabled,
                  onWebViewCreated: (WebViewController webViewController) {
                    setState(() {
                      _webViewController = webViewController;
                    });
                  },
                  navigationDelegate: (NavigationRequest request) {
                    if (!request.url.startsWith('https://stardewvalleywiki.com') || request.url.contains("mobileaction")) {
                      print('blocking navigation to $request}');
                      Scaffold.of(context).showSnackBar(new SnackBar(content: Text("Cannot open external sites.")));
                      return NavigationDecision.prevent;
                    }
                    print('allowing navigation to $request');
                    return NavigationDecision.navigate;
                  },
                  onPageStarted: (String url) async {
                    await BlocProvider.of<AppController>(context).pageViewerService.notifyPageLoading();
                  },
                  onPageFinished: (String url) async {
                    PageBookmark pageBookmark = PageBookmark(getPageTitleFromURL(url));
                    await BlocProvider.of<AppController>(context).pageViewerService.notifyPageLoadComplete(pageBookmark);
                    print('Page finished loading: $url');
                  },
                  gestureNavigationEnabled: false,
                );
              }),
            ),
            Positioned(
              top: 0.0,
              left: 0.0,
              right: 0.0,
              child: StreamBuilder<SearchSuggestions>(
                stream: BlocProvider.of<AppController>(context).searchSuggestionsService.searchSuggestionsStream,
                initialData: SearchSuggestions.empty,
                builder: (BuildContext context, AsyncSnapshot<SearchSuggestions> snapshot) {
                  SearchSuggestions suggestions;
                  if (snapshot.hasData) {
                    suggestions = snapshot.data;
                  } else {
                    suggestions = SearchSuggestions.empty;
                  }
                  return AppBar(
                    leading: IconButton(
                      icon: Icon(Icons.collections_bookmark),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                    title: const Text("Wiki Browser"),
                    actions: <Widget>[
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.search),
                        onPressed: () {
                          showSearch(
                              context: context,
                              delegate: PageSearch(
                                  suggestions: suggestions.suggestions,
                                  onSelect: navigateToPage,
                                  onRefreshSuggestions: () async {
                                    BlocProvider.of<AppController>(context).searchSuggestionsService.refreshSuggestions(true);
                                },
                              )
                          );
                        },
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.home),
                        onPressed: () async {
                          await navigateTo(getURLFromPageTitle("Stardew_Valley_Wiki"));
                        },
                      ),
                    ],
                    // This drop down menu demonstrates that Flutter widgets can be shown over the web view.
                  );
                },
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                color: Theme.of(context).primaryColor,
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16.0, bottom: 16.0),
                child: ListTile(
                  title: Text(
                      'Bookmarks',
                      style: Theme.of(context).primaryTextTheme.headline6),
                ),
              ),

              Expanded(
                child: StreamBuilder<List<PageBookmark>>(
                  stream: BlocProvider.of<AppController>(context).bookmarksService.bookmarksStream,
                  builder: (BuildContext context, AsyncSnapshot<List<PageBookmark>> snapshot) {
                    if (snapshot.hasData) {
                      if (snapshot.data.length > 0) {
                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: snapshot.data.length,
                          itemBuilder: (context, index) {
                            PageBookmark bookmark = snapshot.data[index];
                            return new ListTile(
                              title: Text(bookmark.pageTitle),
                              onTap: () async {
                                Navigator.pop(context);
                                await navigateTo(
                                    getURLFromPageTitle(bookmark.pageTitle));
                              },
                              trailing: IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () async {
                                  await BlocProvider.of<AppController>(context).bookmarksService.removeBookmark(bookmark);
                                },
                              ),
                            );
                          },
                        );
                      } else {
                        return Center(
                          child: Text("Bookmark a page to view it here."),
                        );
                      }
                    } else {
                      return CircularProgressIndicator();
                    }
                  },
                  initialData: [],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: StreamBuilder<PageStatus>(
          stream: BlocProvider.of<AppController>(context).pageViewerService.bookmarkStateStream,
          initialData: PageStatus.empty(),
          builder: (BuildContext context, AsyncSnapshot<PageStatus> snapshot) {
            PageStatus state = snapshot.data;
            return SpeedDial(
              elevation: 8.0,
              animatedIcon: AnimatedIcons.menu_close,
              animatedIconTheme: IconThemeData(size: 22.0),
              children: <SpeedDialChild>[
                SpeedDialChild(
                  child: state.isBookmarked ? Icon(Icons.bookmark) : Icon(Icons.bookmark_border),
                  label: state.isBookmarked ? 'Remove' : 'Bookmark',
                  labelStyle: TextStyle(fontSize: 18.0),
                  onTap: (state.isLoaded) ? () async {
                    if (state.isBookmarked) {
                      await BlocProvider.of<AppController>(context).bookmarksService.removeBookmark(state.page);
                      Scaffold.of(context).showSnackBar(SnackBar(
                          content: Text("Removed ${state.page.pageTitle} to bookmarks.")
                      ));
                    } else {
                      await BlocProvider.of<AppController>(context).bookmarksService.addBookmark(state.page);
                      Scaffold.of(context).showSnackBar(SnackBar(
                          content: Text("Added ${state.page.pageTitle} to bookmarks.")
                      ));
                    }
                  } : null,
                ),
                SpeedDialChild(
                    child: Icon(Icons.share),
                    label: 'Share',
                    labelStyle: TextStyle(fontSize: 18.0),
                    onTap: (state.isLoaded) ? () async {
                      if (state.isLoaded) {
                        await BlocProvider.of<AppController>(context).sharingService.shareString(getURLFromPageTitle(state.page.pageTitle));
                      }
                    } : null
                ),
              ],
            );
          },
        )
      ),
      onWillPop: () async {
        if (_webViewController != null) {
          if (await _webViewController.canGoBack()) {
            await _webViewController.goBack();
            return false;
          }
        }
        return true;
      },
    );
  }
}

