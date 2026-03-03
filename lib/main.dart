import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

// ==========================================
// COLORI & TEMA
// ==========================================
const Color kBlack      = Color(0xFF04040F);
const Color kBlue       = Color(0xFF00EAFF);
const Color kBlueDark   = Color(0xFF0055AA);
const Color kBlueDim    = Color(0xFF003366);
const Color kGold       = Color(0xFFFFD700);
const Color kPurple     = Color(0xFF9D00FF);
const Color kPurpleDim  = Color(0xFF3D0066);
const Color kGreen      = Color(0xFF00FFC8);
const Color kRed        = Color(0xFFFF3A5C);

// ==========================================
// NOTIFICHE
// ==========================================
final FlutterLocalNotificationsPlugin notifPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const settings = InitializationSettings(android: android, iOS: iOS);
  await notifPlugin.initialize(settings);
}

Future<void> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
}) async {
  await notifPlugin.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'hunter_system_channel',
        'Hunter System',
        channelDescription: 'Quest reminders',
        importance: Importance.high,
        priority: Priority.high,
        color: kBlue,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

Future<void> cancelNotification(int id) async {
  await notifPlugin.cancel(id);
}

// ==========================================
// MODELLI DATI
// ==========================================
enum QuestType { daily, gym, adventure }

class SetLog {
  final DateTime date;
  final double weight;
  final int reps;
  SetLog({required this.date, required this.weight, required this.reps});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weight': weight,
    'reps': reps,
  };
  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
    date: DateTime.parse(j['date']),
    weight: (j['weight'] as num).toDouble(),
    reps: j['reps'],
  );
}

class ExerciseBlueprint {
  final String id;
  String name;
  String muscleGroup;
  bool isCustom;

  ExerciseBlueprint({required this.id, required this.name, required this.muscleGroup, this.isCustom = false});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'muscleGroup': muscleGroup, 'isCustom': isCustom};
  factory ExerciseBlueprint.fromJson(Map<String, dynamic> j) => ExerciseBlueprint(
    id: j['id'], name: j['name'], muscleGroup: j['muscleGroup'], isCustom: j['isCustom'] ?? false,
  );
}

class GymTask {
  String id;
  String exerciseId;
  String name;
  String targetMuscle;
  int targetSets;
  int completedSets;
  double lastWeight;
  int lastReps;
  List<SetLog> history; // Storico globale di questo esercizio

  GymTask({
    required this.id,
    required this.exerciseId,
    required this.name,
    required this.targetMuscle,
    this.targetSets = 3,
    this.completedSets = 0,
    this.lastWeight = 0,
    this.lastReps = 0,
    List<SetLog>? history,
  }) : history = history ?? [];

  bool get isFinished => completedSets >= targetSets;

  // Massimo storico
  double get maxWeight => history.isEmpty ? 0 : history.map((s) => s.weight).reduce(max);

  // Ultimi N set per grafici
  List<SetLog> get recentHistory => history.length > 20 ? history.sublist(history.length - 20) : history;

  Map<String, dynamic> toJson() => {
    'id': id, 'exerciseId': exerciseId, 'name': name, 'targetMuscle': targetMuscle,
    'targetSets': targetSets, 'completedSets': completedSets,
    'lastWeight': lastWeight, 'lastReps': lastReps,
    'history': history.map((s) => s.toJson()).toList(),
  };

  factory GymTask.fromJson(Map<String, dynamic> j) => GymTask(
    id: j['id'], exerciseId: j['exerciseId'] ?? '', name: j['name'],
    targetMuscle: j['targetMuscle'], targetSets: j['targetSets'],
    completedSets: j['completedSets'], lastWeight: (j['lastWeight'] as num).toDouble(),
    lastReps: j['lastReps'],
    history: (j['history'] as List?)?.map((s) => SetLog.fromJson(s)).toList() ?? [],
  );
}

class Quest {
  String id;
  String title;
  QuestType type;
  bool isDone;
  List<GymTask> gymRoutine;
  DateTime? reminderTime;
  int? notifId;

  Quest({
    required this.id,
    required this.title,
    required this.type,
    this.isDone = false,
    List<GymTask>? gymRoutine,
    this.reminderTime,
    this.notifId,
  }) : gymRoutine = gymRoutine ?? [];

  bool get isGymComplete => gymRoutine.isNotEmpty && gymRoutine.every((t) => t.isFinished);

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'type': type.index, 'isDone': isDone,
    'gymRoutine': gymRoutine.map((t) => t.toJson()).toList(),
    'reminderTime': reminderTime?.toIso8601String(),
    'notifId': notifId,
  };

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
    id: j['id'], title: j['title'],
    type: QuestType.values[j['type']],
    isDone: j['isDone'],
    gymRoutine: (j['gymRoutine'] as List?)?.map((t) => GymTask.fromJson(t)).toList() ?? [],
    reminderTime: j['reminderTime'] != null ? DateTime.parse(j['reminderTime']) : null,
    notifId: j['notifId'],
  );
}

// ==========================================
// PROVIDER
// ==========================================
class SystemProvider extends ChangeNotifier {
  List<Quest> _quests = [];
  List<ExerciseBlueprint> _exercises = [];
  int _totalVolume = 0;
  int _notifCounter = 100;
  bool _isLoading = true;

  // Getter
  bool get isLoading => _isLoading;
  List<Quest> get quests => _quests;
  List<ExerciseBlueprint> get exercises => _exercises;
  int get totalVolume => _totalVolume;
  List<Quest> get dailyQuests => _quests.where((q) => q.type == QuestType.daily).toList();
  List<Quest> get gymQuests => _quests.where((q) => q.type == QuestType.gym).toList();
  List<Quest> get advQuests => _quests.where((q) => q.type == QuestType.adventure).toList();
  int get playerLevel => 1 + (_totalVolume ~/ 1000) + (_quests.where((q) => q.isDone || q.isGymComplete).length ~/ 3);

  // Carica dati persistenti
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Esercizi default
    final List<ExerciseBlueprint> defaultEx = [
      ExerciseBlueprint(id: 'ex1',  name: "Panca Piana",     muscleGroup: "Petto"),
      ExerciseBlueprint(id: 'ex2',  name: "Panca Inclinata", muscleGroup: "Petto"),
      ExerciseBlueprint(id: 'ex3',  name: "Croci Manubri",   muscleGroup: "Petto"),
      ExerciseBlueprint(id: 'ex4',  name: "Squat",           muscleGroup: "Gambe"),
      ExerciseBlueprint(id: 'ex5',  name: "Leg Press",       muscleGroup: "Gambe"),
      ExerciseBlueprint(id: 'ex6',  name: "Affondi",         muscleGroup: "Gambe"),
      ExerciseBlueprint(id: 'ex7',  name: "Stacchi Terra",   muscleGroup: "Schiena"),
      ExerciseBlueprint(id: 'ex8',  name: "Lat Machine",     muscleGroup: "Schiena"),
      ExerciseBlueprint(id: 'ex9',  name: "Rematore",        muscleGroup: "Schiena"),
      ExerciseBlueprint(id: 'ex10', name: "Military Press",  muscleGroup: "Spalle"),
      ExerciseBlueprint(id: 'ex11', name: "Alzate Laterali", muscleGroup: "Spalle"),
      ExerciseBlueprint(id: 'ex12', name: "Curl Bicipiti",   muscleGroup: "Braccia"),
      ExerciseBlueprint(id: 'ex13', name: "Curl Martello",   muscleGroup: "Braccia"),
      ExerciseBlueprint(id: 'ex14', name: "Pushdown",        muscleGroup: "Braccia"),
      ExerciseBlueprint(id: 'ex15', name: "Tricipiti Corpo", muscleGroup: "Braccia"),
      ExerciseBlueprint(id: 'ex16', name: "Crunch",          muscleGroup: "Core"),
      ExerciseBlueprint(id: 'ex17', name: "Plank",           muscleGroup: "Core"),
    ];

    final exJson = prefs.getString('exercises');
    if (exJson != null) {
      final List decoded = jsonDecode(exJson);
      _exercises = decoded.map((e) => ExerciseBlueprint.fromJson(e)).toList();
      // Aggiungi default mancanti
      for (var d in defaultEx) {
        if (!_exercises.any((e) => e.id == d.id)) _exercises.insert(0, d);
      }
    } else {
      _exercises = defaultEx;
    }

    final questsJson = prefs.getString('quests');
    if (questsJson != null) {
      final List decoded = jsonDecode(questsJson);
      _quests = decoded.map((q) => Quest.fromJson(q)).toList();
    }

    _totalVolume = prefs.getInt('totalVolume') ?? 0;
    _notifCounter = prefs.getInt('notifCounter') ?? 100;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quests', jsonEncode(_quests.map((q) => q.toJson()).toList()));
    await prefs.setString('exercises', jsonEncode(_exercises.map((e) => e.toJson()).toList()));
    await prefs.setInt('totalVolume', _totalVolume);
    await prefs.setInt('notifCounter', _notifCounter);
  }

  // Quest actions
  Future<void> addQuest(Quest q) async {
    _quests.add(q);
    notifyListeners();
    await _save();
  }

  Future<void> removeQuest(Quest q) async {
    if (q.notifId != null) await cancelNotification(q.notifId!);
    _quests.remove(q);
    notifyListeners();
    await _save();
  }

  Future<void> toggleDaily(Quest q) async {
    q.isDone = !q.isDone;
    notifyListeners();
    await _save();
  }

  Future<void> resetDailies() async {
    for (var q in _quests.where((q) => q.type == QuestType.daily)) {
      q.isDone = false;
    }
    notifyListeners();
    await _save();
  }

  // Gym actions
  Future<void> logSet(GymTask task, double weight, int reps) async {
    task.lastWeight = weight;
    task.lastReps = reps;
    task.completedSets += 1;
    task.history.add(SetLog(date: DateTime.now(), weight: weight, reps: reps));
    _totalVolume += (weight * reps).round();
    notifyListeners();
    await _save();
  }

  Future<void> resetGymSession(Quest quest) async {
    for (var t in quest.gymRoutine) {
      t.completedSets = 0;
    }
    notifyListeners();
    await _save();
  }

  // Esercizi custom
  Future<void> addCustomExercise(String name, String muscleGroup) async {
    final ex = ExerciseBlueprint(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      muscleGroup: muscleGroup,
      isCustom: true,
    );
    _exercises.add(ex);
    notifyListeners();
    await _save();
  }

  Future<void> deleteCustomExercise(ExerciseBlueprint ex) async {
    _exercises.remove(ex);
    notifyListeners();
    await _save();
  }

  // Notifiche
  Future<void> scheduleQuestReminder(Quest q, DateTime time) async {
    final id = _notifCounter++;
    q.reminderTime = time;
    q.notifId = id;
    await scheduleNotification(
      id: id,
      title: "⚠️ QUEST REMINDER",
      body: q.title,
      scheduledTime: time,
    );
    notifyListeners();
    await _save();
  }

  Future<void> removeReminder(Quest q) async {
    if (q.notifId != null) await cancelNotification(q.notifId!);
    q.reminderTime = null;
    q.notifId = null;
    notifyListeners();
    await _save();
  }
}

// ==========================================
// MAIN
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await initNotifications();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SystemProvider()..loadData(),
      child: const HunterApp(),
    ),
  );
}

class HunterApp extends StatelessWidget {
  const HunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hunter System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kBlack,
        primaryColor: kBlue,
        colorScheme: const ColorScheme.dark(
          primary: kBlue, secondary: kPurple, surface: Color(0xFF08081A),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'monospace', color: Colors.white),
          titleLarge: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBlueDim)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBlue)),
          labelStyle: TextStyle(color: Colors.grey),
          hintStyle: TextStyle(color: Color(0xFF333355)),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF08081A),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: kBlueDim),
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
      home: const MainScaffold(),
    );
  }
}

// ==========================================
// WIDGET COMUNI
// ==========================================

// Box glowy stile Solo Leveling
class GlowBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final double borderWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;

  const GlowBox({
    super.key,
    required this.child,
    this.color = kBlue,
    this.borderWidth = 1,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: kBlack,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.7), width: borderWidth),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, spreadRadius: 1),
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 6, spreadRadius: 0),
        ],
      ),
      child: child,
    );
  }
}

// Header della finestra di sistema
class SystemWindowHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color color;

  const SystemWindowHeader({super.key, required this.title, this.subtitle, this.color = kBlue});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5)),
            color: color.withOpacity(0.07),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.terminal, color: color, size: 16),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold,
                letterSpacing: 4, fontSize: 14, fontFamily: 'monospace',
              )),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 1)),
        ]
      ],
    );
  }
}

// Row obiettivo (usata nei dungeon)
class GoalRow extends StatelessWidget {
  final String label;
  final String status;
  final bool isDone;
  final VoidCallback? onTap;
  final Color color;

  const GoalRow({
    super.key,
    required this.label,
    required this.status,
    required this.isDone,
    this.onTap,
    this.color = kBlue,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: isDone ? Colors.grey.withOpacity(0.3) : color.withOpacity(0.3)),
          color: isDone ? Colors.white.withOpacity(0.02) : color.withOpacity(0.04),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 18, height: 18,
              decoration: BoxDecoration(
                border: Border.all(color: isDone ? Colors.grey : color),
                color: isDone ? Colors.grey.withOpacity(0.2) : Colors.transparent,
              ),
              child: isDone ? const Icon(Icons.check, size: 12, color: Colors.grey) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
              label,
              style: TextStyle(
                color: isDone ? Colors.grey : Colors.white,
                fontSize: 15,
                decoration: isDone ? TextDecoration.lineThrough : null,
                fontFamily: 'monospace',
              ),
            )),
            Text("[ $status ]", style: TextStyle(
              color: isDone ? Colors.grey : color,
              fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12,
            )),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SCAFFOLD PRINCIPALE
// ==========================================
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with TickerProviderStateMixin {
  int _index = 0;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SystemProvider>(context);
    if (prov.isLoading) {
      return Scaffold(
        backgroundColor: kBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) => Text(
                  "HUNTER SYSTEM",
                  style: TextStyle(
                    color: kBlue.withOpacity(_glowAnim.value),
                    fontSize: 22, letterSpacing: 6, fontFamily: 'monospace',
                    shadows: [Shadow(color: kBlue.withOpacity(_glowAnim.value), blurRadius: 20)],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(color: kBlue, backgroundColor: kBlueDim),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          QuestLogScreen(),
          DungeonKeysScreen(),
          StatusScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBlueDim, width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF06060F),
          selectedItemColor: kBlue,
          unselectedItemColor: Colors.grey[700],
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          selectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 1),
          unselectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: "QUESTS"),
            BottomNavigationBarItem(icon: Icon(Icons.fitness_center_outlined), activeIcon: Icon(Icons.fitness_center), label: "DUNGEON"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "STATUS"),
          ],
        ),
      ),
      floatingActionButton: _index != 2
          ? _GlowFAB(onPressed: () => _showAddMenu(context))
          : null,
    );
  }

  void _showAddMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF08081A),
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: kBlueDim),
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("// SELECT QUEST TYPE", style: TextStyle(color: kBlue, letterSpacing: 3, fontSize: 12, fontFamily: 'monospace')),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TypeButton(Icons.calendar_today, "DAILY", kGold, () {
                  Navigator.pop(context);
                  _addSimpleQuest(context, QuestType.daily);
                }),
                _TypeButton(Icons.fitness_center, "GYM", kPurple, () {
                  Navigator.pop(context);
                  Navigator.push(context, _slideRoute(const DungeonMakerScreen()));
                }),
                _TypeButton(Icons.map_outlined, "ADVENTURE", kGreen, () {
                  Navigator.pop(context);
                  _addSimpleQuest(context, QuestType.adventure);
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _addSimpleQuest(BuildContext context, QuestType type) {
    final ctrl = TextEditingController();
    final color = type == QuestType.daily ? kGold : kGreen;
    final typeName = type == QuestType.daily ? "DAILY" : "ADVENTURE";
    DateTime? reminderTime;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text("NEW $typeName QUEST", style: TextStyle(color: color, letterSpacing: 2, fontFamily: 'monospace', fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: InputDecoration(hintText: "Descrivi l'obiettivo..."),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (t != null) {
                    final now = DateTime.now();
                    var dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
                    if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
                    setDialogState(() => reminderTime = dt);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: reminderTime != null ? color : kBlueDim),
                    color: reminderTime != null ? color.withOpacity(0.08) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined, color: reminderTime != null ? color : Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        reminderTime != null
                            ? "Reminder: ${reminderTime!.hour.toString().padLeft(2,'0')}:${reminderTime!.minute.toString().padLeft(2,'0')}"
                            : "Aggiungi reminder",
                        style: TextStyle(color: reminderTime != null ? color : Colors.grey, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color, shape: const RoundedRectangleBorder()),
              onPressed: () async {
                if (ctrl.text.trim().isNotEmpty) {
                  final prov = Provider.of<SystemProvider>(context, listen: false);
                  final q = Quest(
                    id: 'q_${DateTime.now().millisecondsSinceEpoch}',
                    title: ctrl.text.trim(),
                    type: type,
                  );
                  await prov.addQuest(q);
                  if (reminderTime != null) {
                    await prov.scheduleQuestReminder(q, reminderTime!);
                  }
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text("ACCEPT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowFAB extends StatefulWidget {
  final VoidCallback onPressed;
  const _GlowFAB({required this.onPressed});
  @override
  State<_GlowFAB> createState() => _GlowFABState();
}

class _GlowFABState extends State<_GlowFAB> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _a = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, child) => Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: kBlue.withOpacity(_a.value * 0.6), blurRadius: 20, spreadRadius: 2)],
      ),
      child: FloatingActionButton(
        backgroundColor: kBlue,
        onPressed: widget.onPressed,
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    ),
  );
}

class _TypeButton extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _TypeButton(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          color: color.withOpacity(0.08),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15)],
        ),
        child: Icon(icon, color: color, size: 26),
      ),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(color: color, fontSize: 10, letterSpacing: 2, fontFamily: 'monospace')),
    ]),
  );
}

PageRoute _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
);

// ==========================================
// QUEST LOG SCREEN
// ==========================================
class QuestLogScreen extends StatelessWidget {
  const QuestLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SystemProvider>(context);
    final dailies = prov.dailyQuests;
    final adventures = prov.advQuests;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("// QUEST LOG", style: TextStyle(color: kGold, letterSpacing: 4, fontSize: 16, fontFamily: 'monospace')),
        actions: [
          if (dailies.any((q) => q.isDone))
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              tooltip: "Reset daily",
              onPressed: () => prov.resetDailies(),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (dailies.isNotEmpty) ...[
            _SectionHeader("DAILY QUESTS", kGold, "${dailies.where((q) => q.isDone).length}/${dailies.length}"),
            ...dailies.map((q) => _QuestCard(quest: q, color: kGold)),
            const SizedBox(height: 20),
          ],
          if (adventures.isNotEmpty) ...[
            _SectionHeader("ADVENTURE LOG", kGreen, "${adventures.where((q) => q.isDone).length}/${adventures.length}"),
            ...adventures.map((q) => _QuestCard(quest: q, color: kGreen)),
          ],
          if (dailies.isEmpty && adventures.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, color: Colors.grey[800], size: 48),
                    const SizedBox(height: 12),
                    Text("NO ACTIVE QUESTS", style: TextStyle(color: Colors.grey[700], letterSpacing: 3, fontFamily: 'monospace', fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title; final Color color; final String count;
  const _SectionHeader(this.title, this.color, this.count);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(width: 3, height: 16, color: color, margin: const EdgeInsets.only(right: 10)),
        Text(title, style: TextStyle(color: color, letterSpacing: 2, fontFamily: 'monospace', fontSize: 12)),
        const Spacer(),
        Text(count, style: const TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 12)),
      ],
    ),
  );
}

class _QuestCard extends StatelessWidget {
  final Quest quest; final Color color;
  const _QuestCard({required this.quest, required this.color});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SystemProvider>(context, listen: false);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: quest.isDone ? Colors.grey.withOpacity(0.2) : color.withOpacity(0.4)),
        color: quest.isDone ? Colors.white.withOpacity(0.02) : color.withOpacity(0.04),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: GestureDetector(
          onTap: () => prov.toggleDaily(quest),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 22, height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: quest.isDone ? Colors.grey : color),
              color: quest.isDone ? Colors.grey.withOpacity(0.2) : Colors.transparent,
            ),
            child: quest.isDone ? const Icon(Icons.check, size: 14, color: Colors.grey) : null,
          ),
        ),
        title: Text(
          quest.title,
          style: TextStyle(
            color: quest.isDone ? Colors.grey : Colors.white,
            decoration: quest.isDone ? TextDecoration.lineThrough : null,
            fontFamily: 'monospace',
          ),
        ),
        subtitle: quest.reminderTime != null
            ? Row(children: [
                Icon(Icons.alarm, size: 12, color: color.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(
                  "${quest.reminderTime!.hour.toString().padLeft(2,'0')}:${quest.reminderTime!.minute.toString().padLeft(2,'0')}",
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 11, fontFamily: 'monospace'),
                ),
              ])
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (quest.reminderTime != null)
              IconButton(
                icon: Icon(Icons.notifications_off_outlined, color: Colors.grey[600], size: 18),
                onPressed: () => prov.removeReminder(quest),
              ),
            IconButton(
              icon: const Icon(Icons.close, color: kRed, size: 18),
              onPressed: () => prov.removeQuest(quest),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// DUNGEON KEYS SCREEN (Lista schede)
// ==========================================
class DungeonKeysScreen extends StatelessWidget {
  const DungeonKeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SystemProvider>(context);
    final list = prov.gymQuests;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("// DUNGEON KEYS", style: TextStyle(color: kPurple, letterSpacing: 4, fontSize: 16, fontFamily: 'monospace')),
        actions: [
          IconButton(
            icon: const Icon(Icons.book_outlined, color: Colors.grey),
            tooltip: "Skill Book",
            onPressed: () => Navigator.push(context, _slideRoute(const SkillBookScreen())),
          ),
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.vpn_key_outlined, color: Colors.grey[800], size: 48),
                  const SizedBox(height: 12),
                  Text("NO DUNGEON KEYS", style: TextStyle(color: Colors.grey[700], letterSpacing: 3, fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final q = list[i];
                final done = q.gymRoutine.where((t) => t.isFinished).length;
                final total = q.gymRoutine.length;
                final isComplete = q.isGymComplete;

                return GestureDetector(
                  onTap: () => Navigator.push(ctx, _slideRoute(ActiveDungeonScreen(quest: q))),
                  onLongPress: () => _showDeleteDialog(ctx, q),
                  child: GlowBox(
                    color: isComplete ? Colors.grey : kPurple,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.vpn_key, color: isComplete ? Colors.grey : kPurple, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(q.title, style: TextStyle(
                              color: isComplete ? Colors.grey : Colors.white,
                              fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16,
                            ))),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: total > 0 ? done / total : 0,
                                  backgroundColor: kPurpleDim,
                                  color: isComplete ? Colors.grey : kPurple,
                                  minHeight: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text("$done/$total", style: const TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: q.gymRoutine.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: t.isFinished ? Colors.grey.withOpacity(0.3) : kPurple.withOpacity(0.4)),
                              color: t.isFinished ? Colors.white.withOpacity(0.02) : kPurple.withOpacity(0.06),
                            ),
                            child: Text(t.name, style: TextStyle(
                              color: t.isFinished ? Colors.grey : Colors.white,
                              fontSize: 10, fontFamily: 'monospace',
                            )),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showDeleteDialog(BuildContext ctx, Quest q) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text("DELETE KEY?", style: TextStyle(color: kRed, fontFamily: 'monospace', fontSize: 14, letterSpacing: 2)),
        content: Text("Eliminare \"${q.title}\"?", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, shape: const RoundedRectangleBorder()),
            onPressed: () {
              Provider.of<SystemProvider>(ctx, listen: false).removeQuest(q);
              Navigator.pop(ctx);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// DUNGEON MAKER
// ==========================================
class DungeonMakerScreen extends StatefulWidget {
  const DungeonMakerScreen({super.key});
  @override
  State<DungeonMakerScreen> createState() => _DungeonMakerScreenState();
}

class _DungeonMakerScreenState extends State<DungeonMakerScreen> {
  final _nameCtrl = TextEditingController();
  final List<GymTask> _selected = [];
  String _filter = "Tutti";

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SystemProvider>(context);
    final allEx = prov.exercises;
    final muscleGroups = ["Tutti", ...allEx.map((e) => e.muscleGroup).toSet().toList()..sort()];
    final visible = _filter == "Tutti" ? allEx : allEx.where((e) => e.muscleGroup == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: kPurple),
        title: const Text("CRAFT DUNGEON KEY", style: TextStyle(color: kPurple, letterSpacing: 3, fontFamily: 'monospace', fontSize: 14)),
      ),
      body: Column(
        children: [
          // Nome scheda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace'),
              decoration: const InputDecoration(hintText: "Nome scheda (es. Chest Day)"),
            ),
          ),
          // Filtro gruppi muscolari
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: muscleGroups.length,
              itemBuilder: (ctx, i) {
                final g = muscleGroups[i];
                final sel = _filter == g;
                return GestureDetector(
                  onTap: () => setState(() => _filter = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: sel ? kPurple : kBlueDim),
                      color: sel ? kPurple.withOpacity(0.15) : Colors.transparent,
                    ),
                    child: Text(g, style: TextStyle(
                      color: sel ? kPurple : Colors.grey,
                      fontFamily: 'monospace', fontSize: 12,
                    )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Lista esercizi
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (ctx, i) {
                final ex = visible[i];
                final isSelected = _selected.any((t) => t.exerciseId == ex.id);
                return ListTile(
                  leading: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(color: isSelected ? kPurple : kBlueDim),
                      color: isSelected ? kPurple.withOpacity(0.2) : Colors.transparent,
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 14, color: kPurple) : null,
                  ),
                  title: Text(ex.name, style: TextStyle(color: isSelected ? kPurple : Colors.white, fontFamily: 'monospace')),
                  subtitle: Text(ex.muscleGroup, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  trailing: ex.isCustom
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline, color: kRed, size: 16),
                          onPressed: () => prov.deleteCustomExercise(ex),
                        )
                      : null,
                  onTap: () => _toggleExercise(ex),
                );
              },
            ),
          ),
          // Selected preview
          if (_selected.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBlueDim))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SELEZIONATI: ${_selected.length}", style: const TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: _selected.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: kPurple.withOpacity(0.5)),
                        color: kPurple.withOpacity(0.08),
                      ),
                      child: Text(t.name, style: const TextStyle(color: kPurple, fontSize: 10, fontFamily: 'monospace')),
                    )).toList(),
                  ),
                ],
              ),
            ),
          // Bottoni
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, color: kBlue, size: 16),
                    label: const Text("CUSTOM", style: TextStyle(color: kBlue, fontFamily: 'monospace', fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: kBlueDim), shape: const RoundedRectangleBorder()),
                    onPressed: () => _addCustomExercise(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPurple, shape: const RoundedRectangleBorder(), padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _save,
                    child: const Text("CRAFT KEY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 2)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleExercise(ExerciseBlueprint ex) {
    if (_selected.any((t) => t.exerciseId == ex.id)) {
      setState(() => _selected.removeWhere((t) => t.exerciseId == ex.id));
    } else {
      final setsCtrl = TextEditingController(text: "4");
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ex.name, style: const TextStyle(color: kPurple, fontFamily: 'monospace', fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Serie target:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: setsCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kPurple, fontSize: 28, fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPurple, shape: const RoundedRectangleBorder()),
              onPressed: () {
                final s = int.tryParse(setsCtrl.text) ?? 4;
                setState(() => _selected.add(GymTask(
                  id: 'task_${DateTime.now().millisecondsSinceEpoch}',
                  exerciseId: ex.id, name: ex.name, targetMuscle: ex.muscleGroup, targetSets: s,
                )));
                Navigator.pop(ctx);
              },
              child: const Text("AGGIUNGI", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _addCustomExercise(BuildContext context) {
    final nameCtrl = TextEditingController();
    final muscleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("CUSTOM EXERCISE", style: TextStyle(color: kBlue, fontFamily: 'monospace', fontSize: 13, letterSpacing: 2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome esercizio")),
            const SizedBox(height: 12),
            TextField(controller: muscleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Gruppo muscolare")),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: const RoundedRectangleBorder()),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && muscleCtrl.text.isNotEmpty) {
                Provider.of<SystemProvider>(context, listen: false).addCustomExercise(nameCtrl.text, muscleCtrl.text);
                Navigator.pop(context);
              }
            },
            child: const Text("SAVE", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.isNotEmpty && _selected.isNotEmpty) {
      Provider.of<SystemProvider>(context, listen: false).addQuest(Quest(
        id: 'gym_${DateTime.now().millisecondsSinceEpoch}',
        title: _nameCtrl.text,
        type: QuestType.gym,
        gymRoutine: _selected,
      ));
      Navigator.pop(context);
    }
  }
}

// ==========================================
// ACTIVE DUNGEON SCREEN
// ==========================================
class ActiveDungeonScreen extends StatelessWidget {
  final Quest quest;
  const ActiveDungeonScreen({super.key, required this.quest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: kPurple),
        title: Text(quest.title, style: const TextStyle(color: kPurple, fontFamily: 'monospace', letterSpacing: 2, fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            tooltip: "Reset sessione",
            onPressed: () => Provider.of<SystemProvider>(context, listen: false).resetGymSession(quest),
          ),
        ],
      ),
      body: Consumer<SystemProvider>(
        builder: (ctx, prov, _) {
          final done = quest.gymRoutine.where((t) => t.isFinished).length;
          final total = quest.gymRoutine.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Progress header
              GlowBox(
                color: kPurple,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("DUNGEON PROGRESS", style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 11, letterSpacing: 2)),
                        Text("$done / $total", style: const TextStyle(color: kPurple, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: total > 0 ? done / total : 0,
                        backgroundColor: kPurpleDim,
                        color: kPurple,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),

              // Esercizi
              ...quest.gymRoutine.map((task) => _ExerciseCard(task: task, quest: quest)),

              if (quest.isGymComplete)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: GlowBox(
                    color: kGreen,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: const [
                        Icon(Icons.emoji_events, color: kGreen, size: 32),
                        SizedBox(height: 8),
                        Text("DUNGEON CLEARED!", style: TextStyle(
                          color: kGreen, letterSpacing: 4, fontFamily: 'monospace',
                          fontWeight: FontWeight.bold, fontSize: 16,
                        )),
                        SizedBox(height: 4),
                        Text("Ottimo lavoro, Hunter.", style: TextStyle(color: Colors.grey, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final GymTask task;
  final Quest quest;
  const _ExerciseCard({required this.task, required this.quest});

  @override
  Widget build(BuildContext context) {
    return GlowBox(
      color: task.isFinished ? Colors.grey : kPurple,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Header esercizio
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.name, style: TextStyle(
                        color: task.isFinished ? Colors.grey : Colors.white,
                        fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15,
                      )),
                      Text(task.targetMuscle, style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                // Serie progress
                Row(
                  children: List.generate(task.targetSets, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < task.completedSets ? kPurple : Colors.transparent,
                      border: Border.all(color: i < task.completedSets ? kPurple : kBlueDim),
                    ),
                  )),
                ),
                const SizedBox(width: 8),
                Text("${task.completedSets}/${task.targetSets}", style: const TextStyle(color: kPurple, fontFamily: 'monospace', fontSize: 12)),
              ],
            ),
          ),
          // Info ultimo set + bottoni
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBlueDim, width: 0.5))),
            child: Row(
              children: [
                if (task.lastWeight > 0)
                  Expanded(child: Text(
                    "${task.lastWeight}kg × ${task.lastReps} reps",
                    style: const TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 11),
                  ))
                else
                  const Expanded(child: Text("Nessun set registrato", style: TextStyle(color: Color(0xFF333355), fontFamily: 'monospace', fontSize: 11))),
                if (task.history.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.push(context, _slideRoute(_ExerciseHistoryScreen(task: task))),
                    child: const Text("STORICO", style: TextStyle(color: kBlue, fontFamily: 'monospace', fontSize: 10, letterSpacing: 1)),
                  ),
                if (!task.isFinished)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPurple, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () => _showLogDialog(context, task),
                    child: const Text("LOG SET", style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                if (task.isFinished)
                  const Icon(Icons.check_circle, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogDialog(BuildContext context, GymTask task) {
    HapticFeedback.selectionClick();
    final prov = Provider.of<SystemProvider>(context, listen: false);
    final wCtrl = TextEditingController(text: task.lastWeight > 0 ? "${task.lastWeight}" : "");
    final rCtrl = TextEditingController(text: task.lastReps > 0 ? "${task.lastReps}" : "");
    int countdown = 0;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("SET ${task.completedSets + 1}", style: const TextStyle(color: kPurple, fontFamily: 'monospace', letterSpacing: 2)),
                Text(task.name, style: const TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 12)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.maxWeight > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: kGold.withOpacity(0.3)), color: kGold.withOpacity(0.05)),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, color: kGold, size: 14),
                          const SizedBox(width: 6),
                          Text("Record: ${task.maxWeight}kg", style: const TextStyle(color: kGold, fontFamily: 'monospace', fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(child: TextField(
                      controller: wCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'monospace'),
                      decoration: const InputDecoration(labelText: "KG"),
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: TextField(
                      controller: rCtrl, keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'monospace'),
                      decoration: const InputDecoration(labelText: "REPS"),
                    )),
                  ],
                ),
                const SizedBox(height: 16),
                // Timer recupero
                countdown > 0
                    ? Column(
                        children: [
                          Text("RECUPERO: ${countdown}s", style: TextStyle(
                            color: countdown <= 10 ? kRed : kBlue,
                            fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold,
                          )),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: countdown / 90,
                              color: countdown <= 10 ? kRed : kBlue,
                              backgroundColor: kBlueDim,
                              minHeight: 3,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TimerBtn("60s", 60, () { setS(() => countdown = 60); _startTimer(timer, countdown, setS, ctx); }),
                          const SizedBox(width: 8),
                          _TimerBtn("90s", 90, () { setS(() => countdown = 90); _startTimer(timer, countdown, setS, ctx); }),
                          const SizedBox(width: 8),
                          _TimerBtn("120s", 120, () { setS(() => countdown = 120); _startTimer(timer, countdown, setS, ctx); }),
                        ],
                      ),
              ],
            ),
            actions: [
              TextButton(onPressed: () { timer?.cancel(); Navigator.pop(ctx); }, child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPurple, shape: const RoundedRectangleBorder()),
                onPressed: () {
                  final w = double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? 0;
                  final r = int.tryParse(rCtrl.text) ?? 0;
                  if (w >= 0 && r > 0) {
                    timer?.cancel();
                    prov.logSet(task, w, r);
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    // Avvia timer recupero esterno se non è l'ultimo set
                    if (!task.isFinished) {
                      _showRestTimer(context);
                    }
                  }
                },
                child: const Text("DONE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startTimer(Timer? timer, int seconds, StateSetter setS, BuildContext ctx) {
    timer?.cancel();
    int count = seconds;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (count <= 0) {
        t.cancel();
        HapticFeedback.heavyImpact();
      } else {
        setS(() => count--);
      }
    });
  }

  void _showRestTimer(BuildContext context) {
    int seconds = 90;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          Timer.periodic(const Duration(seconds: 1), (t) {
            if (seconds <= 0 || !ctx2.mounted) { t.cancel(); if (ctx2.mounted) Navigator.of(ctx2).pop(); return; }
            setS(() => seconds--);
          });
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("RECUPERO", style: TextStyle(color: Colors.grey, fontFamily: 'monospace', letterSpacing: 3)),
                const SizedBox(height: 12),
                Text("${seconds}s", style: TextStyle(
                  color: seconds <= 15 ? kRed : kBlue,
                  fontSize: 48, fontFamily: 'monospace', fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: seconds <= 15 ? kRed : kBlue, blurRadius: 20)],
                )),
                const SizedBox(height: 12),
                TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text("SKIP", style: TextStyle(color: Colors.grey))),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _TimerBtn(String label, int seconds, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(border: Border.all(color: kBlueDim), color: kBlue.withOpacity(0.05)),
    child: Text(label, style: const TextStyle(color: kBlue, fontFamily: 'monospace', fontSize: 11)),
  ),
);

// ==========================================
// EXERCISE HISTORY SCREEN
// ==========================================
class _ExerciseHistoryScreen extends StatelessWidget {
  final GymTask task;
  const _ExerciseHistoryScreen({required this.task});

  @override
  Widget build(BuildContext context) {
    final history = task.recentHistory.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: kBlue),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.name, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)),
            const Text("STORICO SET", style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 10, letterSpacing: 2)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Mini grafico
          if (task.history.isNotEmpty)
            GlowBox(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("PESO (kg)", style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  SizedBox(height: 80, child: _MiniChart(history: task.recentHistory)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("RECORD", style: TextStyle(color: kGold, fontFamily: 'monospace', fontSize: 10, letterSpacing: 1)),
                        Text("${task.maxWeight}kg", style: const TextStyle(color: kGold, fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text("TOTALE SET", style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 10, letterSpacing: 1)),
                        Text("${task.history.length}", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          // Lista set
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: history.length,
              itemBuilder: (ctx, i) {
                final s = history[i];
                final isRecord = s.weight == task.maxWeight;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: isRecord ? kGold.withOpacity(0.4) : kBlueDim),
                    color: isRecord ? kGold.withOpacity(0.04) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      if (isRecord) const Icon(Icons.emoji_events, color: kGold, size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        "${s.weight}kg × ${s.reps} reps",
                        style: TextStyle(color: isRecord ? kGold : Colors.white, fontFamily: 'monospace', fontSize: 14),
                      )),
                      Text(
                        "${s.date.day}/${s.date.month} ${s.date.hour.toString().padLeft(2,'0')}:${s.date.minute.toString().padLeft(2,'0')}",
                        style: const TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Grafico minimale
class _MiniChart extends StatelessWidget {
  final List<SetLog> history;
  const _MiniChart({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox();
    return CustomPaint(painter: _ChartPainter(history: history), size: const Size(double.infinity, 80));
  }
}

class _ChartPainter extends CustomPainter {
  final List<SetLog> history;
  _ChartPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final weights = history.map((s) => s.weight).toList();
    final minW = weights.reduce(min);
    final maxW = weights.reduce(max);
    final range = maxW - minW == 0 ? 1.0 : maxW - minW;

    final paint = Paint()
      ..color = kBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = kBlue.withOpacity(0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final dotPaint = Paint()..color = kBlue;

    final path = Path();
    for (int i = 0; i < history.length; i++) {
      final x = (i / (history.length - 1)) * size.width;
      final y = size.height - ((weights[i] - minW) / range) * size.height;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Punti
    for (int i = 0; i < history.length; i++) {
      final x = (i / (history.length - 1)) * size.width;
      final y = size.height - ((weights[i] - minW) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// SKILL BOOK SCREEN (lista esercizi)
// ==========================================
class SkillBookScreen extends StatelessWidget {
  const SkillBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exercises = Provider.of<SystemProvider>(context).exercises;
    final groups = exercises.map((e) => e.muscleGroup).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: kBlue),
        title: const Text("// SKILL BOOK", style: TextStyle(color: kBlue, fontFamily: 'monospace', letterSpacing: 4, fontSize: 14)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: groups.map((group) {
          final exs = exercises.where((e) => e.muscleGroup == group).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(group.toUpperCase(), kBlue, "${exs.length}"),
              ...exs.map((ex) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(border: Border.all(color: kBlueDim)),
                child: Row(
                  children: [
                    Container(width: 3, height: 16, color: ex.isCustom ? kGreen : kBlue, margin: const EdgeInsets.only(right: 10)),
                    Expanded(child: Text(ex.name, style: TextStyle(
                      color: ex.isCustom ? kGreen : Colors.white, fontFamily: 'monospace',
                    ))),
                    if (ex.isCustom)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: kGreen.withOpacity(0.4))),
                        child: const Text("CUSTOM", style: TextStyle(color: kGreen, fontSize: 9, fontFamily: 'monospace', letterSpacing: 1)),
                      ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ==========================================
// STATUS SCREEN
// ==========================================
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});
  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SystemProvider>(context);
    final lvl = prov.playerLevel;
    final totalQuests = prov.quests.length;
    final completedQ = prov.quests.where((q) => q.isDone || q.isGymComplete).length;
    final gymSessions = prov.gymQuests.where((q) => q.isGymComplete).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("// STATUS WINDOW", style: TextStyle(color: kBlue, letterSpacing: 4, fontFamily: 'monospace', fontSize: 14)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Level display
            AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => GlowBox(
                color: kBlue,
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text("HUNTER LEVEL", style: TextStyle(color: kBlue.withOpacity(_glow.value), letterSpacing: 4, fontFamily: 'monospace', fontSize: 12)),
                    const SizedBox(height: 8),
                    Text("$lvl", style: TextStyle(
                      color: kBlue,
                      fontSize: 72, fontFamily: 'monospace', fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: kBlue.withOpacity(_glow.value), blurRadius: 30),
                        Shadow(color: kBlue.withOpacity(_glow.value * 0.5), blurRadius: 60),
                      ],
                    )),
                    const SizedBox(height: 4),
                    Text("SHADOW MONARCH", style: TextStyle(color: Colors.grey.withOpacity(_glow.value), letterSpacing: 3, fontFamily: 'monospace', fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Stats grid
            Row(
              children: [
                Expanded(child: _StatCard("VOLUME TOTALE", "${prov.totalVolume}kg", kPurple, Icons.fitness_center)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard("DUNGEON CLEARED", "$gymSessions", kGreen, Icons.vpn_key)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard("QUEST COMPLETE", "$completedQ", kGold, Icons.check_circle_outline)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard("QUEST TOTALI", "$totalQuests", kBlue, Icons.list_alt)),
              ],
            ),
            const SizedBox(height: 20),
            // Prossimo livello
            GlowBox(
              color: kBlueDim,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("NEXT LEVEL", style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  _xpBar(prov),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _xpBar(SystemProvider prov) {
    final volProgress = (prov.totalVolume % 1000) / 1000;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Volume XP", style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 11)),
            Text("${prov.totalVolume % 1000}/1000kg", style: const TextStyle(color: kBlue, fontFamily: 'monospace', fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: volProgress, color: kBlue, backgroundColor: kBlueDim, minHeight: 6),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label; final String value; final Color color; final IconData icon;
  const _StatCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => GlowBox(
    color: color,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 9, letterSpacing: 1))),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.bold,
          shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 10)],
        )),
      ],
    ),
  );
}