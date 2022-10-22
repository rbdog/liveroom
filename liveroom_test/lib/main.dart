import 'package:flutter/material.dart';
import 'package:liveroom/liveroom.dart';

void main() {
  // アプリ全体の設定
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    home: const HomePage(),
    theme: ThemeData(
      textTheme: const TextTheme(
        bodyText1: TextStyle(fontSize: 24.0),
        bodyText2: TextStyle(fontSize: 24.0),
        button: TextStyle(fontSize: 24.0),
        subtitle1: TextStyle(fontSize: 24.0),
        subtitle2: TextStyle(fontSize: 24.0),
      ),
    ),
  );
  runApp(app);
}

//
// * ライブルームのインスタンス
//
final liveroom = Liveroom(logger: (log) {
  print(log);
});

/// ホーム画面
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  /// メッセージ画面へ進む
  void pushToMessagePage(BuildContext context) {
    final route = MaterialPageRoute(
      builder: (context) => const MessagePage(),
    );
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final layout = HomePageLayout(
      // ルームを作成をタップ
      onTapCreate: () {
        //
        // * ルームを作成したいとき = create
        //
        liveroom.create(roomId: '0001');
      },
      // ルームに参加をタップ
      onTapJoin: () {
        //
        // * ルームに参加したいとき = join
        //
        liveroom.join(roomId: '0001');
      },
    );

    //
    // * ライブルームView を使ってメッセージを受け取る
    //
    return LiveroomView(
      liveroom: liveroom,
      //
      // * 誰かがルームに参加したとき = onJoin
      //
      onJoin: (seatId) {
        // 自分だったときはメッセージ画面に進む
        if (liveroom.mySeatId == seatId) {
          pushToMessagePage(context);
        }
      },
      child: layout,
    );
  }
}

/// メッセージ画面
class MessagePage extends StatefulWidget {
  const MessagePage({Key? key}) : super(key: key);

  @override
  MessagePageState createState() => MessagePageState();
}

class MessagePageState extends State<MessagePage> {
  final List<String> messages = [];

  // メッセージを表示する
  void printMessage(String message) {
    setState(() {
      messages.add(message);
    });
  }

  // 前の画面に戻る
  void popPage(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final layout = MessagePageLayout(
      messages: messages,

      // ルーム退出をタップ
      onTapExit: (() {
        //
        // * ルームを退出したいとき = exit
        //
        liveroom.exit();

        // 前の画面に戻る
        popPage(context);
      }),
      onTapSend: ((text) {
        liveroom.send(message: text);
      }),
    );

    //
    // * ライブルームView を使ってメッセージを受け取る
    //
    return LiveroomView(
      liveroom: liveroom,
      //
      // * 誰かがルームに参加したとき = onJoin
      //
      onJoin: (seatId) {
        // メッセージを表示する
        printMessage('参加しました');
      },
      //
      // * 誰かがメッセージを送信したとき = onReceive
      //
      onReceive: ((seatId, message) {
        // メッセージを表示する
        printMessage(message);
      }),
      //
      // * 誰かがルームを退出したとき = onExit
      //
      onExit: ((seatId) {
        // メッセージを表示する
        printMessage('退出しました');
      }),
      child: layout,
    );
  }
}

/// ホーム画面のレイアウト
class HomePageLayout extends StatelessWidget {
  const HomePageLayout({
    required this.onTapCreate,
    required this.onTapJoin,
    Key? key,
  }) : super(key: key);

  final void Function() onTapCreate;
  final void Function() onTapJoin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: onTapCreate,
              child: const Text('ルーム\n作成'),
            ),
            ElevatedButton(
              onPressed: onTapJoin,
              child: const Text('ルーム\n参加'),
            ),
          ],
        ),
      ),
    );
  }
}

/// メッセージ画面のレイアウト
class MessagePageLayout extends StatelessWidget {
  const MessagePageLayout({
    required this.messages,
    required this.onTapExit,
    required this.onTapSend,
    Key? key,
  }) : super(key: key);

  final List<String> messages;
  final void Function() onTapExit;
  final void Function(String text) onTapSend;

  Widget itemBuilder(BuildContext context, int index) {
    return Text(messages[index]);
  }

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();
    final topBar = Container(
      width: double.infinity,
      height: 100,
      color: Colors.grey[300],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 50, height: 50),
          ElevatedButton(
            onPressed: onTapExit,
            child: const Text('ルーム退出'),
          ),
        ],
      ),
    );
    final bottomBar = Container(
      width: double.infinity,
      height: 100,
      color: Colors.grey[300],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 300,
            height: 50,
            child: TextField(
              decoration: const InputDecoration(
                fillColor: Colors.white,
                filled: true,
              ),
              controller: textController,
            ),
          ),
          ElevatedButton(
            onPressed: () => onTapSend(textController.text),
            child: const Text('送信'),
          ),
        ],
      ),
    );

    final messageListView = Expanded(
      child: ListView.builder(
        itemBuilder: itemBuilder,
        itemCount: messages.length,
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          topBar,
          messageListView,
          bottomBar,
        ],
      ),
    );
  }
}
