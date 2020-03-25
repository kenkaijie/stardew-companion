
import 'package:flutter/material.dart';

class PageSearch extends SearchDelegate<String> {

  final List<String> suggestions;
  final void Function(String selected, String rawQuery) onSelect;
  final void Function() onRefreshSuggestions;
  PageSearch({@required this.suggestions,@required this.onSelect, @required this.onRefreshSuggestions});

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
