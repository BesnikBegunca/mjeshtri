import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/dao_sketch_projects.dart';
import '../models/vizato_sketch.dart';

class VizatoPage extends StatefulWidget {
  const VizatoPage({super.key});

  @override
  State<VizatoPage> createState() => _VizatoPageState();
}

class _VizatoPageState extends State<VizatoPage> {
  final nameC = TextEditingController();
  final notesC = TextEditingController();
  final GlobalKey _canvasKey = GlobalKey();

  final List<SketchItem> _items = [];
  List<SketchProject> _savedProjects = [];

  DrawTool _tool = DrawTool.line;
  Color _selectedColor = Colors.red;
  double _strokeWidth = 2.0;
  double _scalePxPerMeter = 50.0; // 50px = 1m

  Offset? _start;
  Offset? _current;

  int? _editingProjectId;
  bool _loading = true;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    nameC.dispose();
    notesC.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await SketchProjectsDao.I.ensureTable();
    await _loadProjects();
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadProjects() async {
    final list = await SketchProjectsDao.I.list();
    if (!mounted) return;
    setState(() {
      _savedProjects = list;
    });
  }

  double _distancePx(Offset a, Offset b) {
    return (b - a).distance;
  }

  double _distanceMeters(Offset a, Offset b) {
    return _distancePx(a, b) / _scalePxPerMeter;
  }

  String _metersLabel(double meters) {
    return '${meters.toStringAsFixed(2)} m';
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _start = d.localPosition;
      _current = d.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _current = d.localPosition;
    });
  }

  Future<void> _onPanEnd(DragEndDetails d) async {
    if (_start == null || _current == null) return;

    final a = _start!;
    final b = _current!;

    if ((b - a).distance < 4) {
      setState(() {
        _start = null;
        _current = null;
      });
      return;
    }

    if (_tool == DrawTool.line) {
      final meters = _distanceMeters(a, b);
      _items.add(
        SketchItem(
          type: 'line',
          x1: a.dx,
          y1: a.dy,
          x2: b.dx,
          y2: b.dy,
          label: _metersLabel(meters),
          colorHex: colorToHex(_selectedColor),
          strokeWidth: _strokeWidth,
        ),
      );
    } else if (_tool == DrawTool.rect) {
      final widthPx = (b.dx - a.dx).abs();
      final heightPx = (b.dy - a.dy).abs();
      final widthM = widthPx / _scalePxPerMeter;
      final heightM = heightPx / _scalePxPerMeter;

      _items.add(
        SketchItem(
          type: 'rect',
          x1: a.dx,
          y1: a.dy,
          x2: b.dx,
          y2: b.dy,
          label:
              'W: ${widthM.toStringAsFixed(2)} m | H: ${heightM.toStringAsFixed(2)} m',
          colorHex: colorToHex(_selectedColor),
          strokeWidth: _strokeWidth,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _start = null;
      _current = null;
    });
  }

  void _undo() {
    if (_items.isEmpty) return;
    setState(() {
      _items.removeLast();
    });
  }

  void _clearCanvas() {
    setState(() {
      _items.clear();
      _start = null;
      _current = null;
    });
  }

  Future<void> _saveProject() async {
    final name = nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shkruaje emrin e skicës.')),
      );
      return;
    }

    final now = DateTime.now();

    final project = SketchProject(
      id: _editingProjectId,
      name: name,
      notes: notesC.text.trim(),
      itemsJson: jsonEncode(_items.map((e) => e.toMap()).toList()),
      createdAt: now,
      updatedAt: now,
    );

    if (_editingProjectId == null) {
      final id = await SketchProjectsDao.I.insert(project);
      _editingProjectId = id;
    } else {
      final old = await SketchProjectsDao.I.getById(_editingProjectId!);
      await SketchProjectsDao.I.update(
        project.copyWith(
          createdAt: old?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    await _loadProjects();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Skica u ruajt me sukses.')),
    );
  }

  Future<void> _loadProject(SketchProject p) async {
    setState(() {
      _editingProjectId = p.id;
      nameC.text = p.name;
      notesC.text = p.notes;
      _items
        ..clear()
        ..addAll(p.items.where((e) => e.type == 'line' || e.type == 'rect'));
      _start = null;
      _current = null;
    });
  }

  Future<void> _deleteProject(SketchProject p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fshije skicën?'),
        content: Text('A je i sigurt që don me fshi "${p.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Jo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Po'),
          ),
        ],
      ),
    );

    if (ok == true && p.id != null) {
      await SketchProjectsDao.I.delete(p.id!);
      if (_editingProjectId == p.id) {
        setState(() {
          _editingProjectId = null;
          nameC.clear();
          notesC.clear();
          _items.clear();
        });
      }
      await _loadProjects();
    }
  }

  void _newProject() {
    setState(() {
      _editingProjectId = null;
      nameC.clear();
      notesC.clear();
      _items.clear();
      _start = null;
      _current = null;
    });
  }

  Future<Uint8List> _captureCanvasImage() async {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      throw Exception('Canvas nuk u gjet.');
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Nuk u kriju image e skicës.');
    }

    return byteData.buffer.asUint8List();
  }

  Future<void> _printSketch() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuk ka skicë për printim.')),
      );
      return;
    }

    try {
      setState(() {
        _printing = true;
      });

      final imageBytes = await _captureCanvasImage();
      final image = pw.MemoryImage(imageBytes);
      final sketchName =
          nameC.text.trim().isEmpty ? 'Skica pa emër' : nameC.text.trim();
      final notes = notesC.text.trim();

      await Printing.layoutPdf(
        onLayout: (format) async {
          final pdf = pw.Document();

          pdf.addPage(
            pw.Page(
              pageFormat: format,
              build: (context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sketchName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (notes.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        notes,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                    pw.SizedBox(height: 12),
                    pw.Expanded(
                      child: pw.Container(
                        width: double.infinity,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 1),
                        ),
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.FittedBox(
                          fit: pw.BoxFit.contain,
                          child: pw.Image(image),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );

          return pdf.save();
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë printimit: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
        });
      }
    }
  }

  Widget _toolButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final previewItem = (_start != null && _current != null)
        ? SketchItem(
            type: _tool == DrawTool.line ? 'line' : 'rect',
            x1: _start!.dx,
            y1: _start!.dy,
            x2: _current!.dx,
            y2: _current!.dy,
            label: _tool == DrawTool.line
                ? _metersLabel(_distanceMeters(_start!, _current!))
                : 'W: ${((_current!.dx - _start!.dx).abs() / _scalePxPerMeter).toStringAsFixed(2)} m | '
                    'H: ${((_current!.dy - _start!.dy).abs() / _scalePxPerMeter).toStringAsFixed(2)} m',
            colorHex: colorToHex(_selectedColor),
            strokeWidth: _strokeWidth,
          )
        : null;

    return Column(
      children: [
        Material(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: 'Emri i skicës',
                      hintText: 'p.sh. Shpija e Filanit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: notesC,
                    decoration: const InputDecoration(
                      labelText: 'Shënime',
                      hintText: 'p.sh. Fasada lindje, kati 1...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                _toolButton(
                  icon: Icons.show_chart,
                  active: _tool == DrawTool.line,
                  onTap: () => setState(() => _tool = DrawTool.line),
                ),
                _toolButton(
                  icon: Icons.crop_square,
                  active: _tool == DrawTool.rect,
                  onTap: () => setState(() => _tool = DrawTool.rect),
                ),
                _toolButton(
                  icon: Icons.undo,
                  active: false,
                  onTap: _undo,
                ),
                _toolButton(
                  icon: Icons.delete_sweep_outlined,
                  active: false,
                  onTap: _clearCanvas,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('1m ='),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        initialValue: _scalePxPerMeter.toStringAsFixed(0),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          suffixText: 'px',
                        ),
                        onChanged: (v) {
                          final parsed =
                              double.tryParse(v.replaceAll(',', '.'));
                          if (parsed != null && parsed > 0) {
                            setState(() {
                              _scalePxPerMeter = parsed;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 130,
                  child: Slider(
                    value: _strokeWidth,
                    min: 1,
                    max: 8,
                    divisions: 7,
                    label: _strokeWidth.toStringAsFixed(0),
                    onChanged: (v) => setState(() => _strokeWidth = v),
                  ),
                ),
                DropdownButton<Color>(
                  value: _selectedColor,
                  items: const [
                    DropdownMenuItem(value: Colors.red, child: Text('Kuqe')),
                    DropdownMenuItem(value: Colors.blue, child: Text('Kaltër')),
                    DropdownMenuItem(
                        value: Colors.green, child: Text('Gjelbër')),
                    DropdownMenuItem(value: Colors.black, child: Text('Zezë')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedColor = v);
                    }
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _newProject,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Skicë e re'),
                ),
                FilledButton.icon(
                  onPressed: _saveProject,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Ruaj'),
                ),
                FilledButton.icon(
                  onPressed: _printing ? null : _printSketch,
                  icon: _printing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                  label: const Text('Printo'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.grey.shade100,
                  child: RepaintBoundary(
                    key: _canvasKey,
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        painter: _SketchPainter(
                          items: _items,
                          previewItem: previewItem,
                        ),
                        child: Container(),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 320,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Skicat e ruajtura',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _savedProjects.isEmpty
                          ? const Center(
                              child: Text('Nuk ka skica të ruajtura.'),
                            )
                          : ListView.separated(
                              itemCount: _savedProjects.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final p = _savedProjects[index];
                                return ListTile(
                                  title: Text(p.name),
                                  subtitle: Text(
                                    p.notes.isEmpty
                                        ? '${p.items.length} elemente'
                                        : '${p.notes}\n${p.items.length} elemente',
                                  ),
                                  isThreeLine: p.notes.isNotEmpty,
                                  onTap: () => _loadProject(p),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteProject(p),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SketchPainter extends CustomPainter {
  final List<SketchItem> items;
  final SketchItem? previewItem;

  _SketchPainter({
    required this.items,
    this.previewItem,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    for (final item in items) {
      _drawItem(canvas, item);
    }

    if (previewItem != null) {
      _drawItem(canvas, previewItem!, isPreview: true);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.18)
      ..strokeWidth = 1;

    const step = 25.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawItem(Canvas canvas, SketchItem item, {bool isPreview = false}) {
    final color = colorFromHex(item.colorHex).withOpacity(isPreview ? 0.6 : 1);
    final paint = Paint()
      ..color = color
      ..strokeWidth = item.strokeWidth
      ..style = PaintingStyle.stroke;

    final p1 = Offset(item.x1, item.y1);
    final p2 = Offset(item.x2, item.y2);

    if (item.type == 'line') {
      canvas.drawLine(p1, p2, paint);

      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawText(canvas, item.label, mid + const Offset(8, -8), color);
    } else if (item.type == 'rect') {
      final rect = Rect.fromPoints(p1, p2);
      canvas.drawRect(rect, paint);
      _drawText(canvas, item.label, rect.topLeft + const Offset(8, 8), color);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    double fontSize = 14,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        backgroundColor: Colors.white.withOpacity(0.75),
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: 260);

    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) {
    return true;
  }
}
