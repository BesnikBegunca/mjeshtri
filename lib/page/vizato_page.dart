import 'dart:convert';
import 'dart:math' as math;
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
  final List<SketchItem> _redoStack = [];

  List<SketchProject> _savedProjects = [];

  DrawTool _tool = DrawTool.line;
  Color _selectedColor = Colors.red;
  double _strokeWidth = 2.0;
  double _scalePxPerMeter = 50.0;

  bool _snapToGrid = true;
  double _gridStep = 25.0;
  bool _moveMode = false;

  // Snap për lidhje line-line në endpoint
  bool _endpointSnapEnabled = true;
  double _endpointSnapThreshold = 18.0;

  Offset? _start;
  Offset? _current;

  // Ruajmë nëse start/current janë ngjit në endpoint ekzistues
  Offset? _snappedStartPoint;
  Offset? _snappedCurrentPoint;

  int? _selectedIndex;
  Offset? _moveLastPoint;

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

  Offset _snapOffset(Offset p) {
    if (!_snapToGrid || _gridStep <= 1) return p;
    return Offset(
      (p.dx / _gridStep).round() * _gridStep,
      (p.dy / _gridStep).round() * _gridStep,
    );
  }

  double _distancePx(Offset a, Offset b) {
    return (b - a).distance;
  }

  double _distanceMeters(Offset a, Offset b) {
    return _distancePx(a, b) / _scalePxPerMeter;
  }

  double _lineAngleDegrees(Offset a, Offset b) {
    final radians = math.atan2(b.dy - a.dy, b.dx - a.dx);
    return radians * 180 / math.pi;
  }

  String _metersLabel(double meters) {
    return '${meters.toStringAsFixed(2)} m';
  }

  String _lineLabel(Offset a, Offset b) {
    final meters = _distanceMeters(a, b);
    final angle = _lineAngleDegrees(a, b);
    return '${meters.toStringAsFixed(2)} m | ${angle.toStringAsFixed(1)}°';
  }

  String _rectLabel(Offset a, Offset b) {
    final widthPx = (b.dx - a.dx).abs();
    final heightPx = (b.dy - a.dy).abs();
    final widthM = widthPx / _scalePxPerMeter;
    final heightM = heightPx / _scalePxPerMeter;
    final area = widthM * heightM;
    return 'W: ${widthM.toStringAsFixed(2)} m | H: ${heightM.toStringAsFixed(2)} m | A: ${area.toStringAsFixed(2)} m²';
  }

  SketchItem _cloneItem(SketchItem item) {
    return SketchItem(
      type: item.type,
      x1: item.x1,
      y1: item.y1,
      x2: item.x2,
      y2: item.y2,
      label: item.label,
      colorHex: item.colorHex,
      strokeWidth: item.strokeWidth,
    );
  }

  SketchItem _copyWithMoved(SketchItem item, Offset delta) {
    final moved = SketchItem(
      type: item.type,
      x1: item.x1 + delta.dx,
      y1: item.y1 + delta.dy,
      x2: item.x2 + delta.dx,
      y2: item.y2 + delta.dy,
      label: item.label,
      colorHex: item.colorHex,
      strokeWidth: item.strokeWidth,
    );

    return _rebuildItemLabel(moved);
  }

  SketchItem _rebuildItemLabel(SketchItem item) {
    final a = Offset(item.x1, item.y1);
    final b = Offset(item.x2, item.y2);

    if (item.type == 'line') {
      return SketchItem(
        type: item.type,
        x1: item.x1,
        y1: item.y1,
        x2: item.x2,
        y2: item.y2,
        label: _lineLabel(a, b),
        colorHex: item.colorHex,
        strokeWidth: item.strokeWidth,
      );
    }

    if (item.type == 'rect') {
      return SketchItem(
        type: item.type,
        x1: item.x1,
        y1: item.y1,
        x2: item.x2,
        y2: item.y2,
        label: _rectLabel(a, b),
        colorHex: item.colorHex,
        strokeWidth: item.strokeWidth,
      );
    }

    return _cloneItem(item);
  }

  Rect _itemBounds(SketchItem item) {
    final p1 = Offset(item.x1, item.y1);
    final p2 = Offset(item.x2, item.y2);

    if (item.type == 'rect') {
      return Rect.fromPoints(p1, p2);
    }

    final pad = math.max(14.0, item.strokeWidth + 10);
    return Rect.fromPoints(p1, p2).inflate(pad);
  }

  double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;

    if (dx == 0 && dy == 0) {
      return (p - a).distance;
    }

    final t =
        (((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / (dx * dx + dy * dy);
    final clampedT = t.clamp(0.0, 1.0);
    final projection = Offset(a.dx + clampedT * dx, a.dy + clampedT * dy);
    return (p - projection).distance;
  }

  bool _hitTestItem(SketchItem item, Offset p) {
    final a = Offset(item.x1, item.y1);
    final b = Offset(item.x2, item.y2);

    if (item.type == 'rect') {
      final rect = Rect.fromPoints(a, b);
      return rect.inflate(10).contains(p);
    }

    if (item.type == 'line') {
      final tolerance = math.max(12.0, item.strokeWidth + 8);
      return _distancePointToSegment(p, a, b) <= tolerance;
    }

    return false;
  }

  int? _findItemIndexAt(Offset p) {
    for (int i = _items.length - 1; i >= 0; i--) {
      if (_hitTestItem(_items[i], p)) {
        return i;
      }
    }
    return null;
  }

  bool _samePoint(Offset a, Offset b, {double epsilon = 0.01}) {
    return (a - b).distance <= epsilon;
  }

  Offset? _findNearestLineEndpoint(Offset p) {
    if (!_endpointSnapEnabled || _tool != DrawTool.line || _moveMode) {
      return null;
    }

    Offset? nearest;
    double bestDistance = _endpointSnapThreshold;

    for (final item in _items) {
      if (item.type != 'line') continue;

      final p1 = Offset(item.x1, item.y1);
      final p2 = Offset(item.x2, item.y2);

      final d1 = (p - p1).distance;
      if (d1 <= bestDistance) {
        bestDistance = d1;
        nearest = p1;
      }

      final d2 = (p - p2).distance;
      if (d2 <= bestDistance) {
        bestDistance = d2;
        nearest = p2;
      }
    }

    return nearest;
  }

  ({Offset point, Offset? snappedTo}) _resolveDrawPoint(Offset raw) {
    final endpoint = _findNearestLineEndpoint(raw);
    if (endpoint != null) {
      return (point: endpoint, snappedTo: endpoint);
    }

    final grid = _snapOffset(raw);
    return (point: grid, snappedTo: null);
  }

  void _pushRedoClear() {
    _redoStack.clear();
  }

  void _onPanStart(DragStartDetails d) {
    final resolved = _resolveDrawPoint(d.localPosition);

    if (_moveMode) {
      final hitIndex = _findItemIndexAt(resolved.point);
      setState(() {
        _selectedIndex = hitIndex;
        _moveLastPoint = hitIndex != null ? resolved.point : null;
        _start = null;
        _current = null;
        _snappedStartPoint = null;
        _snappedCurrentPoint = null;
      });
      return;
    }

    setState(() {
      _selectedIndex = null;
      _start = resolved.point;
      _current = resolved.point;
      _snappedStartPoint = resolved.snappedTo;
      _snappedCurrentPoint = resolved.snappedTo;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final resolved = _resolveDrawPoint(d.localPosition);

    if (_moveMode) {
      if (_selectedIndex == null || _moveLastPoint == null) return;

      final delta = resolved.point - _moveLastPoint!;
      if (delta == Offset.zero) return;

      setState(() {
        _items[_selectedIndex!] =
            _copyWithMoved(_items[_selectedIndex!], delta);
        _moveLastPoint = resolved.point;
      });
      return;
    }

    setState(() {
      _current = resolved.point;
      _snappedCurrentPoint = resolved.snappedTo;
    });
  }

  Future<void> _onPanEnd(DragEndDetails d) async {
    if (_moveMode) {
      if (_selectedIndex != null) {
        _pushRedoClear();
      }
      setState(() {
        _moveLastPoint = null;
      });
      return;
    }

    if (_start == null || _current == null) return;

    final a = _start!;
    final b = _current!;

    if ((b - a).distance < 4) {
      setState(() {
        _start = null;
        _current = null;
        _snappedStartPoint = null;
        _snappedCurrentPoint = null;
      });
      return;
    }

    if (_tool == DrawTool.line) {
      _items.add(
        SketchItem(
          type: 'line',
          x1: a.dx,
          y1: a.dy,
          x2: b.dx,
          y2: b.dy,
          label: _lineLabel(a, b),
          colorHex: colorToHex(_selectedColor),
          strokeWidth: _strokeWidth,
        ),
      );
    } else if (_tool == DrawTool.rect) {
      _items.add(
        SketchItem(
          type: 'rect',
          x1: a.dx,
          y1: a.dy,
          x2: b.dx,
          y2: b.dy,
          label: _rectLabel(a, b),
          colorHex: colorToHex(_selectedColor),
          strokeWidth: _strokeWidth,
        ),
      );
    }

    _pushRedoClear();

    if (!mounted) return;
    setState(() {
      _selectedIndex = _items.isNotEmpty ? _items.length - 1 : null;
      _start = null;
      _current = null;
      _snappedStartPoint = null;
      _snappedCurrentPoint = null;
    });
  }

  void _onTapDown(TapDownDetails d) {
    final resolved = _resolveDrawPoint(d.localPosition);
    final hitIndex = _findItemIndexAt(resolved.point);

    setState(() {
      _selectedIndex = hitIndex;
      _start = null;
      _current = null;
      _moveLastPoint = null;
      _snappedStartPoint = null;
      _snappedCurrentPoint = null;
    });
  }

  void _undo() {
    if (_items.isEmpty) return;
    setState(() {
      final removed = _items.removeLast();
      _redoStack.add(_cloneItem(removed));
      if (_selectedIndex != null && _selectedIndex! >= _items.length) {
        _selectedIndex = _items.isEmpty ? null : _items.length - 1;
      }
      _start = null;
      _current = null;
      _snappedStartPoint = null;
      _snappedCurrentPoint = null;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      final restored = _redoStack.removeLast();
      _items.add(_cloneItem(restored));
      _selectedIndex = _items.length - 1;
      _start = null;
      _current = null;
      _snappedStartPoint = null;
      _snappedCurrentPoint = null;
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null) return;
    setState(() {
      final removed = _items.removeAt(_selectedIndex!);
      _redoStack.add(_cloneItem(removed));
      if (_items.isEmpty) {
        _selectedIndex = null;
      } else if (_selectedIndex! >= _items.length) {
        _selectedIndex = _items.length - 1;
      }
    });
  }

  void _duplicateSelected() {
    if (_selectedIndex == null) return;

    final item = _items[_selectedIndex!];
    final duplicated = _copyWithMoved(item, const Offset(20, 20));

    setState(() {
      _items.add(duplicated);
      _selectedIndex = _items.length - 1;
      _pushRedoClear();
    });
  }

  void _clearCanvas() {
    setState(() {
      _items.clear();
      _redoStack.clear();
      _selectedIndex = null;
      _start = null;
      _current = null;
      _moveLastPoint = null;
      _snappedStartPoint = null;
      _snappedCurrentPoint = null;
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
        ..addAll(
          p.items
              .where((e) => e.type == 'line' || e.type == 'rect')
              .map(_rebuildItemLabel),
        );
      _redoStack.clear();
      _selectedIndex = null;
      _start = null;
      _current = null;
      _moveLastPoint = null;
      _snappedStartPoint = null;
      _snappedCurrentPoint = null;
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
          _redoStack.clear();
          _selectedIndex = null;
          _start = null;
          _current = null;
          _moveLastPoint = null;
          _snappedStartPoint = null;
          _snappedCurrentPoint = null;
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
      _redoStack.clear();
      _selectedIndex = null;
      _start = null;
      _current = null;
      _moveLastPoint = null;
      _snappedStartPoint = null;
      _snappedCurrentPoint = null;
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
    String? tooltip,
  }) {
    final child = InkWell(
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

    if (tooltip == null) return child;
    return Tooltip(message: tooltip, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final previewItem = (!_moveMode && _start != null && _current != null)
        ? SketchItem(
            type: _tool == DrawTool.line ? 'line' : 'rect',
            x1: _start!.dx,
            y1: _start!.dy,
            x2: _current!.dx,
            y2: _current!.dy,
            label: _tool == DrawTool.line
                ? _lineLabel(_start!, _current!)
                : _rectLabel(_start!, _current!),
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
                  active: !_moveMode && _tool == DrawTool.line,
                  onTap: () => setState(() {
                    _moveMode = false;
                    _tool = DrawTool.line;
                  }),
                  tooltip: 'Line',
                ),
                _toolButton(
                  icon: Icons.crop_square,
                  active: !_moveMode && _tool == DrawTool.rect,
                  onTap: () => setState(() {
                    _moveMode = false;
                    _tool = DrawTool.rect;
                  }),
                  tooltip: 'Rectangle',
                ),
                _toolButton(
                  icon: Icons.open_with,
                  active: _moveMode,
                  onTap: () => setState(() {
                    _moveMode = !_moveMode;
                    _start = null;
                    _current = null;
                    _moveLastPoint = null;
                    _snappedStartPoint = null;
                    _snappedCurrentPoint = null;
                  }),
                  tooltip: 'Move/Select',
                ),
                _toolButton(
                  icon: Icons.undo,
                  active: false,
                  onTap: _undo,
                  tooltip: 'Undo',
                ),
                _toolButton(
                  icon: Icons.redo,
                  active: false,
                  onTap: _redo,
                  tooltip: 'Redo',
                ),
                _toolButton(
                  icon: Icons.content_copy_outlined,
                  active: _selectedIndex != null,
                  onTap: _duplicateSelected,
                  tooltip: 'Duplicate selected',
                ),
                _toolButton(
                  icon: Icons.delete_outline,
                  active: _selectedIndex != null,
                  onTap: _deleteSelected,
                  tooltip: 'Delete selected',
                ),
                _toolButton(
                  icon: Icons.delete_sweep_outlined,
                  active: false,
                  onTap: _clearCanvas,
                  tooltip: 'Clear all',
                ),
                FilterChip(
                  label: const Text('Snap'),
                  selected: _snapToGrid,
                  onSelected: (v) => setState(() => _snapToGrid = v),
                ),
                FilterChip(
                  label: const Text('Point Snap'),
                  selected: _endpointSnapEnabled,
                  onSelected: (v) => setState(() => _endpointSnapEnabled = v),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Grid'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: _gridStep.toStringAsFixed(0),
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
                          if (parsed != null && parsed >= 5) {
                            setState(() {
                              _gridStep = parsed;
                            });
                          }
                        },
                      ),
                    ),
                  ],
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
                              for (int i = 0; i < _items.length; i++) {
                                _items[i] = _rebuildItemLabel(_items[i]);
                              }
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
                      value: Colors.green,
                      child: Text('Gjelbër'),
                    ),
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
                      behavior: HitTestBehavior.opaque,
                      onTapDown: _onTapDown,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        painter: _SketchPainter(
                          items: _items,
                          previewItem: previewItem,
                          selectedIndex: _selectedIndex,
                          gridStep: _gridStep,
                          showGrid: true,
                          snappedStartPoint: _snappedStartPoint,
                          snappedCurrentPoint: _snappedCurrentPoint,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skicat e ruajtura',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _moveMode
                                ? 'Mode: Move/Select'
                                : 'Mode: ${_tool == DrawTool.line ? 'Line' : 'Rect'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedIndex == null
                                ? 'S’ka element të zgjedhur'
                                : 'Selected: ${_items[_selectedIndex!].type}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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

class _AngleMarker {
  final Offset center;
  final Offset p1;
  final Offset p2;
  final double degrees;

  _AngleMarker({
    required this.center,
    required this.p1,
    required this.p2,
    required this.degrees,
  });
}

class _SketchPainter extends CustomPainter {
  final List<SketchItem> items;
  final SketchItem? previewItem;
  final int? selectedIndex;
  final double gridStep;
  final bool showGrid;
  final Offset? snappedStartPoint;
  final Offset? snappedCurrentPoint;

  _SketchPainter({
    required this.items,
    this.previewItem,
    required this.selectedIndex,
    required this.gridStep,
    required this.showGrid,
    required this.snappedStartPoint,
    required this.snappedCurrentPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    for (int i = 0; i < items.length; i++) {
      _drawItem(
        canvas,
        items[i],
        isSelected: i == selectedIndex,
      );
    }

    if (previewItem != null) {
      _drawItem(canvas, previewItem!, isPreview: true);
    }

    _drawAngles(canvas);

    if (snappedStartPoint != null) {
      _drawSnapPoint(canvas, snappedStartPoint!);
    }
    if (snappedCurrentPoint != null) {
      _drawSnapPoint(canvas, snappedCurrentPoint!);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.18)
      ..strokeWidth = 1;

    final step = gridStep <= 1 ? 25.0 : gridStep;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  bool _samePoint(Offset a, Offset b, {double epsilon = 0.01}) {
    return (a - b).distance <= epsilon;
  }

  double _angleBetweenVectors(Offset v1, Offset v2) {
    final len1 = v1.distance;
    final len2 = v2.distance;
    if (len1 == 0 || len2 == 0) return 0;

    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final cosValue = (dot / (len1 * len2)).clamp(-1.0, 1.0);
    return math.acos(cosValue) * 180 / math.pi;
  }

  List<_AngleMarker> _collectAngleMarkers() {
    final lineItems = <SketchItem>[
      ...items.where((e) => e.type == 'line'),
      if (previewItem != null && previewItem!.type == 'line') previewItem!,
    ];

    final markers = <_AngleMarker>[];

    for (int i = 0; i < lineItems.length; i++) {
      final li = lineItems[i];
      final liA = Offset(li.x1, li.y1);
      final liB = Offset(li.x2, li.y2);

      for (int j = i + 1; j < lineItems.length; j++) {
        final lj = lineItems[j];
        final ljA = Offset(lj.x1, lj.y1);
        final ljB = Offset(lj.x2, lj.y2);

        Offset? joint;
        Offset? other1;
        Offset? other2;

        if (_samePoint(liA, ljA)) {
          joint = liA;
          other1 = liB;
          other2 = ljB;
        } else if (_samePoint(liA, ljB)) {
          joint = liA;
          other1 = liB;
          other2 = ljA;
        } else if (_samePoint(liB, ljA)) {
          joint = liB;
          other1 = liA;
          other2 = ljB;
        } else if (_samePoint(liB, ljB)) {
          joint = liB;
          other1 = liA;
          other2 = ljA;
        }

        if (joint != null && other1 != null && other2 != null) {
          final v1 = other1 - joint;
          final v2 = other2 - joint;
          final angle = _angleBetweenVectors(v1, v2);

          if (angle > 0.1 && angle < 179.9) {
            markers.add(
              _AngleMarker(
                center: joint,
                p1: other1,
                p2: other2,
                degrees: angle,
              ),
            );
          }
        }
      }
    }

    return markers;
  }

  void _drawAngles(Canvas canvas) {
    final markers = _collectAngleMarkers();

    for (final marker in markers) {
      _drawAngleMarker(canvas, marker);
    }
  }

  void _drawAngleMarker(Canvas canvas, _AngleMarker marker) {
    final center = marker.center;
    final v1 = marker.p1 - center;
    final v2 = marker.p2 - center;

    final a1 = math.atan2(v1.dy, v1.dx);
    final a2 = math.atan2(v2.dy, v2.dx);

    double startAngle = a1;
    double sweepAngle = a2 - a1;

    while (sweepAngle <= -math.pi) {
      sweepAngle += 2 * math.pi;
    }
    while (sweepAngle > math.pi) {
      sweepAngle -= 2 * math.pi;
    }

    if (sweepAngle < 0) {
      startAngle = a2;
      sweepAngle = -sweepAngle;
    }

    final radius = 24.0;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final arcPaint = Paint()
      ..color = Colors.deepOrange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      arcRect,
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    final labelAngle = startAngle + sweepAngle / 2;
    final labelPos = center +
        Offset(math.cos(labelAngle), math.sin(labelAngle)) * (radius + 12);

    _drawText(
      canvas,
      '${marker.degrees.toStringAsFixed(1)}°',
      labelPos,
      Colors.deepOrange,
      fontSize: 13,
    );
  }

  void _drawSnapPoint(Canvas canvas, Offset p) {
    final fillPaint = Paint()
      ..color = Colors.deepOrange.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.deepOrange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(p, 9, fillPaint);
    canvas.drawCircle(p, 5, strokePaint);
  }

  void _drawItem(
    Canvas canvas,
    SketchItem item, {
    bool isPreview = false,
    bool isSelected = false,
  }) {
    final baseColor = colorFromHex(item.colorHex);
    final color = baseColor.withOpacity(isPreview ? 0.6 : 1);

    final paint = Paint()
      ..color = color
      ..strokeWidth = item.strokeWidth
      ..style = PaintingStyle.stroke;

    final p1 = Offset(item.x1, item.y1);
    final p2 = Offset(item.x2, item.y2);

    if (item.type == 'line') {
      canvas.drawLine(p1, p2, paint);

      if (isSelected) {
        final selPaint = Paint()
          ..color = Colors.orange
          ..strokeWidth = item.strokeWidth + 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(p1, 5, selPaint);
        canvas.drawCircle(p2, 5, selPaint);
      }

      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawText(canvas, item.label, mid + const Offset(8, -8), color);
    } else if (item.type == 'rect') {
      final rect = Rect.fromPoints(p1, p2);
      canvas.drawRect(rect, paint);

      if (isSelected) {
        final selectedPaint = Paint()
          ..color = Colors.orange
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawRect(rect.inflate(4), selectedPaint);
      }

      _drawText(canvas, item.label, rect.topLeft + const Offset(8, 8), color);
    }

    if (isSelected && item.type == 'line') {
      final bounds = Rect.fromPoints(p1, p2).inflate(6);
      final selectedPaint = Paint()
        ..color = Colors.orange
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawRect(bounds, selectedPaint);
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
        backgroundColor: Colors.white.withOpacity(0.78),
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: 320);

    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) {
    return true;
  }
}
