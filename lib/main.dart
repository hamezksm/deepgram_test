import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:convert';
import 'package:sound_stream/sound_stream.dart';
import 'package:web_socket_channel/io.dart';
import 'package:permission_handler/permission_handler.dart';

Future main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deepgram Live Transcription',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Deepgram Live Transcription'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final serverUrl =
      'wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=16000&language=en-GB';
  final apiKey = dotenv.env['DEEPGRAM_API_KEY'];

  String myText = "To start transcribing your voice, press start.";

  final RecorderStream _recorder = RecorderStream();

  StreamSubscription<dynamic>? _recorderStatus;
  StreamSubscription<Uint8List>? _audioStream;

  late IOWebSocketChannel channel;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(onLayoutDone);
  }

  @override
  void dispose() {
    _recorderStatus!.cancel();
    _audioStream!.cancel();
    channel.sink.close();

    super.dispose();
  }

  Future<void> _initStream() async {
    if (_recorderStatus != null) {
      _recorderStatus!.cancel();
    }
    if (_audioStream != null) {
      _audioStream!.cancel();
    }
    channel = IOWebSocketChannel.connect(Uri.parse(serverUrl),
        headers: {'Authorization': 'Token $apiKey'});

    channel.stream.listen((event) async {
      final parsedJson = jsonDecode(event);
      print(parsedJson['channel']);
      print(parsedJson['channel']['alternatives']);
      print(parsedJson['channel']['alternatives'][0]);
      print(parsedJson['channel']['alternatives'][0]['transcript']);

      updateText(parsedJson['channel']['alternatives'][0]['transcript']);
    });

    _audioStream = _recorder.audioStream.listen((data) {
      channel.sink.add(data);
    });

    _recorderStatus = _recorder.status.listen((status) {
      if (mounted) {
        setState(() {});
      }
    });

    await Future.wait([
      _recorder.initialize(),
    ]);
  }

  void _startRecord() async {
    resetText();
    _initStream();
    await _recorder.start();
    setState(() {});
  }

  void _stopRecord() async {
    await _recorder.stop();
    _recorderStatus!.cancel();
    _audioStream!.cancel();
    channel.sink.close();
    setState(() {});
  }

  void onLayoutDone(Duration timeStamp) async {
    await Permission.microphone.request();
    setState(() {});
  }

  void updateText(newText) {
    setState(() {
      myText = '$myText $newText';
    });
  }

  void resetText() {
    setState(() {
      myText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Live Transcription with Deepgram'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    width: 150,
                    child: Text(
                      myText,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 50,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  OutlinedButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all<Color>(Colors.blue),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                    ),
                    onPressed: () {
                      updateText('');

                      _startRecord();
                    },
                    child: const Text('Start', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 5),
                  OutlinedButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all<Color>(Colors.red),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                    ),
                    onPressed: () {
                      _stopRecord();
                    },
                    child: const Text('Stop', style: TextStyle(fontSize: 30)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
