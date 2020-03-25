import 'dart:convert';

import 'package:http/http.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sembast/sembast.dart';
import 'package:stardewcompanion/bloc_base.dart';
import 'package:stardewcompanion/persistent_store_service.dart';

class SearchSuggestions {

  final int cachedTimestampMs;
  final List<String> suggestions;

  Map<String, dynamic> toMap() {
    return {'cachedTimestamp': cachedTimestampMs, 'suggestions': suggestions};
  }

  factory SearchSuggestions.fromMap(Map<String, dynamic> map) {
    return SearchSuggestions(map['cachedTimestamp'], map['suggestions'].toList().cast<String>());
  }

  SearchSuggestions(this.cachedTimestampMs, this.suggestions);

  static final SearchSuggestions empty = SearchSuggestions(0, []);
}

abstract class ISearchSuggestionsService extends BlocBase {
  /// notification stream if search suggestions are updated
  ValueStream<SearchSuggestions> get searchSuggestionsStream;

  /// Causes the Service to refresh the suggestions, if force is set to true, this invalidates any cache, if applicable
  Future<void> refreshSuggestions(bool force);

  /// Direct get of the latest search suggestions
  Future<SearchSuggestions> get searchSuggestions;
}

class SearchSuggestionsService implements ISearchSuggestionsService {

  ValueStream<SearchSuggestions> searchSuggestionsStream;
  BehaviorSubject<SearchSuggestions> _searchSuggestionsSubject;

  final IPersistentStoreService _persistentStore;
  final Duration _cacheStaleTime;
  /// sembast impl
  final StoreRef<int, Map<String, dynamic>> searchTermsStore = intMapStoreFactory.store('searchSuggestions');
  bool _isSearchSuggestionsCached = false;
  SearchSuggestions __searchSuggestionsCache = SearchSuggestions.empty;
  bool _webRetryNeeded = false;

  Future<void> _updateSearchSuggestions(SearchSuggestions suggestions) async {
    __searchSuggestionsCache = suggestions;
    _webRetryNeeded = false;
    _isSearchSuggestionsCached = true;
    _searchSuggestionsSubject.add(suggestions);
  }

  Future<SearchSuggestions> get searchSuggestions async {
    if(!_isSearchSuggestionsCached) {
      // if none of those returned, we are not cached
      final query = Finder(
        // just really need something to get all values
          filter: Filter.notNull('cachedTimestamp'),
          sortOrders: [SortOrder('cachedTimestamp', false)]
      );

      var records = await searchTermsStore.find(await _persistentStore.dbClient, finder: query);

      // if we happen to have more than 1 cache, just delete all except the first
      await Future.forEach(records, (RecordSnapshot<int, Map<String, dynamic>> record) async {
        if (record != records.first) {
          await searchTermsStore.record(record.key).delete(await _persistentStore.dbClient);
        } else {
          __searchSuggestionsCache = SearchSuggestions.fromMap(record.value);
        }
      });
      _isSearchSuggestionsCached = true;
    }

    if(DateTime.now().millisecondsSinceEpoch - __searchSuggestionsCache.cachedTimestampMs >= _cacheStaleTime.inMilliseconds) {
      _webRetryNeeded = true;
    };

    if (_webRetryNeeded) {
      _webRetryNeeded = false;
      _refreshSuggestionsFromWeb().then((suggestions) async {
        await _updateSearchSuggestions(suggestions);
      }, onError: (error) {
        _webRetryNeeded = true;
      });
    }
    return __searchSuggestionsCache;
  }

  SearchSuggestionsService(this._persistentStore, this._cacheStaleTime) {
    _searchSuggestionsSubject = new BehaviorSubject.seeded(SearchSuggestions.empty);
    searchSuggestionsStream = _searchSuggestionsSubject.stream;
    _searchSuggestionsSubject.onListen = () async {
      _updateSearchSuggestions(await searchSuggestions);
    };
  }

  void dispose() {
    _searchSuggestionsSubject.close();
  }

  Future<void> refreshSuggestions(bool force) async {
    if (force) _webRetryNeeded = true;
    if (_webRetryNeeded) {
      /// for a retry we force the reading
      await searchSuggestions;
    }
  }

  Future<SearchSuggestions> _refreshSuggestionsFromWeb() async {
    var suggestions = await _createSearchItems();
    return new SearchSuggestions(DateTime.now().millisecondsSinceEpoch, suggestions);
  }

  Future<List<String>> _createSearchItems() async {
    List<String> searchTerms = new List<String>();
    String continueToken = "";
    do {
      continueToken = await _getPagesLimited(searchTerms, continueToken: continueToken);
    } while (continueToken != null && continueToken != "");

    if (continueToken == "") {
      return searchTerms;
    } else {
      return [];
    }
  }

  Future<String> _getPagesLimited(List<String> saveObjectList, {String continueToken = ""}) async {
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

}