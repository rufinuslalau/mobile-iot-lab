
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

const Color primaryPurple = Color(0xFF7C3AED);
const Color darkPurple = Color(0xFF5B21B6);
const Color lightPurple = Color(0xFFF5F3FF);
const Color borderPurple = Color(0xFFE9D5FF);

class TemperatureChart extends StatelessWidget {
  final List<double> temperatures;

  const TemperatureChart({
    super.key,
    required this.temperatures,
  });

  static const int maxData = 30;

  @override
  Widget build(BuildContext context) {
    // Mengambil maksimal 30 data terbaru.
    final validData = temperatures
        .where((value) => value.isFinite)
        .toList();

    final data = validData.length > maxData
        ? validData.sublist(validData.length - maxData)
        : validData;

    final bool hasData = data.isNotEmpty;

    final double? latest = hasData ? data.last : null;

    final double? minimum = hasData
        ? data.reduce(math.min)
        : null;

    final double? maximum = hasData
        ? data.reduce(math.max)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderPurple,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // =================================
          // HEADER DASHBOARD
          // =================================

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 10),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monitoring Suhu Real-Time',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: darkPurple,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dashboard monitoring sensor',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =================================
          // INFORMASI JUMLAH DATA
          // =================================

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: primaryPurple,
                  size: 17,
                ),

                const SizedBox(width: 7),

                Text(
                  '${data.length}/$maxData Data Suhu Terbaru',
                  style: const TextStyle(
                    fontSize: 12,
                    color: darkPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // =================================
          // GRAFIK SUHU
          // =================================

          if (!hasData)
            Container(
              height: 230,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.device_thermostat_outlined,
                    size: 46,
                    color: primaryPurple,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada riwayat suhu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkPurple,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Menunggu data sensor ESP32...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          else
            _buildLineChart(data, minimum!, maximum!),

          const SizedBox(height: 18),

          // =================================
          // KARTU STATISTIK
          // =================================

          Row(
            children: [
              Expanded(
                child: _statCard(
                  title: 'Terbaru',
                  value: latest,
                  icon: Icons.thermostat,
                  color: primaryPurple,
                ),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: _statCard(
                  title: 'Minimum',
                  value: minimum,
                  icon: Icons.south_rounded,
                  color: const Color(0xFF0284C7),
                ),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: _statCard(
                  title: 'Maksimum',
                  value: maximum,
                  icon: Icons.north_rounded,
                  color: const Color(0xFFEA580C),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // =================================
          // FOOTER
          // =================================

          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: Colors.black54,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  'Grafik diperbarui saat data sensor diterima.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================
  // MEMBUAT GRAFIK GARIS
  // =========================================

  Widget _buildLineChart(
    List<double> data,
    double minimum,
    double maximum,
  ) {
    final List<FlSpot> spots = [];

    for (int i = 0; i < data.length; i++) {
      spots.add(
        FlSpot(i.toDouble(), data[i]),
      );
    }

    final double minY = (minimum - 1).floorToDouble();
    final double maxY = (maximum + 1).ceilToDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 18, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 12),
            child: Text(
              'Grafik Perubahan Suhu (°C)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: darkPurple,
              ),
            ),
          ),

          SizedBox(
            height: 230,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: math.max(1, data.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,

                // GRID
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFEDE9FE),
                      strokeWidth: 1,
                    );
                  },
                ),

                // BORDER
                borderData: FlBorderData(
                  show: false,
                ),

                // LABEL SUMBU
                titlesData: FlTitlesData(
                  show: true,

                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),

                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),

                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: math.max(
                        1.0,
                        (maxY - minY) / 4,
                      ),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),

                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      'Urutan Pembacaan',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                    axisNameSize: 22,

                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,

                      getTitlesWidget: (value, meta) {
                        final int index = value.toInt();

                        if (value != index.toDouble() ||
                            index < 0 ||
                            index >= data.length) {
                          return const SizedBox.shrink();
                        }

                        final int nomor = index + 1;

                        if (nomor != 1 &&
                            nomor % 5 != 0 &&
                            nomor != data.length) {
                          return const SizedBox.shrink();
                        }

                        return Text(
                          '$nomor',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // INTERAKSI SENTUH GRAFIK
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,

                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          'Data ${spot.x.toInt() + 1}\n'
                          '${spot.y.toStringAsFixed(1)} °C',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),

                // GARIS GRAFIK
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,

                    // Garis melengkung
                    isCurved: true,

                    color: primaryPurple,
                    barWidth: 3.5,

                    isStrokeCapRound: true,

                    // TITIK SETIAP DATA
                    dotData: FlDotData(
                      show: true,

                      getDotPainter: (
                        spot,
                        percent,
                        barData,
                        index,
                      ) {
                        return FlDotCirclePainter(
                          radius: index == data.length - 1 ? 5 : 3,
                          color: primaryPurple,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),

                    // WARNA AREA DI BAWAH GRAFIK
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primaryPurple.withValues(alpha: 0.25),
                          primaryPurple.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              duration: const Duration(
                milliseconds: 350,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // KARTU STATISTIK SUHU
  // =========================================

  Widget _statCard({
    required String title,
    required double? value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: borderPurple,
        ),
      ),

      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),

          const SizedBox(height: 7),

          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            value == null
                ? '- °C'
                : '${value.toStringAsFixed(1)}°C',

            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),

            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
