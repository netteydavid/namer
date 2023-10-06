import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Every dart app enters through the main method.
void main() {
  runApp(MyApp());
}

//The main app itself. Note that this is a widget.
//Think of the UI/UX as a tree of widgets
//This widget is stateless, meaning it doesn't tend to change dynamically.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  //Creates the UI for the the current widget.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      //Allows ChangeNotifers to be used with the app
      create: (context) {
        var state = MyAppState();
        state.loadFavorites();
        return state;
      },
      child: MaterialApp(
        //Main App UI, themes, title, etc.
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

//Handles the main app's state and sends change notifications
class MyAppState extends ChangeNotifier {
  final key = 'favorites'; //Key for persistent data

  var current = WordPair.random(); //The current word pair to display

  //Creates a new wordpair and sets it as the current wordpair
  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  //List of favorite wordpairs
  var favorites = <WordPair>[];

  //Adds or removes the current wordpair
  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }

    saveFavorites();

    notifyListeners();
  }

  //Saves the current list of favorite wordpairs to disk via a key-value pair
  void saveFavorites() {
    //getInstance is async, so we use a callback so that we don't need to await
    SharedPreferences.getInstance().then((value) {
      var strFavorites =
          favorites.map((e) => "${e.first}_${e.second}").toList();

      if (strFavorites.isEmpty) {
        value.remove(key);
      } else {
        //The saved kvp have only a few primitives available.
        //For a list of objects, the objects must be serialized to string
        value.setStringList(key, strFavorites);
      }
    });
  }

  //Loads the saved list of favorites
  void loadFavorites() {
    SharedPreferences.getInstance().then((value) {
      var strFavorites = value.get(key) as List<Object?>?;

      if (strFavorites != null && strFavorites.isNotEmpty) {
        favorites.clear();
        //Deserialize objects and add to in-memory list of favorites
        for (var pair in strFavorites) {
          var separated = (pair as String).split('_');
          favorites.add(WordPair(separated.first, separated.last));
        }
      }
    });
  }
}

//This widget can change dynamically based on user interaction
//We must therefore create a state for this widget.
class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

//The state of the dynamically changable home page widget
class _MyHomePageState extends State<MyHomePage> {
  //Selected tab's 0-based index
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    //Shows a different widget based on the selected tab
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage(); //Main page, shows current wordpair
        break;
      case 1:
        page = FavoritesPage(); //Lists favorted wordpairs
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                extended: constraints.maxWidth >=
                    600, //Changes look if phone is landscape
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.favorite),
                    label: Text('Favorites'),
                  ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) {
                  //setState sets the state (obviously)
                  //setState must be called if there's going to be a UI change
                  setState(() {
                    selectedIndex = value;
                  });
                },
              ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: page,
              ),
            ),
          ],
        ),
      );
    });
  }
}

//Displays favorited wordpairs
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    //Has the widget watch the nearest ancestor with type MyAppState
    var appState = context.watch<MyAppState>();
    var favorites = appState.favorites;

    //Default content, no favorites yet
    if (favorites.isEmpty) {
      return Center(
        child: Text("No favorites yet"),
      );
    }

    List<Widget> content = [
      Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
            "You have ${favorites.length} favorite${favorites.length == 1 ? '' : 's'}"),
      ),
    ];

    content.addAll(favorites
        .map((e) => ListTile(
              leading: Icon(Icons.favorite),
              title: Text(e.asLowerCase),
              onTap: () {
                Clipboard.setData(ClipboardData(text: e.asLowerCase));
              },
              onLongPress: () {
                showDialog(
                    //Shows a dialog when user tries to delete a word
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                          title: Text('Remove ${e.toLowerCase()}'),
                          content: Text(
                              'Are you sure you want remove ${e.toLowerCase()} from your favorites?'),
                          actions: <Widget>[
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, 'Cancel'),
                                child: const Text('NO')),
                            TextButton(
                                onPressed: () {
                                  appState.current = e;
                                  appState.toggleFavorite();
                                  Navigator.pop(context, 'OK');
                                },
                                child: const Text('YES'))
                          ],
                        ));
              },
            ))
        .toList());

    return ListView(
      children: content,
    );
  }
}

//The main tab page, shows a new wordpair and allows
//for favoriting and going to the next wordpair.
class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(pair: pair),
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: Text('Like'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//A card widget placed in the Generator tab. Displays current wordpair.
class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return GestureDetector(
      child: Card(
        color: theme.colorScheme.primary,
        elevation: 7.0,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            pair.asLowerCase,
            style: style,
            semanticsLabel: "${pair.first} ${pair.second}",
          ),
        ),
      ),
      onTap: () => Clipboard.setData(ClipboardData(text: pair.asLowerCase)),
    );
  }
}
