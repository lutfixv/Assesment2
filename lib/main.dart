import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==== Dependency Injection (Service & Repository) ====
  final notesRepository = NotesRepository();
  final locationService = LocationService();
  final weatherService = WeatherService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        notesRepository: notesRepository,
        locationService: locationService,
        weatherService: weatherService,
      ),
      child: const DailyNotesApp(),
    ),
  );
}

/// =====================================================
///                     DATA MODEL
/// =====================================================

class Note {
  final int? id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;

  Note({
    this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
  });

  Note copyWith({
    int? id,
    String? title,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = <String, dynamic>{
      'title': title,
      'body': body,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'lat': latitude,
      'lon': longitude,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      latitude: map['lat'] as double?,
      longitude: map['lon'] as double?,
    );
  }
}

/// =====================================================
///                 SERVICE / REPOSITORY
/// =====================================================

class NotesRepository {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'daily_notes.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE notes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          lat REAL,
          lon REAL
        )
        ''');
      },
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('Database belum diinisialisasi');
    }
    return db;
  }

  Future<List<Note>> fetchAll() async {
    final rows = await _database.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    return rows.map((e) => Note.fromMap(e)).toList();
  }

  Future<int> insert(Note note) async {
    return _database.insert('notes', note.toMap(includeId: false));
  }

  Future<void> update(Note note) async {
    await _database.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> delete(int id) async {
    await _database.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class LocationService {
  Future<Position> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Layanan lokasi dimatikan');
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak');
      }
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak permanen');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }
}

class WeatherService {
  Future<double?> fetchTemperature({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude&current_weather=true',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final current = json['current_weather'] as Map<String, dynamic>?;
    final temp = current?['temperature'];
    if (temp is num) return temp.toDouble();
    return null;
  }
}

/// =====================================================
///              GLOBAL STATE (Provider)
/// =====================================================

class AppState extends ChangeNotifier {
  final NotesRepository notesRepository;
  final LocationService locationService;
  final WeatherService weatherService;

  AppState({
    required this.notesRepository,
    required this.locationService,
    required this.weatherService,
  }) {
    _bootstrap();
  }

  bool _busy = true;
  bool get isBusy => _busy;

  bool _darkMode = false;
  bool get darkMode => _darkMode;

  String? _ownerName;
  String? get ownerName => _ownerName;

  List<Note> _notes = [];
  List<Note> get notes => _notes;

  // Weather / Location
  bool _weatherLoading = false;
  bool get weatherLoading => _weatherLoading;

  String? _weatherError;
  String? get weatherError => _weatherError;

  double? _temperature;
  double? get temperature => _temperature;

  String? _locationLabel;
  String? get locationLabel => _locationLabel;

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _ownerName = prefs.getString('owner_name');

      await notesRepository.init();
      _notes = await notesRepository.fetchAll();

      await refreshWeather();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> setOwnerName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _ownerName = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_name', trimmed);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _darkMode = !_darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    notifyListeners();
  }

  Future<void> refreshNotes() async {
    _notes = await notesRepository.fetchAll();
    notifyListeners();
  }

  Future<void> addOrUpdateNote(Note note) async {
    if (note.id == null) {
      final id = await notesRepository.insert(note);
      final saved = note.copyWith(id: id);
      _notes.insert(0, saved);
    } else {
      await notesRepository.update(note);
      final idx = _notes.indexWhere((n) => n.id == note.id);
      if (idx != -1) {
        _notes[idx] = note;
      }
    }
    notifyListeners();
  }

  Future<void> deleteNote(Note note) async {
    if (note.id != null) {
      await notesRepository.delete(note.id!);
    }
    _notes.removeWhere((n) => n.id == note.id);
    notifyListeners();
  }

  Future<void> refreshWeather() async {
    _weatherLoading = true;
    _weatherError = null;
    notifyListeners();

    try {
      final pos = await locationService.getCurrentPosition();
      _locationLabel =
          'Lat ${pos.latitude.toStringAsFixed(2)}, Lon ${pos.longitude.toStringAsFixed(2)}';

      final temp = await weatherService.fetchTemperature(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (temp == null) {
        _weatherError = 'Cuaca tidak tersedia';
        _temperature = null;
      } else {
        _temperature = temp;
      }
    } catch (e) {
      _weatherError = 'Lokasi/cuaca tidak tersedia';
      _temperature = null;
    } finally {
      _weatherLoading = false;
      notifyListeners();
    }
  }
}

/// =====================================================
///                        UI
/// =====================================================

class DailyNotesApp extends StatelessWidget {
  const DailyNotesApp({super.key});

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: Colors.indigo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        final mode = app.darkMode ? ThemeMode.dark : ThemeMode.light;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Catatan Harian',
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: mode,
          home: app.isBusy
              ? const SplashScreen()
              : (app.ownerName == null
                  ? const SetupProfileScreen()
                  : const NotesHomeScreen()),
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// ---------- Setup Nama Pengguna ----------

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    await app.setOwnerName(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Harian - Profil'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: app.darkMode ? 'Mode terang' : 'Mode gelap',
            icon: Icon(
              app.darkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => app.toggleTheme(),
          )
        ],
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width =
                constraints.maxWidth > 480 ? 400.0 : constraints.maxWidth * 0.9;
            return SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Masukkan nama panggilan Anda untuk digunakan di aplikasi catatan.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Nama panggilan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Lanjut'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ---------- Home / Daftar Catatan ----------

class NotesHomeScreen extends StatelessWidget {
  const NotesHomeScreen({super.key});

  void _openEditor(BuildContext context, {Note? note}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final notes = app.notes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Harian'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: app.darkMode ? 'Mode terang' : 'Mode gelap',
            icon: Icon(
              app.darkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => app.toggleTheme(),
          ),
          IconButton(
            tooltip: 'Refresh cuaca',
            icon: const Icon(Icons.cloud_sync),
            onPressed: () => app.refreshWeather(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.note_add),
      ),
      body: Column(
        children: [
          const NotesHeader(),
          Expanded(
            child: notes.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada catatan.\nTekan tombol + untuk membuat catatan baru.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 600;
                      final padding = isWide ? 24.0 : 12.0;

                      return ListView.builder(
                        padding: EdgeInsets.all(padding),
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onTap: () => _openEditor(context, note: note),
                              title: Text(
                                note.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                note.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    context.read<AppState>().deleteNote(note),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Header berisi salam, cuaca, dan lokasi

class NotesHeader extends StatelessWidget {
  const NotesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    String weatherText;
    if (app.weatherLoading) {
      weatherText = 'Memuat cuaca...';
    } else if (app.weatherError != null) {
      weatherText = app.weatherError!;
    } else if (app.temperature != null) {
      weatherText =
          'Cuaca sekitar: ${app.temperature!.toStringAsFixed(1)}°C';
    } else {
      weatherText = 'Cuaca tidak tersedia';
    }

    final locationText = app.locationLabel ?? 'Lokasi belum tersedia';

    final name = app.ownerName ?? 'Teman';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat datang, $name',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(weatherText),
                    Text(
                      locationText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------- Editor Catatan ----------

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.note?.title ?? '');
    _bodyController = TextEditingController(text: widget.note?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    final now = DateTime.now();

    // saat menyimpan, coba ambil posisi terakhir untuk disimpan di catatan
    double? lat;
    double? lon;
    try {
      final pos = await app.locationService.getCurrentPosition();
      lat = pos.latitude;
      lon = pos.longitude;
    } catch (_) {
      // diam saja; catatan tetap disimpan tanpa koordinat
    }

    if (widget.note == null) {
      final note = Note(
        title: _titleController.text.trim().isEmpty
            ? '(Tanpa judul)'
            : _titleController.text.trim(),
        body: _bodyController.text.trim(),
        createdAt: now,
        updatedAt: now,
        latitude: lat,
        longitude: lon,
      );
      await app.addOrUpdateNote(note);
    } else {
      final updated = widget.note!.copyWith(
        title: _titleController.text.trim().isEmpty
            ? widget.note!.title
            : _titleController.text.trim(),
        body: _bodyController.text.trim(),
        updatedAt: now,
        latitude: lat ?? widget.note!.latitude,
        longitude: lon ?? widget.note!.longitude,
      );
      await app.addOrUpdateNote(updated);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Catatan' : 'Catatan Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Simpan',
            onPressed: _save,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;
          final editor = Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Judul catatan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        hintText: 'Tulis isi catatan di sini...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                ],
              ),
            ),
          );

          if (isWide) {
            return Center(
              child: editor,
            );
          } else {
            return editor;
          }
        },
      ),
    );
  }
}
