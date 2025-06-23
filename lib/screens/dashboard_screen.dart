import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<List<dynamic>> csvData = [];
  String insights = '';
  bool loading = false;
  Timer? _kpiTimer;
  Map<String, dynamic> kpis = {};
  List<String> kpiHistory = [];

  @override
  void initState() {
    super.initState();
    _startKPIUpdates();
  }

  @override
  void dispose() {
    _kpiTimer?.cancel();
    super.dispose();
  }

  void _startKPIUpdates() {
    _kpiTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (csvData.isNotEmpty) {
        _updateRealTimeKPIs();
      }
    });
  }

  void _updateRealTimeKPIs() {
    if (csvData.isEmpty) return;

    setState(() {
      // Calculate real-time KPIs based on CSV data
      kpis = _calculateKPIs();
      
      // Add to history for trend tracking
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      kpiHistory.add('$timestamp: Total Records: ${kpis['totalRecords']}');
      if (kpiHistory.length > 10) kpiHistory.removeAt(0);
    });
  }

  Map<String, dynamic> _calculateKPIs() {
    if (csvData.length < 2) return {};

    double total = 0;
    double max = double.negativeInfinity;
    double min = double.infinity;
    int validRecords = 0;

    for (int i = 1; i < csvData.length; i++) {
      if (csvData[i].length > 1) {
        double value = double.tryParse(csvData[i][1].toString()) ?? 0;
        total += value;
        max = value > max ? value : max;
        min = value < min ? value : min;
        validRecords++;
      }
    }

    double average = validRecords > 0 ? total / validRecords : 0;
    double growthRate = validRecords > 1 ? ((csvData.length - 1) / validRecords) * 100 : 0;

    return {
      'totalRecords': csvData.length - 1,
      'totalValue': total,
      'average': average,
      'maximum': max == double.negativeInfinity ? 0 : max,
      'minimum': min == double.infinity ? 0 : min,
      'growthRate': growthRate,
      'lastUpdated': DateTime.now(),
    };
  }

  Future<void> pickCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null) {
      final fileBytes = result.files.single.bytes;
      if (fileBytes == null) return;

      final raw = utf8.decode(fileBytes);
      final csvList = const CsvToListConverter().convert(raw);

      setState(() {
        csvData = csvList;
        insights = '';
        kpis = _calculateKPIs();
      });

      await generateInsights(raw);
    }
  }

  Future<void> generateInsights(String csvRawData) async {
    setState(() => loading = true);
    const apiKey = '';
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey');

    final prompt = '''
You are an expert data analyst. Analyze the following CSV data and generate a comprehensive business intelligence report.
Include:
1. Key Performance Indicators (KPIs) analysis
2. Trend analysis and patterns
3. Data quality assessment
4. Business recommendations
5. Risk factors and opportunities
6. Comparative analysis
7. Forecasting insights

CSV Data:
$csvRawData

Provide actionable insights in a structured format with clear sections.
''';

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      final decoded = jsonDecode(response.body);
      final output = decoded['candidates']?[0]['content']?['parts']?[0]['text'];

      setState(() {
        insights = output ?? 'No insights available.';
        loading = false;
      });
    } catch (e) {
      setState(() {
        insights = 'Error generating insights: ';
        loading = false;
      });
    }
  }

  Widget _buildKPICard(String title, String value, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIDashboard() {
    if (kpis.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1024;
        final isTablet = constraints.maxWidth > 600;
        
        int crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);
        double childAspectRatio = isDesktop ? 1.5 : (isTablet ? 1.3 : 2.5);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "Real-time KPIs",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 8),
                      const SizedBox(width: 4),
                      Text(
                        "Live",
                        style: TextStyle(color: Colors.green[700], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildKPICard(
                  "Total Records",
                  "${kpis['totalRecords']}",
                  "Data entries",
                  Icons.dataset,
                  Colors.blue,
                ),
                _buildKPICard(
                  "Total Value",
                  "${kpis['totalValue']?.toStringAsFixed(2)}",
                  "Sum of all values",
                  Icons.attach_money,
                  Colors.green,
                ),
                _buildKPICard(
                  "Average",
                  "${kpis['average']?.toStringAsFixed(2)}",
                  "Mean value",
                  Icons.trending_up,
                  Colors.orange,
                ),
                _buildKPICard(
                  "Growth Rate",
                  "${kpis['growthRate']?.toStringAsFixed(1)}%",
                  "Performance indicator",
                  Icons.show_chart,
                  Colors.purple,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget buildBarChart() {
    if (csvData.length < 2 || csvData[0].length < 2) return const Text("Not enough data");

    List<BarChartGroupData> barData = [];
    for (int i = 1; i < csvData.length && i < 10; i++) {
      double y = double.tryParse(csvData[i][1].toString()) ?? 0;
      barData.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: y,
              width: 16,
              color: Colors.tealAccent,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bar Chart Analysis",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.5,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  barGroups: barData,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPieChart() {
    if (csvData.length < 2 || csvData[0].length < 2) return const Text("Not enough data");

    List<PieChartSectionData> pieData = [];
    for (int i = 1; i < csvData.length && i < 6; i++) {
      double value = double.tryParse(csvData[i][1].toString()) ?? 0;
      pieData.add(
        PieChartSectionData(
          value: value,
          title: '${((value / kpis['totalValue']) * 100).toStringAsFixed(1)}%',
          color: Colors.primaries[i % Colors.primaries.length],
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Distribution Analysis",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.3,
              child: PieChart(
                PieChartData(
                  sections: pieData,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLineChart() {
    if (csvData.length < 2 || csvData[0].length < 2) return const Text("Not enough data");

    List<FlSpot> spots = [];
    for (int i = 1; i < csvData.length && i < 10; i++) {
      double y = double.tryParse(csvData[i][1].toString()) ?? 0;
      spots.add(FlSpot(i.toDouble(), y));
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Trend Analysis",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.5,
              child: LineChart(
                LineChartData(
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.amber,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.amber.withOpacity(0.1),
                      ),
                      dotData: FlDotData(show: true),
                    )
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AI-Generated Insights",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[600]!
                      : Colors.grey[300]!,
                ),
              ),
              child: Text(
                insights.isEmpty ? 'Upload a CSV file to generate insights...' : insights,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIHistory() {
    if (kpiHistory.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Real-time Updates",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              child: ListView.builder(
                itemCount: kpiHistory.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kpiHistory[kpiHistory.length - 1 - index],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("InsightAI: Advanced Dashboard"),
        actions: [
          if (csvData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  "Last Updated: ${kpis['lastUpdated'] != null ? TimeOfDay.fromDateTime(kpis['lastUpdated']).format(context) : 'Never'}",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1024;
          // ignore: unused_local_variable
          final isTablet = constraints.maxWidth > 600;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Upload button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: pickCSV,
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Upload CSV File"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Generating AI insights..."),
                        ],
                      ),
                    ),
                  )
                else if (csvData.isNotEmpty) ...[
                  // KPI Dashboard
                  _buildKPIDashboard(),
                  const SizedBox(height: 24),

                  // Charts section - responsive layout
                  if (isDesktop) ...[
                    // Desktop: Side by side charts
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: buildBarChart()),
                        const SizedBox(width: 16),
                        Expanded(child: buildPieChart()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildLineChart(),
                  ] else ...[
                    // Mobile/Tablet: Stacked charts
                    buildBarChart(),
                    const SizedBox(height: 16),
                    buildPieChart(),
                    const SizedBox(height: 16),
                    buildLineChart(),
                  ],

                  const SizedBox(height: 24),

                  // Bottom section - responsive layout
                  if (isDesktop) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildInsightsSection()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildKPIHistory()),
                      ],
                    ),
                  ] else ...[
                    _buildInsightsSection(),
                    const SizedBox(height: 16),
                    _buildKPIHistory(),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}