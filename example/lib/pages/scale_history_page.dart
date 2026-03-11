import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scale_reading.dart';
import '../services/reading_history_service.dart';

class ScaleHistoryPage extends StatefulWidget {
  const ScaleHistoryPage({super.key});

  @override
  State<ScaleHistoryPage> createState() => _ScaleHistoryPageState();
}

class _ScaleHistoryPageState extends State<ScaleHistoryPage> {
  List<ScaleReading> _readings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final readings = await ReadingHistoryService.loadScaleReadings();
    setState(() {
      _readings = readings;
      _loading = false;
    });
  }

  Future<void> _deleteReading(ScaleReading reading) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reading?'),
        content: Text(
          'Delete the reading from ${DateFormat('MMM d, h:mm a').format(reading.timestamp)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ReadingHistoryService.deleteScaleReading(reading.timestamp);
      await _load();
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Readings?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ReadingHistoryService.clearScaleReadings();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Scale History'),
        backgroundColor: cs.surface,
        actions: [
          if (_readings.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep, size: 22),
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _readings.isEmpty
              ? _buildEmpty(cs)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: _readings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _ReadingCard(
                    reading: _readings[i],
                    onDelete: () => _deleteReading(_readings[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.scale, size: 64, color: cs.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(
            'No scale readings yet',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Measurements will appear here automatically',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reading Card ──────────────────────────────────────────────────────

class _ReadingCard extends StatefulWidget {
  final ScaleReading reading;
  final VoidCallback onDelete;

  const _ReadingCard({required this.reading, required this.onDelete});

  @override
  State<_ReadingCard> createState() => _ReadingCardState();
}

class _ReadingCardState extends State<_ReadingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = widget.reading;
    final dateStr = DateFormat('MMM d, yyyy').format(r.timestamp);
    final timeStr = DateFormat('h:mm a').format(r.timestamp);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: date/time + weight
                Row(
                  children: [
                    // Date & time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Weight
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${r.weightKg}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                        Text(
                          'kg',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.primary.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Quick summary row
                _QuickStatsRow(reading: r),

                // Expand indicator
                Center(
                  child: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: cs.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),

                // Expanded details
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),
                  _DetailGrid(reading: r),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade300,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick Stats Row ───────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  final ScaleReading reading;
  const _QuickStatsRow({required this.reading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _miniStat(cs, 'BMI', reading.bmi.toString()),
        _miniStat(cs, 'Fat', '${reading.bodyFat}%'),
        _miniStat(cs, 'Muscle', '${reading.muscle} kg'),
        _miniStat(cs, 'HR', '${reading.heartRate}'),
      ],
    );
  }

  Widget _miniStat(ColorScheme cs, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

// ─── Detail Grid ───────────────────────────────────────────────────────

class _DetailGrid extends StatelessWidget {
  final ScaleReading reading;
  const _DetailGrid({required this.reading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = reading;

    final items = <_GridItem>[
      _GridItem('Weight', '${r.weightKg} kg', const Color(0xFF69F0AE)),
      _GridItem('BMI', '${r.bmi}', const Color(0xFF448AFF)),
      _GridItem('Body Fat', '${r.bodyFat} %', const Color(0xFFFF8A65)),
      _GridItem('Fat Mass', '${r.fatMass} kg', const Color(0xFFFF8A65)),
      _GridItem('Body Water', '${r.water} %', const Color(0xFF4FC3F7)),
      _GridItem('BMR', '${r.bmr} kcal', const Color(0xFFFFD54F)),
      _GridItem('Protein', '${r.protein} %', const Color(0xFFA5D6A7)),
      _GridItem('Skeletal Muscle', '${r.skeletalMuscle} kg', const Color(0xFF81C784)),
      _GridItem('Muscle Mass', '${r.muscle} kg', const Color(0xFF81C784)),
      _GridItem('Bone Mass', '${r.bone} kg', const Color(0xFFBCAAA4)),
      _GridItem('Visceral Fat', '${r.visceral}', const Color(0xFFEF5350)),
      _GridItem('Subcut. Fat', '${r.subcutaneous} %', const Color(0xFFFFAB91)),
      _GridItem('Body Age', '${r.bodyAge.round()}', const Color(0xFFCE93D8)),
      _GridItem('Heart Rate', '${r.heartRate} bpm', const Color(0xFFFF5252)),
      _GridItem('Cardiac Index', '${r.cardiacIndex}', const Color(0xFF80DEEA)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => _gridTile(cs, item)).toList(),
    );
  }

  Widget _gridTile(ColorScheme cs, _GridItem item) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridItem {
  final String label;
  final String value;
  final Color color;
  const _GridItem(this.label, this.value, this.color);
}
