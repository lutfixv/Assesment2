import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

/// Key untuk SharedPreferences
const String kPrefsXp = 'habithero_xp';
const String kPrefsGold = 'habithero_gold';
const String kPrefsHp = 'habithero_hp';
const String kPrefsFilter = 'habithero_filter';
const String kPrefsThemeDark = 'habithero_theme_dark';
const String kPrefsUserName = 'habithero_user_name';

/// Tipe task (habitica-style)
enum TaskType { habit, daily, todo }

/// Tingkat kesulitan task
enum Difficulty { easy, medium, hard }

/// Filter tampilan daftar
enum TaskFilter { all, habit, daily, todo }

/// Model task yang disimpan di SQLite & dipakai di UI
class TodoTask {
  final int? id;
  final String title;
  final TaskType type;
  final Difficulty difficulty;
  final bool isDone;

  TodoTask({
    this.id,
    required this.title,
    required this.type,
    required this.difficulty,
    this.isDone = false,
  });

  TodoTask copyWith({
    int? id,
    String? title,
    TaskType? type,
    Difficulty? difficulty,
    bool? isDone,
  }) {
    return TodoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.index,
      'difficulty': difficulty.index,
      'is_done': isDone ? 1 : 0,
    };
  }

  factory TodoTask.fromMap(Map<String, dynamic> map) {
    int typeIndex = (map['type'] as int? ?? 0);
    int diffIndex = (map['difficulty'] as int? ?? 0);

    return TodoTask(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      type: TaskType.values[
          typeIndex.clamp(0, TaskType.values.length - 1)],
      difficulty: Difficulty.values[
          diffIndex.clamp(0, Difficulty.values.length - 1)],
      isDone: (map['is_done'] as int? ?? 0) == 1,
    );
  }
}

/// Item di Shop
class ShopItem {
  final String name;
  final String description;
  final int price;
  final int hpRestore;

  ShopItem({
    required this.name,
    required this.description,
    required this.price,
    required this.hpRestore,
  });
}

/// Helper SQLite untuk tabel tasks
class TaskDatabase {
  TaskDatabase._internal();
  static final TaskDatabase instance = TaskDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'habit_hero.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            type INTEGER NOT NULL,
            difficulty INTEGER NOT NULL,
            is_done INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<List<TodoTask>> getAllTasks() async {
    final db = await database;
    final maps = await db.query('tasks', orderBy: 'id ASC');
    return maps.map((m) => TodoTask.fromMap(m)).toList();
  }

  Future<int> insertTask(TodoTask task) async {
    final db = await database;
    final data = task.toMap();
    data.remove('id'); // id auto increment
    return db.insert('tasks', data);
  }

  Future<int> updateTask(TodoTask task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HabitHeroApp());
}

/// Root app: pegang ThemeMode dan status login
class HabitHeroApp extends StatefulWidget {
  const HabitHeroApp({super.key});

  @override
  State<HabitHeroApp> createState() => _HabitHeroAppState();
}

class _HabitHeroAppState extends State<HabitHeroApp> {
  ThemeMode _themeMode = ThemeMode.light;
  String? _userName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialPrefs();
  }

  Future<void> _loadInitialPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(kPrefsThemeDark) ?? false;
    final user = prefs.getString(kPrefsUserName);

    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _userName = user;
      _isLoading = false;
    });
  }

  Future<void> _setThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefsThemeDark, isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _handleLogin(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsUserName, userName);
    setState(() {
      _userName = userName;
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrefsUserName);
    setState(() {
      _userName = null;
    });
  }

  ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: Colors.deepPurple,
    );
    return base;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Habit Hero',
        themeMode: _themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isDark = _themeMode == ThemeMode.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Habit Hero',
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: _userName == null
          ? LoginPage(
              isDarkMode: isDark,
              onToggleTheme: () => _setThemeMode(!isDark),
              onLogin: _handleLogin,
            )
          : HabitHomePage(
              userName: _userName!,
              isDarkMode: isDark,
              onToggleTheme: () => _setThemeMode(!isDark),
              onLogout: () {
                _handleLogout();
              },
            ),
    );
  }
}

/// Halaman Login
class LoginPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Future<void> Function(String userName) onLogin;

  const LoginPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogin,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    await widget.onLogin(_nameController.text.trim());

    if (!mounted) return;
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Hero - Login'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: widget.isDarkMode
                ? 'Switch to Light'
                : 'Switch to Dark',
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selamat datang di Habit Hero',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama pengguna',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Masuk'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Halaman utama Habit Hero (habitica-style todo)
class HabitHomePage extends StatefulWidget {
  final String userName;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  const HabitHomePage({
    super.key,
    required this.userName,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogout,
  });

  @override
  State<HabitHomePage> createState() => _HabitHomePageState();
}

class _HabitHomePageState extends State<HabitHomePage> {
  final List<TodoTask> _tasks = [];
  int _totalXp = 0;
  int _gold = 0;
  int _hp = 100;
  TaskFilter _filter = TaskFilter.all;
  bool _isLoading = true;

  List<ShopItem> get _shopItems => [
        ShopItem(
          name: 'Potion Kecil',
          description: 'Pulihkan 15 HP.',
          price: 20,
          hpRestore: 15,
        ),
        ShopItem(
          name: 'Potion Sedang',
          description: 'Pulihkan 35 HP.',
          price: 40,
          hpRestore: 35,
        ),
        ShopItem(
          name: 'Potion Besar',
          description: 'Pulihkan hingga HP penuh.',
          price: 75,
          hpRestore: 999,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
  try {
    await _loadStatsFromPrefs();

    // Kalau lagi di web, skip SQLite (sqflite tidak support web)
    if (kIsWeb) {
      // isi seed in-memory saja
      _tasks
        ..clear()
        ..addAll([
          TodoTask(
            id: 1,
            title: 'Belajar Flutter 30 menit',
            type: TaskType.daily,
            difficulty: Difficulty.medium,
          ),
          TodoTask(
            id: 2,
            title: 'Minum air putih',
            type: TaskType.habit,
            difficulty: Difficulty.easy,
          ),
          TodoTask(
            id: 3,
            title: 'Rapikan meja belajar',
            type: TaskType.todo,
            difficulty: Difficulty.easy,
          ),
        ]);
    } else {
      // Platform mobile/desktop yang support sqflite
      await _loadTasksFromDb();

      // Kalau DB kosong, isi default seed sekali
      if (_tasks.isEmpty) {
        await _seedDefaultTasks();
        await _loadTasksFromDb();
      }
    }
  } catch (e, st) {
    // Supaya kelihatan kalau ada error
    debugPrint('ERROR _initData: $e');
    debugPrint('$st');
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  Future<void> _loadStatsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _totalXp = prefs.getInt(kPrefsXp) ?? 0;
    _gold = prefs.getInt(kPrefsGold) ?? 0;
    _hp = prefs.getInt(kPrefsHp) ?? 100;

    final filterIndex = prefs.getInt(kPrefsFilter);
    if (filterIndex != null &&
        filterIndex >= 0 &&
        filterIndex < TaskFilter.values.length) {
      _filter = TaskFilter.values[filterIndex];
    }
  }

  Future<void> _saveStatsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefsXp, _totalXp);
    await prefs.setInt(kPrefsGold, _gold);
    await prefs.setInt(kPrefsHp, _hp);
    await prefs.setInt(kPrefsFilter, _filter.index);
  }

  Future<void> _loadTasksFromDb() async {
    final loaded = await TaskDatabase.instance.getAllTasks();
    setState(() {
      _tasks
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _seedDefaultTasks() async {
    final db = TaskDatabase.instance;
    await db.insertTask(
      TodoTask(
        title: 'Belajar Flutter 30 menit',
        type: TaskType.daily,
        difficulty: Difficulty.medium,
      ),
    );
    await db.insertTask(
      TodoTask(
        title: 'Minum air putih',
        type: TaskType.habit,
        difficulty: Difficulty.easy,
      ),
    );
    await db.insertTask(
      TodoTask(
        title: 'Rapikan meja belajar',
        type: TaskType.todo,
        difficulty: Difficulty.easy,
      ),
    );
  }

  int _xpReward(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 5;
      case Difficulty.medium:
        return 10;
      case Difficulty.hard:
        return 20;
    }
  }

  int _goldReward(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 5;
      case Difficulty.medium:
        return 10;
      case Difficulty.hard:
        return 15;
    }
  }

  int _hpPenalty(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 5;
      case Difficulty.medium:
        return 10;
      case Difficulty.hard:
        return 15;
    }
  }

  void _changeFilter(TaskFilter filter) async {
    setState(() {
      _filter = filter;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefsFilter, filter.index);
  }

  List<TodoTask> get _visibleTasks {
    switch (_filter) {
      case TaskFilter.habit:
        return _tasks.where((t) => t.type == TaskType.habit).toList();
      case TaskFilter.daily:
        return _tasks.where((t) => t.type == TaskType.daily).toList();
      case TaskFilter.todo:
        return _tasks.where((t) => t.type == TaskType.todo).toList();
      case TaskFilter.all:
      default:
        return _tasks;
    }
  }

  Future<void> _addTask(
    String title,
    TaskType type,
    Difficulty difficulty,
  ) async {
    if (title.trim().isEmpty) return;
    final newTask = TodoTask(
      title: title.trim(),
      type: type,
      difficulty: difficulty,
    );

    final id = await TaskDatabase.instance.insertTask(newTask);
    final withId = newTask.copyWith(id: id);

    setState(() {
      _tasks.add(withId);
    });
  }

  Future<void> _deleteTask(int index) async {
    final task = _visibleTasks[index];
    final realIndex =
        _tasks.indexWhere((t) => t.id == task.id);

    if (realIndex == -1) return;

    setState(() {
      _tasks.removeAt(realIndex);
    });

    if (task.id != null) {
      await TaskDatabase.instance.deleteTask(task.id!);
    }
  }

  Future<void> _toggleTaskDone(int index) async {
    final visibleTask = _visibleTasks[index];
    final realIndex =
        _tasks.indexWhere((t) => t.id == visibleTask.id);
    if (realIndex == -1) return;

    late TodoTask updated;

    setState(() {
      final current = _tasks[realIndex];
      if (current.isDone) {
        // batalkan task yang sudah selesai
        _totalXp -= _xpReward(current.difficulty);
        _gold -= _goldReward(current.difficulty);
        if (_totalXp < 0) _totalXp = 0;
        if (_gold < 0) _gold = 0;
        updated = current.copyWith(isDone: false);
      } else {
        // selesaikan task
        _totalXp += _xpReward(current.difficulty);
        _gold += _goldReward(current.difficulty);
        updated = current.copyWith(isDone: true);
      }
      _tasks[realIndex] = updated;
    });

    if (updated.id != null) {
      await TaskDatabase.instance.updateTask(updated);
    }
    await _saveStatsToPrefs();
  }

  Future<void> _applyHabitPositive(TodoTask task) async {
    setState(() {
      _totalXp += _xpReward(task.difficulty);
      _gold += _goldReward(task.difficulty);
      _hp += 2;
      if (_hp > 100) _hp = 100;
    });
    await _saveStatsToPrefs();
  }

  Future<void> _applyHabitNegative(TodoTask task) async {
    setState(() {
      _hp -= _hpPenalty(task.difficulty);
      if (_hp < 0) _hp = 0;
    });
    await _saveStatsToPrefs();
  }

  Future<void> _endDayAndResetDailies() async {
    int undone = 0;
    int totalPenalty = 0;
    final List<TodoTask> updatedDailies = [];

    setState(() {
      for (final t in _tasks) {
        if (t.type == TaskType.daily && !t.isDone) {
          undone++;
          totalPenalty += _hpPenalty(t.difficulty);
        }
      }

      _hp -= totalPenalty;
      if (_hp < 0) _hp = 0;

      for (int i = 0; i < _tasks.length; i++) {
        final t = _tasks[i];
        if (t.type == TaskType.daily) {
          final reset = t.copyWith(isDone: false);
          _tasks[i] = reset;
          updatedDailies.add(reset);
        }
      }
    });

    for (final t in updatedDailies) {
      if (t.id != null) {
        await TaskDatabase.instance.updateTask(t);
      }
    }
    await _saveStatsToPrefs();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hari berakhir'),
          content: Text(
            undone == 0
                ? 'Keren! Semua daily kamu selesai hari ini 🎉'
                : 'Ada $undone daily yang belum dikerjakan.\n'
                  'Kamu kehilangan $totalPenalty HP.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _confirmEndDay() {
    int undone = 0;
    int totalPenalty = 0;

    for (final t in _tasks) {
      if (t.type == TaskType.daily && !t.isDone) {
        undone++;
        totalPenalty += _hpPenalty(t.difficulty);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Akhiri Hari?'),
          content: Text(
            undone == 0
                ? 'Semua daily sudah selesai. Akhiri hari dan reset daily untuk besok?'
                : 'Ada $undone daily yang belum selesai.\n'
                  'HP kamu akan berkurang $totalPenalty.\n\n'
                  'Tetap akhiri hari dan reset daily?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _endDayAndResetDailies();
              },
              child: const Text('Akhiri Hari'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddTaskDialog() async {
    final titleController = TextEditingController();
    TaskType selectedType = TaskType.todo;
    Difficulty selectedDifficulty = Difficulty.medium;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Task',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Tipe: '),
                    const SizedBox(width: 8),
                    DropdownButton<TaskType>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(
                          value: TaskType.habit,
                          child: Text('Habit'),
                        ),
                        DropdownMenuItem(
                          value: TaskType.daily,
                          child: Text('Daily'),
                        ),
                        DropdownMenuItem(
                          value: TaskType.todo,
                          child: Text('To-Do'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedType = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Kesulitan: '),
                    const SizedBox(width: 8),
                    DropdownButton<Difficulty>(
                      value: selectedDifficulty,
                      items: const [
                        DropdownMenuItem(
                          value: Difficulty.easy,
                          child: Text('Mudah'),
                        ),
                        DropdownMenuItem(
                          value: Difficulty.medium,
                          child: Text('Sedang'),
                        ),
                        DropdownMenuItem(
                          value: Difficulty.hard,
                          child: Text('Sulit'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedDifficulty = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _addTask(
                  titleController.text,
                  selectedType,
                  selectedDifficulty,
                );
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showShopDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined),
                    const SizedBox(width: 8),
                    const Text(
                      'Shop',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Image.asset(
                      'assets/gold.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 4),
                    Text('$_gold'),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _shopItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _shopItems[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.local_drink),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.description}\nHarga: ${item.price} Gold',
                          ),
                          isThreeLine: true,
                          trailing: ElevatedButton(
                            onPressed: _gold >= item.price && _hp < 100
                                ? () async {
                                    setState(() {
                                      _gold -= item.price;
                                      _hp += item.hpRestore;
                                      if (_hp > 100) _hp = 100;
                                    });
                                    await _saveStatsToPrefs();
                                  }
                                : null,
                            child: const Text('Beli'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hp >= 100
                      ? 'HP sudah penuh. Tidak perlu potion untuk sekarang.'
                      : 'Gunakan gold untuk membeli potion dan memulihkan HP.',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(TaskFilter filter, String label) {
    final isSelected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _changeFilter(filter),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final expToNextLevel = 100;
    final currentLevel = (_totalXp ~/ 100) + 1;
    final levelProgress =
        ((_totalXp % expToNextLevel) / expToNextLevel).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/avatar.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Habit Hero',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Halo, ${widget.userName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'LV $currentLevel',
                        style: TextStyle(
                          color:
                              theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/gold.png',
                          width: 18,
                          height: 18,
                        ),
                        const SizedBox(width: 4),
                        Text('$_gold'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/hp.png',
                          width: 18,
                          height: 18,
                        ),
                        const SizedBox(width: 4),
                        Text('HP: $_hp'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'XP ke Level berikutnya (${_totalXp % expToNextLevel} / $expToNextLevel)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: levelProgress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(
    int index,
    TodoTask task,
  ) {
    Color typeColor;
    IconData leadingIcon;

    switch (task.type) {
      case TaskType.habit:
        typeColor = Colors.blueAccent;
        leadingIcon = Icons.repeat;
        break;
      case TaskType.daily:
        typeColor = Colors.orangeAccent;
        leadingIcon = Icons.calendar_today;
        break;
      case TaskType.todo:
        typeColor = Colors.green;
        leadingIcon = Icons.check_box_outlined;
        break;
    }

    final difficultyLabel = switch (task.difficulty) {
      Difficulty.easy => 'Mudah',
      Difficulty.medium => 'Sedang',
      Difficulty.hard => 'Sulit',
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.15),
          child: Icon(
            leadingIcon,
            color: typeColor,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration:
                task.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('$difficultyLabel • ${task.type.name}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.type == TaskType.habit) ...[
              IconButton(
                tooltip: 'Habit positif',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _applyHabitPositive(task),
              ),
              IconButton(
                tooltip: 'Habit negatif',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _applyHabitNegative(task),
              ),
            ] else ...[
              IconButton(
                icon: Icon(
                  task.isDone
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: task.isDone ? Colors.green : null,
                ),
                onPressed: () => _toggleTaskDone(index),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteTask(index),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTasks = _visibleTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Hero'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: widget.isDarkMode
                ? 'Switch to Light'
                : 'Switch to Dark',
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: 'Shop',
            icon: const Icon(Icons.storefront),
            onPressed: _showShopDialog,
          ),
          IconButton(
            tooltip: 'Akhiri Hari',
            icon: const Icon(Icons.nights_stay),
            onPressed: _confirmEndDay,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(context),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(TaskFilter.all, 'Semua'),
                      _buildFilterChip(TaskFilter.habit, 'Habit'),
                      _buildFilterChip(TaskFilter.daily, 'Daily'),
                      _buildFilterChip(TaskFilter.todo, 'To-Do'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visibleTasks.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada task.\nTambahkan task baru dengan tombol +.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: visibleTasks.length,
                          itemBuilder: (context, index) {
                            final task = visibleTasks[index];
                            return _buildTaskTile(index, task);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
