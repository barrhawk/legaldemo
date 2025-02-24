import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState()..loadHistory(),
      child: const MyApp(),
    ),
  );
}

// Configurable API endpoint.
const String API_ENDPOINT_BASE = 'http://0.0.0.0:8000'; // CHANGE THIS

final ThemeData lunarTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: Colors.black,
  ),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: Colors.grey,
    brightness: Brightness.dark,
  ).copyWith(secondary: Colors.white, background: Colors.black),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white),
    displayLarge: TextStyle(color: Colors.white),
    displayMedium: TextStyle(color: Colors.white),
    displaySmall: TextStyle(color: Colors.white),
    headlineMedium: TextStyle(color: Colors.white),
    headlineSmall: TextStyle(color: Colors.white),
    titleLarge: TextStyle(color: Colors.white),
    titleMedium: TextStyle(color: Colors.white),
    titleSmall: TextStyle(color: Colors.white),
    labelLarge: TextStyle(color: Colors.white),
    labelSmall: TextStyle(color: Colors.white),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    hintStyle: TextStyle(color: Colors.white70),
    labelStyle: TextStyle(color: Colors.white),
    // White borders.
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white),
    ),
  ),
  iconTheme: const IconThemeData(
    color: Colors.white,
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
          ],
          title: 'silverdemo',
          theme: appState.isLunarTheme ? lunarTheme : ThemeData.light(),
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MainScreenState();
  }
}

class _MainScreenState extends State<MainScreen> {
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Highly Classified Settings '),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('temperature: 0.5 (Control Novelity in replies)'),
                Text('top_p: 0.95 (Precision targeting of top probabilities)'),
                Text('top_k: 40 (Elite selection of top choices)'),
                Text('max_output_tokens: 4096 (Keep things concise)'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('EDIT SETTINGS'),
              onPressed: () {
                // TODO: Settings editor.
              },
            ),
            TextButton(
              child: const Text('DISMISS (Acknowledged)'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // About section. Unchanged.
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About - silverdemo'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'This is the test AI demo for Silverman. It\'s raw, it\'s unfiltered, and it\'s here to kick ass and take names. We\'re not here to play nice; we\'re here to dominate.'),
                  SizedBox(height: 10),
                  Text(
                    'Powered by cutting-edge language models, this demo is as tough as they come. It\'s designed to push the limits of what\'s possible, leaving the competition in the dust.'),
                    SizedBox(height: 10),
                    Text('So buckle up. You\'re in for a wild ride.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('LET\'S DO THIS!'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.lightBlue,
              ),
              child: Text(
                'silverdemo Mission Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.question_answer),
              title: const Text('About'),
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                _showSettingsDialog(context);
              },
            ),
            // System Instructions Switch. Removed, not needed for this task.
            ListTile(
              leading: const Icon(Icons.share_sharp),
              title: const Text("Share this Conversation"),
              onTap: () {
                final appState = Provider.of<AppState>(context, listen: false);
                String conversation =
                "I had this conversation with silverdemo!\n\n";
              for (var item in appState.history) {
                conversation +=
                "QUESTION: ${item['query']}\nREPLY: ${item['response']}\n\n";
              }
              Clipboard.setData(ClipboardData(text: conversation));
              Navigator.pop(context); // Close the drawer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation copied to clipboard!')),
              );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Session History'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SessionHistoryScreen()),
                );
              },
            ),
            // History-clearing button.
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Clear this Conversation'),
              onTap: () {
                Provider.of<AppState>(context, listen: false).clearHistory();
                Navigator.pop(context); // Close the drawer
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History ERASED.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_2),
              title: const Text('Lunar Theme'),
              trailing: Consumer<AppState>(
                builder: (context, appState, child) {
                  return Switch(
                    value: appState.isLunarTheme,
                    onChanged: (value) {
                      appState.toggleTheme();
                    },
                    activeColor: Colors.white,
                    activeTrackColor: Colors.grey,
                    inactiveThumbColor: Colors.blue,
                    inactiveTrackColor: Colors.lightBlue,
                  );
                },
              ),
              onTap: () {
                // Switch handles it.
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('silverdemo'),
        backgroundColor: Colors.deepOrange,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog(context);
            },
          ),
        ],
      ),
      body: MyHomePage(),
    );
  }
}

class AppState with ChangeNotifier {
  String _response = '';
  bool _isLoading = false;
  String _selectedEndpoint = '/analysis'; // Default endpoint
  String? _selectedCharacter; // Nullable, for redaction character
  String _selectedFile = 'a'; // Default file
  static const int maxHistoryLength = 10;
  List<Map<String, String>> _history = [];
  bool _isLunarTheme = false;
  Stopwatch? _stopwatch;
  double _averageResponseTime = 0.0;
  int _responseCount = 0;

  String get response => _response;
  bool get isLoading => _isLoading;
  String get selectedEndpoint => _selectedEndpoint;
  String? get selectedCharacter => _selectedCharacter; // Getter
  String get selectedFile => _selectedFile;
  List<Map<String, String>> get history => _history;
  bool get isLunarTheme => _isLunarTheme;
  double get averageResponseTime => _averageResponseTime;

  void updateResponse(String newResponse) {
    _response = newResponse;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setEndpoint(String endpoint) {
    _selectedEndpoint = endpoint;
    _selectedCharacter = null; // Reset character when changing endpoints
    print('Endpoint updated to: $endpoint');
    notifyListeners();
  }

  void setCharacter(String? character) {
    _selectedCharacter = character;
    print('Character updated to: $character');
    notifyListeners();
  }

  void setFile(String file) {
    _selectedFile = file;
    print('File updated to: $file');
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _history = _history.isNotEmpty ? _history : [];
    print('History loaded (in-memory).');
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    print('History saved (in-memory).');
  }

  // Build the URL.
  Uri _buildUrl(String endpoint) {
    final String urlString = '$API_ENDPOINT_BASE$endpoint';
    return Uri.parse(urlString);
  }

  Future<void> submitQuery(String query) async {
    setLoading(true);

    _stopwatch = Stopwatch()..start();

    _history.add({'query': query, 'response': '', 'time': ''});
    if (_history.length > maxHistoryLength) {
      _history.removeAt(0);
    }
    notifyListeners();

    final url = _buildUrl(_selectedEndpoint);
    print('Submitting query to: $url');
    final headers = {'Content-Type': 'application/json'};
    // Include character and file in body
    final Map<String, dynamic> requestBody = {'query': query, 'file': _selectedFile};
    if (_selectedEndpoint == '/redact' && _selectedCharacter != null) {
      requestBody['character'] = _selectedCharacter;
    }
    final body = jsonEncode(requestBody);


    try {
      final response = await http.post(url, headers: headers, body: body);
      String newResponse;
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        newResponse = jsonResponse['response'] is String
        ? jsonResponse['response']
        : 'Error: Invalid response format from server.';
      } else {
        newResponse = 'API Error: ${response.statusCode}.';
      }

      _history.last['response'] = newResponse;
      updateResponse(newResponse);
    } catch (e) {
      String newResponse = 'Catastrophic Error: $e';
      _history.last['response'] = newResponse;
      updateResponse(newResponse);
    } finally {
      setLoading(false);
      _stopwatch!.stop();
      final responseTime = _stopwatch!.elapsedMilliseconds / 1000.0;
      _history.last['time'] = responseTime.toStringAsFixed(2);

      _responseCount++;
      _averageResponseTime =
      ((_averageResponseTime * (_responseCount - 1)) + responseTime) /
      _responseCount;

      notifyListeners();
    }
  }

  void toggleTheme() {
    _isLunarTheme = !_isLunarTheme;
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  final _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String formatForSocialMedia(String query, String response) {
    return "I asked silverdemo - \"$query\" and it replied \"$response\"";
  }

  void _handleSubmit(AppState appState) {
    if (_formKey.currentState!.validate()) {
      appState.submitQuery(_queryController.text);
      _queryController.clear();
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: RawKeyboardListener(
            focusNode: _focusNode,
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.enter &&
                  event.isControlPressed) {
                  _handleSubmit(appState);
                  }
              }
            },
            child: Column(
              children: <Widget>[
                // File Selection Buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      ElevatedButton(
                        onPressed: () => appState.setFile('a'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appState.selectedFile == 'a'
                        ? Colors.amber
                        : Colors.grey,
                        ),
                        child: const Text('File A'),
                      ),
                      ElevatedButton(
                        onPressed: () => appState.setFile('b'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appState.selectedFile == 'b'
                        ? Colors.amber
                        : Colors.grey,
                        ),
                        child: const Text('File B'),
                      ),
                      ElevatedButton(
                        onPressed: () => appState.setFile('c'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appState.selectedFile == 'c'
                        ? Colors.amber
                        : Colors.grey,
                        ),
                        child: const Text('File C'),
                      ),
                    ],
                  ),
                ),
                // Main Action Buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      ElevatedButton(
                        onPressed: () => appState.setEndpoint('/analysis'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          appState.selectedEndpoint == '/analysis'
                        ? Colors.blue
                        : Colors.grey,
                        ),
                        child: const Text('Analysis'),
                      ),
                      ElevatedButton(
                        onPressed: () => appState.setEndpoint('/extract'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          appState.selectedEndpoint == '/extract'
                        ? Colors.green
                        : Colors.grey,
                        ),
                        child: const Text('Extract'),
                      ),
                      ElevatedButton(
                        onPressed: () => appState.setEndpoint('/redact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          appState.selectedEndpoint == '/redact'
                        ? Colors.red
                        : Colors.grey,
                        ),
                        child: const Text('Redact'),
                      ),
                    ],
                  ),
                ),

                // Character Selection Buttons (Conditional)
                if (appState.selectedEndpoint == '/redact')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        ElevatedButton(
                          onPressed: () => appState.setCharacter('Harry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            appState.selectedCharacter == 'Harry'
                          ? Colors.red[700]
                          : Colors.red,
                          ),
                          child: const Text('Harry'),
                        ),
                        ElevatedButton(
                          onPressed: () => appState.setCharacter('Ron'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appState.selectedCharacter == 'Ron'
                          ? Colors.red[700]
                          : Colors.red,
                          ),
                          child: const Text('Ron'),
                        ),
                        ElevatedButton(
                          onPressed: () => appState.setCharacter('Hermione'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            appState.selectedCharacter == 'Hermione'
                          ? Colors.red[700]
                          : Colors.red,
                          ),
                          child: const Text('Hermione'),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: appState.history.length,
                      itemBuilder: (context, index) {
                        final item = appState.history[index];
                        final responseTime = item['time'] ?? '';
                    return GestureDetector(
                      onTap: () {
                        if (item['response']!.isNotEmpty) {
                          final formattedMessage = formatForSocialMedia(
                            item['query']!, item['response']!);
                          Clipboard.setData(
                            ClipboardData(text: formattedMessage));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Formatted response copied to clipboard!')),
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Query.
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            margin: const EdgeInsets.only(bottom: 4.0),
                            decoration: BoxDecoration(
                              color: appState.isLunarTheme
                              ? Colors.white10
                              : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              "Query: ${item['query']!}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Response.
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            margin: const EdgeInsets.only(bottom: 8.0),
                            decoration: BoxDecoration(
                              color: appState.isLunarTheme
                              ? Colors.white12
                              : Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "A: ${item['response']!.isEmpty ? 'Waiting...' : item['response']!}",
                                ),
                                if (responseTime.isNotEmpty)
                                  Text(
                                    "Time: $responseTime seconds",
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Average response time: ${appState.averageResponseTime.toStringAsFixed(2)} seconds',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  // Query Input Area.
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Form(
                      key: _formKey,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _queryController,
                              decoration: const InputDecoration(
                                hintText: 'Ask Anything!',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Try writing that again';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          ElevatedButton(
                            onPressed: appState.isLoading
                            ? null
                            : () => _handleSubmit(appState),
                            child: appState.isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Submit!'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});

  String formatForSocialMedia(String query, String response) {
    return "I asked silverdemo - \"$query\" and it replied \"$response\"";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return ListView.builder(
            itemCount: appState.history.length,
            itemBuilder: (context, index) {
              final item = appState.history[index];
              return ListTile(
                title: Text(item['query']!,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: item['response']!.isEmpty
                            ? const Text('Waiting...',
                                         style: TextStyle(fontStyle: FontStyle.italic))
                            : Text(item['response']!),
                            onTap: () {
                              if (item['response']!.isNotEmpty) {
                                final formattedMessage = formatForSocialMedia(
                                  item['query']!, item['response']!);
                                Clipboard.setData(ClipboardData(text: formattedMessage));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                    Text('Formatted response copied to clipboard!')),
                                );
                              }
                            },
              );
            },
          );
        },
      ),
    );
  }
}
// End of file.
