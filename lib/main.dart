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

  List<String> favourites = new List<String>();
  bool currentIsFavourite = false; // flag to indicate if the current url is already in the favourites
  bool pageReady = false;

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

  Future<String> getCurrentPageTitle() async {
    if (_webViewController != null) {
      return getPageTitleFromURL(await _webViewController.currentUrl());
    }
    return null;
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
            initialUrl: getURLFromPageTitle("Stardew_Valley_Wiki"),
            javascriptMode: JavascriptMode.disabled,
            onWebViewCreated: (WebViewController webViewController) {
              setState(() {
                _webViewController = webViewController;
              });
            },
            navigationDelegate: (NavigationRequest request) {
              if (!request.url.startsWith('https://stardewvalleywiki.com')) {
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
        drawer: Drawer(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DrawerHeader(
                padding: EdgeInsets.zero,
                child: Text("Favourites"),
              ),
              Expanded(
                child: ListView.builder(
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
        floatingActionButton: FloatingActionButton(

          child: currentIsFavourite ? Icon(Icons.favorite) : Icon(Icons.favorite_border),
          onPressed: pageReady ? () async {
            String pageTitle = await getCurrentPageTitle();
            if (currentIsFavourite) {
              deleteFavourite(pageTitle);
            } else {
              addFavourite(pageTitle);
            }
          } : null,
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