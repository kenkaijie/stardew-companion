import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:autocomplete_textfield/autocomplete_textfield.dart';
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
  final GlobalKey autocompleteKey =
      new GlobalKey<AutoCompleteTextFieldState<String>>();
  AutoCompleteTextField<String> _autoCompleteTextField;

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
        _autoCompleteTextField.addSuggestion(suggestion);
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

  _MainPageState() {
    _autoCompleteTextField = new SimpleAutoCompleteTextField(
      decoration: InputDecoration(
        hintText: "Search Topic",
        suffixIcon: new Icon(Icons.search),
      ),
      textSubmitted: (value) {
        print("Submitted $value");
        if (_webViewController != null) {
          setState(() {
            _webViewController.loadUrl(getURLFromPageTitle(value));
          });
        }
      },
      key: autocompleteKey,
      suggestions: new List<String>(),
    );
    currentUrl = getURLFromPageTitle("Stardew_Valley_Wiki");
  }

  void _shareCurrentPage() async {
    String shareString = "https//www.stardewvalleywiki.com";
    if (_webViewController != null) {
      shareString = await _webViewController.currentUrl();
    }
    Share.share(shareString);
  }

  String currentUrl = "";
  bool currentFavourite = false;
  List<String> favourites = new List<String>();

  List<Widget> _buildDrawer(BuildContext context) {
    List<Widget> widgetList = new List<Widget>();
    widgetList.add(new DrawerHeader(
      child: Text("Favourites"),
    ));

    favourites.forEach((element) {
      widgetList.add(
          new ListTile(
              title: Text(element),
              trailing: IconButton(
                onPressed: () {
                  setState(() {
                    favourites.remove(element);
                    currentFavourite = false;
                  });
                },
                icon: Icon(Icons.clear),
              ),
              onTap: () {
                setState(() async {
                  await _webViewController.loadUrl(
                      getURLFromPageTitle(element));
                  Navigator.pop(context);
                });
              }
          )
      );
    });
    return widgetList;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: _autoCompleteTextField,
          actions: <Widget>[
            IconButton(
              icon: new Icon(Icons.share),
              onPressed: _shareCurrentPage,
            )
          ],
          // This drop down menu demonstrates that Flutter widgets can be shown over the web view.
        ),
        body: Builder(builder: (BuildContext context) {
          return WebView(
            initialUrl: currentUrl,
            javascriptMode: JavascriptMode.disabled,
            onWebViewCreated: (WebViewController webViewController) {
              setState(() {
                _webViewController = webViewController;
              });
            },
            navigationDelegate: (NavigationRequest request) {
              if (!request.url.startsWith('https://stardewvalleywiki.com')) {
                print('blocking navigation to $request}');
                return NavigationDecision.prevent;
              }
              print('allowing navigation to $request');
              return NavigationDecision.navigate;
            },
            onPageStarted: (String url) {
              setState(() {
                currentUrl = url;
                currentFavourite = favourites.contains(getPageTitleFromURL(currentUrl));
              });
              print('Page started loading: $url');
            },
            onPageFinished: (String url) {
              print('Page finished loading: $url');
            },
            gestureNavigationEnabled: false,
          );
        }),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: _buildDrawer(context),
          )
        ),
        floatingActionButton: new FloatingActionButton(
          child: currentFavourite ? new Icon(Icons.favorite) : new Icon(Icons.favorite_border),
            onPressed: () async {
              setState(() {
                if (favourites.contains(getPageTitleFromURL(currentUrl))) {
                  favourites.remove(getPageTitleFromURL(currentUrl));
                  currentFavourite = false;
                } else {
                  favourites.add(getPageTitleFromURL(currentUrl));
                  favourites.sort();
                  currentFavourite = true;
                }
              });
        }),
      ),
      onWillPop: () async {
        if (await _webViewController.canGoBack()) {
          await _webViewController.goBack();
          return false;
        } else {
          return true;
        }
      },
    );
  }
}
