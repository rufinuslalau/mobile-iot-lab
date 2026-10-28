import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/temperature_chart.dart';

const String serviceUuid = '12345678-1234-5678-1234-56789abcdef0';
const String ledUuid = '12345678-1234-5678-1234-56789abcdef1';
const String sensorUuid = '12345678-1234-5678-1234-56789abcdef2';

class BlePage extends StatefulWidget {
  const BlePage({super.key});

  @override
  State<BlePage> createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {
  List<ScanResult> _results = [];
  BluetoothDevice? _device;
  BluetoothCharacteristic? _ledChar;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  bool _scanning = false;
  bool _ledOn = false;
  bool _measuring = false;
  String _temperature = '-';
  String _humidity = '-';
  String _status = 'Belum terhubung';
  String _latBle = '-';
  final List<double> _history = [];

  void _saveTemperature(double value) {
    if (!value.isFinite) return;
    _history.add(value);
    if (_history.length > 30) _history.removeAt(0);
  }

  Future<void> _scan() async {
    if (_scanning) return;
    try {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        if (mounted) setState(() => _status = 'Aktifkan Bluetooth dan Lokasi pada HP');
        return;
      }

      await _scanSub?.cancel();
      if (!mounted) return;
      setState(() {
        _results = [];
        _scanning = true;
        _status = 'Memindai ESP32...';
      });

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) setState(() => _results = results);
      });
      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        timeout: const Duration(seconds: 6),
      );
      if (mounted) setState(() => _status = 'Pemindaian selesai');
    } catch (e) {
      if (mounted) setState(() => _status = 'Gagal scan: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
      await device.connect(timeout: const Duration(seconds: 12));
      await _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            _device = null;
            _ledChar = null;
            _status = 'BLE terputus';
          });
        }
      });

      BluetoothCharacteristic? foundLed;
      BluetoothCharacteristic? foundSensor;
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid != Guid(serviceUuid)) continue;
        for (final charac in service.characteristics) {
          if (charac.uuid == Guid(ledUuid)) foundLed = charac;
          if (charac.uuid == Guid(sensorUuid)) foundSensor = charac;
        }
      }
      if (foundLed == null || foundSensor == null) {
        throw Exception('Service/characteristic ESP32 tidak ditemukan');
      }

      await _notifySub?.cancel();
      _notifySub = foundSensor.onValueReceived.listen((bytes) {
        final parts = utf8.decode(bytes, allowMalformed: true).split(';');
        if (parts.length != 2 || !mounted) return;
        final parsed = double.tryParse(parts[0]);
        setState(() {
          _temperature = parts[0];
          _humidity = parts[1];
          if (parsed != null) _saveTemperature(parsed);
        });
      });
      await foundSensor.setNotifyValue(true);

      final ledValue = await foundLed.read();
      if (!mounted) return;
      setState(() {
        _device = device;
        _ledChar = foundLed;
        _ledOn = ledValue.isNotEmpty && ledValue.first != 0;
        _status = 'Terhubung ke ${device.platformName.isEmpty ? "ESP32" : device.platformName}';
      });
    } catch (e) {
      await device.disconnect();
      if (mounted) setState(() => _status = 'Gagal connect: $e');
    }
  }

  Future<void> _setLed(bool on) async {
    try {
      await _ledChar?.write([on ? 1 : 0]);
      if (mounted) setState(() => _ledOn = on);
    } catch (e) {
      if (mounted) setState(() => _status = 'Gagal mengirim perintah: $e');
    }
  }

  Future<void> _measureLatency() async {
    if (_ledChar == null || _measuring) return;
    setState(() => _measuring = true);
    final samples = <int>[];
    try {
      for (var i = 0; i < 10; i++) {
        final stopwatch = Stopwatch()..start();
        await _ledChar!.write([i.isEven ? 1 : 0]);
        stopwatch.stop();
        samples.add(stopwatch.elapsedMilliseconds);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final avg = samples.reduce((a, b) => a + b) / samples.length;
      if (mounted) {
        setState(() {
          _ledOn = false;
          _latBle = '${avg.toStringAsFixed(1)} ms '
              '(min ${samples.reduce(math.min)}, maks ${samples.reduce(math.max)})';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _latBle = 'Gagal mengukur: $e');
    } finally {
      if (mounted) setState(() => _measuring = false);
    }
  }

  Future<void> _disconnect() async {
    await _device?.disconnect();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _notifySub?.cancel();
    _connSub?.cancel();
    _device?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _device != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('BLE Controller', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(_status),
        const SizedBox(height: 14),
        if (!connected) ...[
          FilledButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(_scanning ? 'Memindai...' : 'Scan perangkat'),
          ),
          ..._results.map((result) {
            final name = result.device.platformName.isEmpty
                ? result.device.remoteId.str
                : result.device.platformName;
            return Card(
              child: ListTile(
                title: Text(name),
                subtitle: Text('RSSI: ${result.rssi} dBm'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _connect(result.device),
              ),
            );
          }),
        ] else ...[
          Card(
            child: SwitchListTile(
              title: const Text('Kontrol LED via BLE'),
              subtitle: const Text('Komunikasi langsung tanpa internet'),
              value: _ledOn,
              onChanged: _measuring ? null : _setLed,
            ),
          ),
          Card(
            child: ListTile(
              title: Text('Suhu: $_temperature °C'),
              subtitle: Text('Kelembapan: $_humidity %'),
              leading: const Icon(Icons.thermostat),
            ),
          ),
          TemperatureChart(temperatures: List<double>.of(_history)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _measuring ? null : _measureLatency,
            child: Text(_measuring ? 'Mengukur 10 kali...' : 'Ukur latensi BLE (10 kali)'),
          ),
          Text('Latensi BLE: $_latBle'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off),
            label: const Text('Putuskan BLE'),
          ),
        ],
      ],
    );
  }
}
