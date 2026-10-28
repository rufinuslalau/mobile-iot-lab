import 'package:flutter/material.dart';
import 'ble_page.dart';
import 'mqtt_page.dart';

void main() => runApp(const MobileIoTApp());

class MobileIoTApp extends StatelessWidget {
  const MobileIoTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile IoT Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const MobileIoTHome(),
    );
  }
}

class MobileIoTHome extends StatefulWidget {
  const MobileIoTHome({super.key});

  @override
  State<MobileIoTHome> createState() => _MobileIoTHomeState();
}

class _MobileIoTHomeState extends State<MobileIoTHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile IoT Lab')),
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: const [BlePage(), MqttPage()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bluetooth), label: 'BLE'),
          NavigationDestination(icon: Icon(Icons.cloud_outlined), label: 'MQTT'),
        ],
      ),
    );
  }
}
