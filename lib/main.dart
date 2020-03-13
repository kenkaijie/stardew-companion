import 'dart:async';
import 'dart:convert';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:stardewcompanion/persistent_store.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share/share.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stardew Valley Companion',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: MainPage(title: 'Stardew Valley Companion'),
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

  bool currentIsBookmarked = false; // flag to indicate if the current url is already in the bookmarks list
  String currentUrl;
  Stream<List<PageBookmark>> bookmarksStream;
  Stream<SearchSuggestions> searchSuggestionsStream;

  Future<List<String>> createSearchItems() async {
    List<String> searchTerms = new List<String>();
    String continueToken = "";
    do {
      continueToken = await getPagesLimited(searchTerms, continueToken: continueToken);
    } while (continueToken != null && continueToken != "");

    if (continueToken == "") {
     return searchTerms;
    } else {
      return [];
    }
  }

  Future<String> getPagesLimited(List<String> saveObjectList, {String continueToken = ""}) async {
    try {
      Response response = await get(
          "https://stardewvalleywiki.com/mediawiki/api.php?action=query&format=json&list=allpages&aplimit=500&continue=&apcontinue=$continueToken")
          .timeout(Duration(seconds: 30));
      Map<String, dynamic> parsed = json.decode(response.body);

      if (response.statusCode != 200) {
        return null;
      }

      if (parsed.containsKey('error') || !parsed.containsKey('query')) {
        return null;
      } else {
        parsed['query']["allpages"].forEach((item) {
          print(item);
          saveObjectList.add(item['title']);
        });
        if (!parsed.containsKey('continue')) {
          // we know we are at the last one
          return "";
        } else {
          return parsed['continue']['apcontinue'];
        }
      }

    } catch (e, stackTrace) {
      print("HTTP request timed out");
      print(e);
      print(stackTrace);
    }

    return null;
  }

  Future<void> refreshSuggestions() async {
    var suggestions = await createSearchItems();
    if (suggestions.length != 0) {
      await PersistentStore.instance.updateSearchSuggestions(
          SearchSuggestions(DateTime.now().millisecondsSinceEpoch, suggestions));
    }
  }

  @override
  void initState() {

    searchSuggestionsStream = PersistentStore.instance.searchSuggestionsController.stream;

    searchSuggestionsStream.first.then((event) async {
      int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
//      int maximumCacheStoreTime = Duration.millisecondsPerDay * 1;
      int maximumCacheStoreTime = 0;
      if (event == SearchSuggestions.empty || (currentTimestamp - event.cachedTimestamp) >= maximumCacheStoreTime ) {
        // we dont have a cache, we will attempt to update it
        await refreshSuggestions();
      }
    });

    bookmarksStream = PersistentStore.instance.bookmarksStreamController.stream.map((Map<int, PageBookmark> element) {
      return element.values.toList();
    });

    super.initState();
  }

  String getURLFromPageTitle(String pageTitle) {
    return 'https://stardewvalleywiki.com/$pageTitle';
  }

  String getPageTitleFromURL(String url) {
    return url.split("https://stardewvalleywiki.com/").last;
  }

  Future<String> getCurrentPageTitle() async {
    if (_webViewController != null) {
      return getPageTitleFromURL(await _webViewController.currentUrl());
    }
    return null;
  }

  void _shareCurrentPage() async {
    String shareString = "https//www.stardewvalleywiki.com";
    if (_webViewController != null) {
      shareString = await _webViewController.currentUrl();
    }
    Share.share(shareString);
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
                  onPageStarted: (String url) {
                    print('Page started loading: $url');
                    setState(() {
                      currentUrl = null;
                    });
                  },
                  onPageFinished: (String url) async {
                    bool isBookmarked = await PersistentStore.instance.containsBookmark(PageBookmark(getPageTitleFromURL(url)));
                    setState(() {
                      currentUrl = getPageTitleFromURL(url);
                      currentIsBookmarked = isBookmarked;
                    });
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
                stream: searchSuggestionsStream,
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
                    title: GestureDetector(
                      child: Text("Search Topics..."),
                      onTap: () {
                        showSearch(
                            context: context,
                            delegate: PageSearch(
                                suggestions.suggestions,
                                onSelect: navigateToPage,
                                onRefreshSuggestions: refreshSuggestions,
                            )
                        );
                      }
                    ),
                    actions: <Widget>[
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.search),
                        onPressed: () {
                          showSearch(
                              context: context,
                              delegate: PageSearch(
                                  suggestions.suggestions,
                                  onSelect: navigateToPage,
                                  onRefreshSuggestions: refreshSuggestions,
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
                  stream: bookmarksStream,
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
                                  await PersistentStore.instance.deleteBookmark(
                                      bookmark);
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
        floatingActionButton: StreamBuilder<List<PageBookmark>>(
          stream: bookmarksStream,
          builder: (BuildContext context, AsyncSnapshot<List<PageBookmark>> snapshot) {
            bool currentIsBookmarked = snapshot.hasData && (currentUrl != null) && (snapshot.data.firstWhere((element) => element.pageTitle == currentUrl, orElse: () => null) != null);

            return SpeedDial(
              elevation: 8.0,
              animatedIcon: AnimatedIcons.menu_close,
              animatedIconTheme: IconThemeData(size: 22.0),
              children: <SpeedDialChild>[
                SpeedDialChild(
                  child: currentIsBookmarked ? Icon(Icons.bookmark) : Icon(Icons.bookmark_border),
                  label: currentIsBookmarked ? 'Remove' : 'Bookmark',
                  labelStyle: TextStyle(fontSize: 18.0),
                  onTap: (currentUrl != null) ? () async {
                    String pageTitle = await getCurrentPageTitle();
                    if (currentIsBookmarked) {
                      await PersistentStore.instance.deleteBookmark(PageBookmark(pageTitle));
                      Scaffold.of(context).showSnackBar(SnackBar(
                          content: Text("Removed $pageTitle to bookmarks.")
                      ));
                      setState(() {
                        currentIsBookmarked = false;
                      });
                    } else {
                      setState(() {
                        currentIsBookmarked = true;
                      });
                      await PersistentStore.instance.addBookmark(PageBookmark(pageTitle));
                      Scaffold.of(context).showSnackBar(SnackBar(
                          content: Text("Added $pageTitle to bookmarks.")
                      ));
                    }
                  } : null,
                ),
                SpeedDialChild(
                    child: Icon(Icons.share),
                    label: 'Share',
                    labelStyle: TextStyle(fontSize: 18.0),
                    onTap: _shareCurrentPage
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

class PageSearch extends SearchDelegate<String> {

  final List<String> suggestions;
  final void Function(String selected, String rawQuery) onSelect;
  final void Function() onRefreshSuggestions;
  PageSearch(this.suggestions, {this.onSelect, this.onRefreshSuggestions});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
      IconButton(
        icon: Icon(Icons.refresh),
        onPressed: () {
          if (onRefreshSuggestions != null) {
            onRefreshSuggestions();
          }
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(
          Icons.arrow_back),
          onPressed: () {
            close(context, null);
          },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // just do the same thing
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query == '') {
      // just return empty
      return Center(
        child: Text("Type something to see suggestions."),
      );
    }
    List<String> filteredStrings = ["Search \"$query\" On Wiki"];
    filteredStrings.addAll(suggestions.where((item) {
      return item.toLowerCase().startsWith(query.toLowerCase());
    }));

    return ListView.builder(
        itemCount: filteredStrings.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(filteredStrings[index]),
            onTap: () {
              close(context, null);
              if (onSelect != null) {
                onSelect(filteredStrings[index], query);
              }
            },
          );
        }
    );
  }
}
