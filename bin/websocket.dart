// bin/server.dart
import 'package:args/args.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:collection';

class WebSocketsClient {
  String name;
  WebSocket ws;

  WebSocketsClient(this.ws);
  Future close() => ws.close();
}

// Single item in the chat history
class ChatMessage {
  String name;
  String text;

  ChatMessage(this.name, this.text);
  String get json => JSON.encode({
    'name': name,
    'text': text
  });
}


class ChatWebSocketsServer {
  // hold all connected clients in this list
  List<WebSocketsClient> _clients = [];

  // chat history
  ListQueue<ChatMessage> _chat;
  static const int MAX_HISTORY = 100;

  ChatWebSocketsServer() {
    _chat = new ListQueue<ChatMessage>();
  }


  // add a new client based on his WebSocket connection
  void handleWebSocket(WebSocket ws) {
    WebSocketsClient client = new WebSocketsClient(ws);
    _clients.add(client);
    print('Client connected');

    // In a real application we would probably wrap JSON.decode() with
    // try & catch to filter out malformed inputs.
    // Stream.map() returns a new Stream and processes each item
    // with callback function. In our case it decodes all JSONs.
    // onDone is called when the connection is closed by the client.
    ws.map((string) => JSON.decode(string)).listen((Map json) {
      handleMessage(client, json);
    }, onDone: () => close(client));
  }

  // handle incoming messages
  void handleMessage(WebSocketsClient client, Map json) {
    if (json['type'] == 'change_name') {
      client.name = json['name'];

    } else if (json['type'] == 'post' && client.name.isNotEmpty) {
      ChatMessage record = new ChatMessage(client.name, json['text']);
      // keep only last MAX_HISTORY messages
      _chat.addLast(record);
      if (_chat.length > MAX_HISTORY) {
        _chat.removeFirst();
      }
      _broadcast(record);

    } else if (json['type'] == 'init') {
      // let's not bother with performance now for simplicity reasons
      _chat.forEach((ChatMessage record) {
        client.ws.add(record.json);
      });
    }
  }
  // client closed their connection
  void close(WebSocketsClient client) {
    print('Client disconnected');
    // remove the reference from the list of clients
    client.close().then((_) {
      _clients.removeAt(_indexByWebSocket(client.ws));
    });
  }
  
  // close connection to all clients
  // this is used only on server shutdown
  Future closeAll() {
    Completer completer = new Completer();
    // make a list of all Future objects returned by close() methods ..
    List<Future> futures = [];
    _clients.forEach((WebSocketsClient client) =>
      futures.add(client.ws.close()));
    // ... and wait until all of them complete
    Future.wait(futures).then((_) => completer.complete());
    return completer.future;
  }


  // send a message to all connected clients
  void _broadcast(ChatMessage message) {
    _clients.forEach((WebSocketsClient client) {
      // method add() send a string to the client
      client.ws.add(message.json);
    });
  }

  // get index for this WebSocket connection in the list of all clients
  int _indexByWebSocket(WebSocket ws) {
    for (int i = 0; i < _clients.length; i++) {
      if (_clients[i].ws == ws) {
        return i;
      }
    }
    return null;
  }
}


main(List<String> args) {
  ArgParser parser = new ArgParser();

  // this is probably self-explanatory
  parser
      ..addOption('port', abbr: 'p', defaultsTo: '8888')
      ..addOption(
          'pid-file',
          defaultsTo: 'var/websockets.pid',
          help: 'Path for a file with process ID')
      ..addOption(
          'cmd',
          abbr: 'c',
          allowed: ['start', 'stop', 'stats'],
          defaultsTo: 'start')
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  ArgResults argResults = parser.parse(args);

  /* args parser as above */
  HttpServer httpServer;
  ChatWebSocketsServer wsServer;

  if (argResults['help']) {
    print(parser.usage);
  } else if (argResults['cmd'] == 'stop') {
    // stop server by sending a SIGTERM signal
  } else if (argResults['cmd'] == 'start') {
    wsServer = new ChatWebSocketsServer();

    print('My PID: $pid');
    int port = int.parse(argResults['port']);
    print('Starting WebSocket server');
    
    HttpServer.bind(
        InternetAddress.LOOPBACK_IP_V4,
        port).then((HttpServer server) {
      httpServer = server;

      // handle upgrade requests
      StreamController sc = new StreamController();
      sc.stream.transform(new WebSocketTransformer()).listen((WebSocket ws) {
        wsServer.handleWebSocket(ws);
      });

      // listen to HTTP requests
      server.listen((HttpRequest request) {
        // you can manually handle different URLs with request.uri
        // and listen to WebSockets connection only on a specific URL
        // eg. if (request.uri == '/ws') { }
        sc.add(request);
      });
    });
  }
}
