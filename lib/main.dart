import 'dart:io';

import 'package:clipboard_watcher/clipboard_watcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await hotKeyManager.unregisterAll();
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(240, 360),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.hide();
    await trayManager.setIcon(
      Platform.isWindows ? 'images/tray_icon.ico' : 'images/tray_icon.png',
    );
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: '显示',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit_app',
          label: '退出',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);

    await _initHotKey();
  });

  runApp(const App());
}

Future<void> _initHotKey() async {
  final hotKey = HotKey(
    key: PhysicalKeyboardKey.semicolon,
    modifiers: [HotKeyModifier.control],
    scope: HotKeyScope.system,
  );
  await hotKeyManager.register(
    hotKey,
    keyDownHandler: (hotKey) async {
      final mousePosition = await screenRetriever.getCursorScreenPoint();
      await windowManager.setPosition(mousePosition);
      await windowManager.show();
    },
  );

  final hotKey1 = HotKey(
    key: PhysicalKeyboardKey.escape,
    scope: HotKeyScope.inapp,
  );
  await hotKeyManager.register(
    hotKey1,
    keyDownHandler: (hotKey) async {
      await windowManager.hide();
    },
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with ClipboardListener, WindowListener, TrayListener {
  final records = <String>[];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    clipboardWatcher.addListener(this);
    clipboardWatcher.start();
    _initInAppHotKey();
  }

  @override
  void dispose() {
    clipboardWatcher.removeListener(this);
    clipboardWatcher.stop();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initInAppHotKey() async {
    final numbers = [
      PhysicalKeyboardKey.digit1,
      PhysicalKeyboardKey.digit2,
      PhysicalKeyboardKey.digit3,
      PhysicalKeyboardKey.digit4,
      PhysicalKeyboardKey.digit5,
      PhysicalKeyboardKey.digit6,
      PhysicalKeyboardKey.digit7,
      PhysicalKeyboardKey.digit8,
      PhysicalKeyboardKey.digit9,
      PhysicalKeyboardKey.digit0,
    ];
    for (var i = 0; i < numbers.length; i++) {
      final hotKey = HotKey(
        key: numbers[i],
        scope: HotKeyScope.inapp,
      );
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) async {
          await onSelect(i);
        },
      );
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
    } else if (menuItem.key == 'exit_app') {
      windowManager.close();
    }
  }

  @override
  void onWindowBlur() {
    super.onWindowBlur();
    windowManager.hide();
  }

  @override
  void onClipboardChanged() async {
    final newClipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = newClipboardData?.text;
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        records.remove(text);
        records.insert(0, text);
        if (records.length > 100) {
          records.removeRange(100, records.length);
        }
      });
    }
  }

  Future<void> onSelect(int index) async {
    await Clipboard.setData(ClipboardData(text: records[index]));
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: records.isEmpty
          ? Center(
              child: Text('剪切板记录为空'),
            )
          : ListView.separated(
              itemCount: records.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => onSelect(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        Text('${index + 1}'),
                        Expanded(
                          child: Text(
                            records[index].trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) {
                return const Divider(
                  height: 0,
                  thickness: 0,
                );
              },
            ),
    );
  }
}
