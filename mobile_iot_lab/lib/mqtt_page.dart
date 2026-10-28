import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'widgets/temperature_chart.dart';

// Ganti "kelompok_x" ke nama unik yang SAMA dengan KELOMPOK di firmware ESP32.
const String kelompok = 'kel2';
const String host = 'broker.emqx.io';
const String tSensor = 'polnes/oit/$kelompok/sensor';
const String tLed = 'polnes/oit/$kelompok/led';
const String tLedState = 'polnes/oit/$kelompok/led/state';
const String tStatus = 'polnes/oit/$kelompok/status';

class MqttPage extends StatefulWidget {
  const MqttPage({super.key});

  @override
  State<MqttPage> createState() => _MqttPageState();
}

class _MqttPageState extends State<MqttPage> {
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;
  bool _connected = false;
  bool _measuring = false;
  bool _ledOn = false;
  String _suhu = '-';
  String _hum = '-';
  String _device = 'tidak diketahui';
  String _status = 'Belum terhubung';
  String _latMqtt = '-';
  final List<double> _history = [];
  Completer<void>? _waiting;
  String _expected = '';

  void _saveTemperature(double value) {
    if (!value.isFinite) return;
    _history.add(value);
    if (_history.length > 30) _history.removeAt(0);
  }

  Future<void> _connect() async {
    if (_connected) return;
    final id = 'flutter-$kelompok-${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient(host, id);
    client.port = 1883;
    client.keepAlivePeriod = 30;
    client.logging(on: false);
    client.onDisconnected = _onDisconnected;
    client.connectionMessage =
        MqttConnectMessage().withClientIdentifier(id).startClean();
    setState(() => _status = 'Menghubungkan ke broker...');

    try {
      await client.connect();
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        throw Exception('Broker menolak koneksi: ${client.connectionStatus}');
      }
      _updatesSub = client.updates!.listen(_onMessage);
      client.subscribe(tSensor, MqttQos.atMostOnce);
      client.subscribe(tLedState, MqttQos.atLeastOnce);
      client.subscribe(tStatus, MqttQos.atLeastOnce);
      if (!mounted) {
        client.disconnect();
        return;
      }
      setState(() {
        _client = client;
        _connected = true;
        _status = 'Terhubung ke $host:1883';
      });
    } catch (e) {
      client.disconnect();
      if (mounted) setState(() => _status = 'Gagal terhubung: $e');
    }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    if (events.isEmpty || !mounted) return;
    for (final event in events) {
      if (event.payload is! MqttPublishMessage) continue;
      final message = event.payload as MqttPublishMessage;
      final text = MqttPublishPayload.bytesToStringAsString(message.payload.message);
      final topic = event.topic;
      if (!mounted) return;

      if (topic == tSensor) {
        try {
          final decoded = jsonDecode(text) as Map<String, dynamic>;
          final temperature = (decoded['suhu'] as num).toDouble();
          final humidity = (decoded['hum'] as num).toDouble();
          setState(() {
            _suhu = temperature.toStringAsFixed(1);
            _hum = humidity.toStringAsFixed(1);
            _saveTemperature(temperature);
          });
        } catch (_) {
          // Abaikan pesan sensor dari publisher dengan format yang tidak cocok.
        }
      } else if (topic == tLedState) {
        setState(() => _ledOn = text == 'ON');
        if (_waiting != null && !_waiting!.isCompleted && text == _expected) {
          _waiting!.complete();
        }
      } else if (topic == tStatus) {
        setState(() => _device = text);
      }
    }
  }

  void _onDisconnected() {
    _waiting?.completeIfPending();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _status = 'Terputus dari broker';
    });
  }

  void _publish(String topic, String value) {
    if (!_connected || _client == null) return;
    final builder = MqttClientPayloadBuilder()..addString(value);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> _measureLatency() async {
    if (!_connected || _measuring) return;
    setState(() => _measuring = true);
    final samples = <int>[];
    try {
      for (var i = 0; i < 10 && _connected; i++) {
        final command = i.isEven ? 'ON' : 'OFF';
        _expected = command;
        _waiting = Completer<void>();
        final sw = Stopwatch()..start();
        _publish(tLed, command);
        try {
          await _waiting!.future.timeout(const Duration(seconds: 3));
          sw.stop();
          if (_connected) samples.add(sw.elapsedMilliseconds);
        } on TimeoutException {
          // Pesan balasan tidak diterima dalam 3 detik.
        }
        _waiting = null;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted) return;
      if (samples.isEmpty) {
        setState(() => _latMqtt = 'Tidak ada respons');
      } else {
        final avg = samples.reduce((a, b) => a + b) / samples.length;
        setState(() => _latMqtt = '${avg.toStringAsFixed(1)} ms '
            '(min ${samples.reduce(math.min)}, maks ${samples.reduce(math.max)}, '
            '${samples.length}/10 sampel)');
      }
    } catch (e) {
      if (mounted) setState(() => _latMqtt = 'Gagal mengukur: $e');
    } finally {
      _waiting = null;
      if (mounted) setState(() => _measuring = false);
    }
  }

  void _disconnect() {
    _client?.disconnect();
    _connected = false;
    setState(() => _status = 'Diputuskan dari broker');
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    _client?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('MQTT Controller', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(_status),
        const SizedBox(height: 14),
        if (!_connected) ...[
          FilledButton.icon(
            onPressed: _connect,
            icon: const Icon(Icons.cloud),
            label: const Text('Hubungkan ke MQTT'),
          ),
        ] else ...[
          Text('Status ESP32: $_device'),
          Card(
            child: SwitchListTile(
              title: const Text('Kontrol LED via MQTT'),
              subtitle: const Text('Perintah melalui broker internet'),
              value: _ledOn,
              onChanged: _measuring ? null : (on) => _publish(tLed, on ? 'ON' : 'OFF'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('Suhu: $_suhu °C'),
              subtitle: Text('Kelembapan: $_hum %'),
              leading: const Icon(Icons.thermostat),
            ),
          ),
          TemperatureChart(temperatures: List<double>.of(_history)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _measuring ? null : _measureLatency,
            child: Text(_measuring ? 'Mengukur 10 kali...' : 'Ukur latensi MQTT (10 kali)'),
          ),
          Text('Latensi MQTT: $_latMqtt'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off),
            label: const Text('Putuskan MQTT'),
          ),
        ],
      ],
    );
  }
}

// Completer yang belum selesai diselesaikan saat sambungan broker terputus.
extension _CompleterTools on Completer<void> {
  void completeIfPending() {
    if (!isCompleted) complete();
  }
}
