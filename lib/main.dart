import 'dart:async';
import 'dart:convert';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
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

  List<String> favourites = new List<String>();
  bool currentIsFavourite = false; // flag to indicate if the current url is already in the favourites
  bool pageReady = false;

  PageSearch _pageSearch;

  void addFavourite(String item) {
    if (!favourites.contains(item)) {
      setState(() {
        favourites.add(item);
        favourites.sort();
        currentIsFavourite = true;
      });
    }
  }

  void deleteFavourite(String item) {
    if (favourites.contains(item)) {
      setState(() {
        favourites.remove(item);
        currentIsFavourite = false;
      });
    }
  }

  bool containsFavourite(String item) {
    return favourites.contains(item);
  }

  Future<List<String>> createSearchItems() async {
    List<String> searchTerms = new List<String>();
    String continueToken = "";
    while (continueToken != null) {
      continueToken =
          await getPagesLimited(searchTerms, continueToken: continueToken);
    }
    return searchTerms;
  }

  Future<String> getPagesLimited(List<String> saveObjectList,
      {String continueToken = ""}) async {
    Response response = await get(
        "https://stardewvalleywiki.com/mediawiki/api.php?action=query&format=json&list=allpages&aplimit=500&continue=&apcontinue=$continueToken");
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
        return null;
      } else {
        return parsed['continue']['apcontinue'];
      }
    }
  }

  @override
  void initState() {
    createSearchItems().then((suggestionList) {
      suggestionList.forEach((suggestion) {
        _pageSearch.addSuggestion(suggestion);
      });
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

  _MainPageState() {
    _pageSearch = PageSearch(List<String>(), (String selected, String rawQuery) async {
      if (selected.startsWith("Search")) {
        await navigateTo("https://stardewvalleywiki.com/mediawiki/index.php?search=$rawQuery&fulltext=search");
      } else {
        await navigateTo(getURLFromPageTitle(selected));
      }
    });
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
                      pageReady = false;
                    });
                  },
                  onPageFinished: (String url) {
                    setState(() {
                      pageReady = true;
                      currentIsFavourite = containsFavourite(getPageTitleFromURL(url));
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
              child: Builder(
                builder: (BuildContext context) {
                  return AppBar(
                    leading: IconButton(
                      icon: Icon(Icons.bookmark),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                    title: GestureDetector(
                      child: Text("Search Topics..."),
                      onTap: () {
                        showSearch(
                            context: context,
                            delegate: _pageSearch
                        );
                      },
                    ),
                    actions: <Widget>[
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.search),
                        onPressed: () {
                          showSearch(
                              context: context,
                              delegate: _pageSearch
                          );
                        },
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.share),
                        onPressed: _shareCurrentPage,
                      )
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
                  leading: Icon(
                      Icons.favorite,
                      color: Theme.of(context).primaryTextTheme.headline6.color),
                  title: Text(
                      'Favourites',
                      style: Theme.of(context).primaryTextTheme.headline6),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: favourites.length,
                  itemBuilder: (context, index) {
                    String item = favourites[index];
                    return new ListTile(
                      title: Text(item),
                      onTap: () async {
                        Navigator.pop(context);
                        await navigateTo(getURLFromPageTitle(item));
                      },
                      trailing: IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          deleteFavourite(item);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (BuildContext context) {
            return SpeedDial(
              elevation: 8.0,
              animatedIcon: AnimatedIcons.menu_close,
              animatedIconTheme: IconThemeData(size: 22.0),
              children: <SpeedDialChild>[
                SpeedDialChild(
                    child: Icon(Icons.home),
                    label: 'Home',
                    labelStyle: TextStyle(fontSize: 18.0),
                    onTap: () async {
                      await navigateTo(getURLFromPageTitle("Stardew_Valley_Wiki"));
                    }
                ),
                SpeedDialChild(
                  child: currentIsFavourite ? Icon(Icons.favorite) : Icon(Icons.favorite_border),
                  label: currentIsFavourite ? 'Unfavourite' : 'Favourite',
                  labelStyle: TextStyle(fontSize: 18.0),
                  onTap: pageReady ? () async {
                    String pageTitle = await getCurrentPageTitle();
                    if (currentIsFavourite) {
                      deleteFavourite(pageTitle);
                      Scaffold.of(context).showSnackBar(SnackBar(
                          content: Text("Removed $pageTitle to favourites.")
                      ));
                    } else {
                      addFavourite(pageTitle);
                      Scaffold.of(context).showSnackBar(SnackBar(
                        content: Text("Added $pageTitle to favourites.")
                      ));
                    }
                  } : null,
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

  PageSearch(this.suggestions, this.onSelect);

  void addSuggestion(String value) {
    if (!suggestions.contains(value)) {
      suggestions.add(value);
    }
  }

  void removeSuggestion(String value) {
    if (suggestions.contains(value)) {
      suggestions.remove(value);
    }
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      )
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
        child: Text("Type something to see pages."),
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
              onSelect(filteredStrings[index], query);
            },
          );
        }
    );
  }
  
}