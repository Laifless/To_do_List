import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ==========================================
// 1. CONFIGURAZIONE COLORI & TEMA (SYSTEM)
// ==========================================
const Color kSystemBlack = Color(0xFF050510); // Nero profondo bluastro
const Color kSystemBlue = Color(0xFF00EAFF);  // Ciano Elettrico (Glow principale)
const Color kSystemDarkBlue = Color(0xFF0055AA); // Blu scuro per sfondi secondari
const Color kGold = Color(0xFFFFD700);        // Per Daily Quests
const Color kPurple = Color(0xFF9D00FF);      // Per Dungeon/Gym
const Color kGreen = Color(0xFF00FFC8);       // Per Adventure

// ==========================================
// 2. MODELLI DI DATI
// ==========================================

enum QuestType { daily, gym, adventure }

// Un singolo esercizio nel database
class ExerciseBlueprint {
  final String name;
  final String muscleGroup;
  ExerciseBlueprint(this.name, this.muscleGroup);
}

// Un esercizio attivo dentro una scheda (Dungeon)
class GymTask {
  String name;
  String targetMuscle;
  int targetSets;      // Quante serie devi fare (es: 4)
  int completedSets;   // Quante ne hai fatte (es: 1)
  
  // Storico veloce dell'ultimo set fatto per display
  int lastWeight;
  int lastReps;

  GymTask({
    required this.name,
    required this.targetMuscle,
    this.targetSets = 3,
    this.completedSets = 0,
    this.lastWeight = 0,
    this.lastReps = 0,
  });

  bool get isFinished => completedSets >= targetSets;
}

class Quest {
  String title;
  QuestType type;
  bool isDone;         // Per Daily/Adv
  List<GymTask> gymRoutine; // Per Gym

  Quest({
    required this.title,
    required this.type,
    this.isDone = false,
    this.gymRoutine = const [],
  });
}

// ==========================================
// 3. PROVIDER (LOGICA DEL SISTEMA)
// ==========================================
class SystemProvider extends ChangeNotifier {
  final List<Quest> _quests = [];
  
  // Database Iniziale Esercizi
  final List<ExerciseBlueprint> _skillBook = [
    ExerciseBlueprint("Panca Piana", "Chest"),
    ExerciseBlueprint("Spinte Manubri", "Chest"),
    ExerciseBlueprint("Squat", "Legs"),
    ExerciseBlueprint("Leg Press", "Legs"),
    ExerciseBlueprint("Stacchi Terra", "Back"),
    ExerciseBlueprint("Lat Machine", "Back"),
    ExerciseBlueprint("Military Press", "Shoulders"),
    ExerciseBlueprint("Curl Bicipiti", "Arms"),
    ExerciseBlueprint("Pushdown", "Arms"),
    ExerciseBlueprint("Crunch", "Core"),
  ];

  // Getters
  List<Quest> get quests => _quests;
  List<ExerciseBlueprint> get skillBook => _skillBook;
  
  List<Quest> get dailyQuests => _quests.where((q) => q.type == QuestType.daily).toList();
  List<Quest> get gymQuests => _quests.where((q) => q.type == QuestType.gym).toList();
  List<Quest> get advQuests => _quests.where((q) => q.type == QuestType.adventure).toList();

  // Statistiche Player
  int _totalVolume = 0; // Kg totali sollevati
  int get playerLevel => 1 + (_totalVolume ~/ 500) + (_quests.where((q)=>q.isDone).length ~/ 5);
  
  // Azioni
  void addQuest(Quest q) {
    _quests.add(q);
    notifyListeners();
  }

  void removeQuest(Quest q) {
    _quests.remove(q);
    notifyListeners();
  }

  void toggleDaily(Quest q) {
    q.isDone = !q.isDone;
    notifyListeners();
  }

  // Logica Palestra
  void logSet(GymTask task, int weight, int reps) {
    task.lastWeight = weight;
    task.lastReps = reps;
    task.completedSets += 1;
    _totalVolume += (weight * reps); // Aumenta XP
    notifyListeners();
  }
}

// ==========================================
// 4. MAIN APP & TEMA
// ==========================================
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SystemProvider(),
      child: const SoloLevelingApp(),
    ),
  );
}

class SoloLevelingApp extends StatelessWidget {
  const SoloLevelingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hunter System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: kSystemBlue,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Courier', color: Colors.white), // Font Monospaziato stile Terminale
          titleLarge: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: kSystemBlue,
          secondary: kPurple,
          surface: kSystemBlack,
        ),
      ),
      home: const SystemScaffold(),
    );
  }
}

// ==========================================
// 5. WIDGET PERSONALIZZATO "SYSTEM WINDOW"
// ==========================================
// Questo crea l'effetto grafico dell'immagine che hai mandato
class HunterSystemWindow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  const HunterSystemWindow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kSystemBlack.withOpacity(0.9), // Sfondo semitrasparente
        border: Border.all(color: kSystemBlue.withOpacity(0.8), width: 1.5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: kSystemBlue.withOpacity(0.2), blurRadius: 15, spreadRadius: 1), // Bagliore esterno
          BoxShadow(color: kSystemBlue.withOpacity(0.1), blurRadius: 10, spreadRadius: 0, offset: const Offset(0, 0)), // Bagliore interno
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          // --- HEADER ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: kSystemBlue.withOpacity(0.4)),
              color: kSystemBlue.withOpacity(0.05),
              boxShadow: [BoxShadow(color: kSystemBlue.withOpacity(0.1), blurRadius: 10)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: kSystemBlue, size: 18),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          
          const SizedBox(height: 20),
          const Text("GOALS", style: TextStyle(color: kSystemBlue, letterSpacing: 2, fontSize: 14)),
          const SizedBox(height: 10),

          // --- CONTENUTO DINAMICO ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
            child: child,
          ),

          // --- FOOTER ---
          if (footer != null) ...[
            const Divider(color: kSystemDarkBlue),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: footer!,
            )
          ] else const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Widget per la riga singola (Es: [ Panca Piana ] ... [ 1/3 ])
class SystemGoalRow extends StatelessWidget {
  final String label;
  final String statusText; 
  final bool isDone;
  final VoidCallback? onTap;

  const SystemGoalRow({super.key, required this.label, required this.statusText, required this.isDone, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        color: Colors.transparent, // Per captare il tap
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label, 
                style: TextStyle(
                  color: isDone ? Colors.grey : Colors.white, 
                  fontSize: 16,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Row(
              children: [
                Text("[ $statusText ]", style: const TextStyle(color: kSystemBlue, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: isDone ? Colors.grey : kSystemBlue),
                    color: isDone ? Colors.grey.withOpacity(0.2) : null,
                  ),
                  child: isDone ? const Icon(Icons.check, size: 14, color: Colors.grey) : null,
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. SCHERMATE PRINCIPALI
// ==========================================

class SystemScaffold extends StatefulWidget {
  const SystemScaffold({super.key});
  @override
  State<SystemScaffold> createState() => _SystemScaffoldState();
}

class _SystemScaffoldState extends State<SystemScaffold> {
  int _index = 0;
  final List<Widget> _pages = [
    const QuestLogScreen(),     // Daily & Adventure
    const DungeonKeysScreen(),  // Lista Schede Palestra
    const StatusWindowScreen(), // Stats
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: kSystemBlue,
        unselectedItemColor: Colors.grey[800],
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "QUESTS"),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: "DUNGEON"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "STATUS"),
        ],
      ),
      floatingActionButton: _index != 2 
        ? FloatingActionButton(
            backgroundColor: kSystemBlue,
            child: const Icon(Icons.add, color: Colors.black),
            onPressed: () => _showAddMenu(context),
          )
        : null,
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSystemBlack,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("SELECT QUEST TYPE", style: TextStyle(color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickBtn(Icons.calendar_today, "DAILY", kGold, () {
                  Navigator.pop(context);
                  _addSimpleQuest(context, QuestType.daily);
                }),
                _QuickBtn(Icons.fitness_center, "GYM", kPurple, () {
                  Navigator.pop(context);
                  // Apre il Builder della Scheda
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DungeonMakerScreen()));
                }),
                _QuickBtn(Icons.map, "ADVENTURE", kGreen, () {
                  Navigator.pop(context);
                  _addSimpleQuest(context, QuestType.adventure);
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _addSimpleQuest(BuildContext context, QuestType type) {
    final ctrl = TextEditingController();
    final color = type == QuestType.daily ? kGold : kGreen;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSystemBlack,
        shape: RoundedRectangleBorder(side: BorderSide(color: color)),
        title: Text("NEW QUEST", style: TextStyle(color: color)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: "Objective...", hintStyle: TextStyle(color: Colors.grey[700])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                Provider.of<SystemProvider>(context, listen: false).addQuest(Quest(title: ctrl.text, type: type));
                Navigator.pop(context);
              }
            },
            child: const Text("ACCEPT", style: TextStyle(color: Colors.black)),
          )
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon; final String lbl; final Color col; final VoidCallback act;
  const _QuickBtn(this.icon, this.lbl, this.col, this.act);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: act,
      child: Column(children: [
        CircleAvatar(radius: 30, backgroundColor: Colors.transparent, foregroundImage: null, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: col, width: 2)), padding: const EdgeInsets.all(15), child: Icon(icon, color: col))),
        const SizedBox(height: 8),
        Text(lbl, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold))
      ]),
    );
  }
}

// ==========================================
// 7. DUNGEON MAKER (CREAZIONE SCHEDA)
// ==========================================
class DungeonMakerScreen extends StatefulWidget {
  const DungeonMakerScreen({super.key});
  @override
  State<DungeonMakerScreen> createState() => _DungeonMakerScreenState();
}

class _DungeonMakerScreenState extends State<DungeonMakerScreen> {
  final _nameCtrl = TextEditingController();
  final List<GymTask> _selectedTasks = [];
  String _filter = "All";

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SystemProvider>(context);
    final allEx = provider.skillBook;
    final visibleEx = _filter == "All" ? allEx : allEx.where((e)=>e.muscleGroup == _filter).toList();
    final filters = ["All", ...allEx.map((e)=>e.muscleGroup).toSet()];

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("CREATE DUNGEON KEY", style: TextStyle(color: kPurple))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(hintText: "Routine Name (e.g. Chest Day)", hintStyle: TextStyle(color: Colors.grey)),
            ),
          ),
          SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, children: filters.map((f) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (v)=>setState(()=>_filter=f), selectedColor: kPurple, backgroundColor: kSystemBlack, labelStyle: TextStyle(color: _filter==f?Colors.white:Colors.grey)))).toList())),
          Expanded(
            child: ListView.builder(
              itemCount: visibleEx.length,
              itemBuilder: (ctx, i) {
                final ex = visibleEx[i];
                final isSel = _selectedTasks.any((t) => t.name == ex.name);
                return ListTile(
                  title: Text(ex.name, style: TextStyle(color: isSel ? kPurple : Colors.white)),
                  subtitle: Text(ex.muscleGroup, style: const TextStyle(color: Colors.grey)),
                  trailing: isSel ? const Icon(Icons.check, color: kPurple) : const Icon(Icons.add, color: Colors.grey),
                  onTap: () => _toggleExercise(ex),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: kPurple), onPressed: _saveDungeon, child: const Text("CRAFT KEY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          )
        ],
      ),
    );
  }

  void _toggleExercise(ExerciseBlueprint ex) {
    if (_selectedTasks.any((t) => t.name == ex.name)) {
      setState(() => _selectedTasks.removeWhere((t) => t.name == ex.name));
    } else {
      // CHIEDI IL NUMERO DI SERIE
      final setsCtrl = TextEditingController(text: "3");
      showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: kSystemBlack,
        shape: const RoundedRectangleBorder(side: BorderSide(color: kPurple)),
        title: Text(ex.name, style: const TextStyle(color: kPurple)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Target Sets:", style: TextStyle(color: Colors.white)),
          TextField(controller: setsCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: kPurple, fontSize: 24)),
        ]),
        actions: [
          TextButton(onPressed: (){
            int s = int.tryParse(setsCtrl.text) ?? 3;
            setState(() => _selectedTasks.add(GymTask(name: ex.name, targetMuscle: ex.muscleGroup, targetSets: s)));
            Navigator.pop(ctx);
          }, child: const Text("ADD"))
        ],
      ));
    }
  }

  void _saveDungeon() {
    if (_nameCtrl.text.isNotEmpty && _selectedTasks.isNotEmpty) {
      Provider.of<SystemProvider>(context, listen: false).addQuest(Quest(title: _nameCtrl.text, type: QuestType.gym, gymRoutine: _selectedTasks));
      Navigator.pop(context);
    }
  }
}

// ==========================================
// 8. ACTIVE DUNGEON (ALLENAMENTO)
// ==========================================
class ActiveDungeonScreen extends StatelessWidget {
  final Quest quest;
  const ActiveDungeonScreen({super.key, required this.quest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // IL WIDGET GRAFICO RICHIESTO
            HunterSystemWindow(
              title: "QUEST INFO",
              subtitle: "[ Dungeon: ${quest.title} ]",
              footer: const Center(child: Text("BONUS OBJECTIVES: SURVIVE", style: TextStyle(color: kSystemBlue, letterSpacing: 2))),
              child: Consumer<SystemProvider>(
                builder: (ctx, provider, _) {
                  return Column(
                    children: quest.gymRoutine.map((task) {
                      return SystemGoalRow(
                        label: task.name,
                        statusText: "${task.completedSets} / ${task.targetSets}",
                        isDone: task.isFinished,
                        onTap: () {
                          if (!task.isFinished) _showLogSetDialog(context, task, provider);
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogSetDialog(BuildContext context, GymTask task, SystemProvider prov) {
    final wCtrl = TextEditingController(text: task.lastWeight > 0 ? "${task.lastWeight}" : "");
    final rCtrl = TextEditingController(text: task.lastReps > 0 ? "${task.lastReps}" : "");

    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: kSystemBlack,
      shape: const RoundedRectangleBorder(side: BorderSide(color: kSystemBlue)),
      title: Text("LOG SET ${task.completedSets + 1}", style: const TextStyle(color: kSystemBlue)),
      content: Row(children: [
        Expanded(child: TextField(controller: wCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "KG", labelStyle: TextStyle(color: Colors.grey)))),
        const SizedBox(width: 16),
        Expanded(child: TextField(controller: rCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "REPS", labelStyle: TextStyle(color: Colors.grey)))),
      ]),
      actions: [
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: kSystemBlue), onPressed: () {
          prov.logSet(task, int.tryParse(wCtrl.text)??0, int.tryParse(rCtrl.text)??0);
          Navigator.pop(ctx);
        }, child: const Text("COMPLETE SET", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
      ],
    ));
  }
}

// ==========================================
// 9. ALTRE LISTE E STATISTICHE
// ==========================================

class DungeonKeysScreen extends StatelessWidget {
  const DungeonKeysScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final list = Provider.of<SystemProvider>(context).gymQuests;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("DUNGEON KEYS", style: TextStyle(color: kPurple))),
      body: list.isEmpty ? const Center(child: Text("No Keys Crafted", style: TextStyle(color: Colors.grey))) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, i) => Card(
          color: kSystemBlack,
          shape: RoundedRectangleBorder(side: BorderSide(color: list[i].gymRoutine.every((t)=>t.isFinished) ? Colors.grey : kPurple)),
          child: ListTile(
            title: Text(list[i].title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text("${list[i].gymRoutine.length} Monsters (Exercises)", style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.arrow_forward_ios, color: kPurple),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveDungeonScreen(quest: list[i]))),
          ),
        ),
      ),
    );
  }
}

class QuestLogScreen extends StatelessWidget {
  const QuestLogScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SystemProvider>(context);
    final list = [...prov.dailyQuests, ...prov.advQuests];
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("QUEST LOG", style: TextStyle(color: kGold))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final q = list[i];
          final col = q.type == QuestType.daily ? kGold : kGreen;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(border: Border.all(color: q.isDone ? Colors.grey : col.withOpacity(0.5))),
            child: ListTile(
              leading: Checkbox(activeColor: col, value: q.isDone, onChanged: (_) => prov.toggleDaily(q)),
              title: Text(q.title, style: TextStyle(color: q.isDone ? Colors.grey : Colors.white, decoration: q.isDone ? TextDecoration.lineThrough : null)),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: ()=> prov.removeQuest(q)),
            ),
          );
        },
      ),
    );
  }
}

class StatusWindowScreen extends StatelessWidget {
  const StatusWindowScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final lvl = Provider.of<SystemProvider>(context).playerLevel;
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text("NAME: PLAYER", style: TextStyle(color: Colors.white)),
      const Text("JOB: SHADOW MONARCH", style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 30),
      const Text("LEVEL", style: TextStyle(color: Colors.white, fontSize: 30)),
      Text("$lvl", style: const TextStyle(color: kSystemBlue, fontSize: 60, fontWeight: FontWeight.bold, shadows: [Shadow(color: kSystemBlue, blurRadius: 20)])),
    ]));
  }
}