import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for async main

  // ⚠️ HACKATHON STEP: Paste your Supabase URL and Anon Key here!
  await Supabase.initialize(
    url: 'https://vczrykrtshcfgeazmnak.supabase.co',
    anonKey: 'sb_publishable_A3ngRWqzlMohQ87mcCrU5g_2N3_wqgz',
  );

  runApp(const VolunteerApp());
}

class VolunteerApp extends StatelessWidget {
  const VolunteerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volunteer Match-30',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DiscoveryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  // --- STATE VARIABLES ---
  String searchQuery = "";
  String activeFilter = "all";
  String viewMode = "list";
  int totalXP = 1250;
  int currentNavIndex = 0;
  List<String> claimedIds = [];

  // --- DATABASE SETUP ---
  final supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _tasksStream;

  @override
  void initState() {
    super.initState();
    // Start listening to the live Postgres database!
    _tasksStream = supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // --- DATABASE FUNCTIONS ---
  Future<void> createNewTask(String title, String category, int duration, int xp) async {
    try {
      await supabase.from('tasks').insert({
        'title': title,
        'category': category,
        'duration': duration,
        'xp': xp,
        'verified': true,
        'distance': '0.3 mi',
        // Slight math so new map pins don't stack perfectly on top of each other
        'lat': 37.3540 + (DateTime.now().millisecond % 10) * 0.001,
        'lng': -121.9550 + (DateTime.now().second % 10) * 0.001,
        'status': 'open'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("New task posted to live database!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error creating task: $e");
    }
  }

  Future<void> completeTask(String taskId, int xp) async {
    try {
      await supabase.from('tasks').delete().eq('id', taskId);

      setState(() {
        totalXP += xp;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Task Completed! +$xp XP Earned"), backgroundColor: Colors.amber.shade700),
        );
      }
    } catch (e) {
      print("Error deleting task: $e");
    }
  }

  // --- CLAIM A TASK ---
  Future<void> claimTask(String taskId) async {
    try {
      // Updates the status from 'open' to 'claimed'
      await supabase.from('tasks').update({'status': 'claimed'}).eq('id', taskId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task Claimed! Check the 'My Tasks' tab."), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      print("Error claiming task: $e");
    }
  }

  // --- DROP/UNCLAIM A TASK ---
  Future<void> unclaimTask(String taskId) async {
    try {
      // Puts it back in the Discover feed
      await supabase.from('tasks').update({'status': 'open'}).eq('id', taskId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task dropped. It is back in the Discover feed."), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print("Error unclaiming task: $e");
    }
  }

  // --- BOTTOM SHEETS ---
  void _showCreateTaskSheet() {
    final titleController = TextEditingController();
    final durationController = TextEditingController();
    final xpController = TextEditingController();
    String selectedCategory = 'physical';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Post a New Job", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Task Title", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'physical', child: Text("Physical (Moving, Cleaning)")),
                      DropdownMenuItem(value: 'education', child: Text("Education (Tutoring)")),
                      DropdownMenuItem(value: 'tech', child: Text("Tech (IT Help, Setup)")),
                    ],
                    onChanged: (val) => setModalState(() => selectedCategory = val!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Duration (mins)", border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: xpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "XP Reward", border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                      onPressed: () {
                        final title = titleController.text;
                        final duration = int.tryParse(durationController.text) ?? 15;
                        final xp = int.tryParse(xpController.text) ?? 100;

                        if (title.isNotEmpty) {
                          Navigator.pop(context);
                          createNewTask(title, selectedCategory, duration, xp);
                        }
                      },
                      child: const Text("Post Job", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showTaskDetailSheet(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(task['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  if (task['verified'] == true) const Icon(Icons.verified, color: Colors.blue)
                ],
              ),
              const SizedBox(height: 8),
              Text("${task['distance']} away • ${task['duration']} mins", style: const TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.amber),
                  Text("Reward: ${task['xp']} XP", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    Navigator.pop(context);
                    // Deletes the task from the DB and gives the user XP!
                    completeTask(task['id'].toString(), int.tryParse(task['xp'].toString()) ?? 0);
                  },
                  child: const Text("Complete & Claim XP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (currentNavIndex) {
      case 0: return _buildDiscoverTab();
      case 1: return _buildMyTasksTab();
      case 2: return _buildProfileTab();
      default: return _buildDiscoverTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text("Volunteer Match-30", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 18),
                Text("$totalXP", style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: currentNavIndex == 0 ? FloatingActionButton.extended(
        onPressed: _showCreateTaskSheet,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Post Job", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentNavIndex,
        onTap: (index) => setState(() => currentNavIndex = index),
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Discover"),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: "My Tasks"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 0: DISCOVER
  // ==========================================
  Widget _buildDiscoverTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                hintText: "Search tasks nearby...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Nearby Tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.list, color: viewMode == "list" ? Colors.teal : Colors.grey),
                      onPressed: () => setState(() => viewMode = "list"),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: Icon(Icons.map, color: viewMode == "map" ? Colors.teal : Colors.grey),
                      onPressed: () => setState(() => viewMode = "map"),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilter("All", "all"),
              const SizedBox(width: 8),
              _buildFilter("Under 10 mins", "under10"),
              const SizedBox(width: 8),
              _buildFilter("Education", "education"),
              const SizedBox(width: 8),
              _buildFilter("Physical", "physical"),
            ],
          ),
        ),
        
        // LIVE DATABASE STREAM
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _tasksStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.teal));
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              final liveTasks = snapshot.data ?? [];
              final filteredTasks = liveTasks.where((task) {
                if (searchQuery.isNotEmpty && !task['title'].toString().toLowerCase().contains(searchQuery.toLowerCase())) return false;
                
                final duration = task['duration'] is int ? task['duration'] : int.tryParse(task['duration'].toString()) ?? 0;
                if (activeFilter == "under10" && duration > 10) return false;
                if (activeFilter == "education" && task['category'] != "education") return false;
                if (activeFilter == "physical" && task['category'] != "physical") return false;
                
                return true;
              }).toList();

              return viewMode == "map" 
                ? _buildGoogleMap(filteredTasks) 
                : _buildListView(filteredTasks);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleMap(List<Map<String, dynamic>> tasks) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(37.3541, -121.9552),
        zoom: 14,
      ),
      myLocationEnabled: true,
      markers: tasks.map((task) {
        final lat = task['lat'] is double ? task['lat'] : double.tryParse(task['lat'].toString()) ?? 37.3541;
        final lng = task['lng'] is double ? task['lng'] : double.tryParse(task['lng'].toString()) ?? -121.9552;
        
        return Marker(
          markerId: MarkerId(task['id'].toString()),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: task['title'],
            snippet: "${task['duration']} mins • Tap to view",
            onTap: () => _showTaskDetailSheet(task),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            task['category'] == 'education' ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange
          ),
        );
      }).toSet(),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("No tasks match your filters.", style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return GestureDetector(
          onTap: () => _showTaskDetailSheet(task),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    task['category'] == 'education' ? Icons.school : 
                    task['category'] == 'tech' ? Icons.computer : Icons.fitness_center,
                    color: Colors.teal.shade600,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task['title'], 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (task['verified'] == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: Colors.blue, size: 16),
                          ]
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text("${task['distance']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(width: 12),
                          Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text("${task['duration']} min", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.amber, size: 14),
                          Text("${task['xp']}", style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20)
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilter(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: activeFilter == value,
      onSelected: (_) => setState(() => activeFilter = value),
      backgroundColor: Colors.white,
      selectedColor: Colors.teal.shade100,
      checkmarkColor: Colors.teal.shade900,
      side: BorderSide(color: activeFilter == value ? Colors.teal : Colors.grey.shade300),
    );
  }

  // ==========================================
  // TAB 1: MY TASKS (Placeholder)
  // ==========================================
  Widget _buildMyTasksTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("No active tasks yet.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Go to Discover to claim one!", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PROFILE
  // ==========================================
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Badges", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("6/9 unlocked", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBadgesGrid(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Skills", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text("Edit"),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue.shade600),
                    )
                  ],
                ),
                _buildSkillsWrap(),
                const SizedBox(height: 24),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF2476D2),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: const Center(
                  child: Text("AJ", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Alex Johnson", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text("Level 5", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      const Text("Neighborhood Hero", style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$totalXP / 5,000 XP", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
              Text("Level 6", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalXP / 5000,
            backgroundColor: Colors.black.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          )
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(Icons.workspace_premium_outlined, "23", "Tasks Done", Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard(Icons.schedule, "485", "Mins Donated", Colors.green),
        const SizedBox(width: 12),
        _buildStatCard(Icons.bolt, "$totalXP", "Points Earned", Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesGrid() {
    final badges = [
      {"title": "First 5-Star", "icon": Icons.star_border, "unlocked": true},
      {"title": "Weekend Warrior", "icon": Icons.military_tech_outlined, "unlocked": true},
      {"title": "Speed Demon", "icon": Icons.bolt, "unlocked": true},
      {"title": "Kind Heart", "icon": Icons.favorite_border, "unlocked": true},
      {"title": "Team Player", "icon": Icons.people_outline, "unlocked": true},
      {"title": "Delivery Pro", "icon": Icons.inventory_2_outlined, "unlocked": false},
      {"title": "Math Whiz", "icon": Icons.calculate_outlined, "unlocked": true},
      {"title": "Strong Helper", "icon": Icons.fitness_center, "unlocked": false},
      {"title": "Tech Guru", "icon": Icons.code, "unlocked": false},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final bool isUnlocked = badge["unlocked"] as bool;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              if (isUnlocked) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked ? Colors.teal.shade50 : Colors.grey.shade100,
                ),
                child: Icon(
                  badge["icon"] as IconData, 
                  color: isUnlocked ? Colors.teal.shade400 : Colors.grey.shade300,
                  size: 24
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge["title"] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                  color: isUnlocked ? Colors.black87 : Colors.grey.shade400,
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkillsWrap() {
    final skills = ["Math", "Lifting", "Coding", "Dog Walking", "Tutoring", "Cooking"];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) => Chip(
        label: Text(skill, style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.teal.shade50,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      )).toList(),
    );
  }
}