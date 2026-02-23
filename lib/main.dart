import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://htvyekhsxzctvlltqtsq.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh0dnlla2hzeHpjdHZsbHRxdHNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwMDA1NjMsImV4cCI6MjA4NjU3NjU2M30.F8DUOG6q9ynw1IbIkn1Q1GJfICL_XvJKb9V-AlPCuEw',
  );
  runApp(const KistStudentPortal());
}

class KistStudentPortal extends StatelessWidget {
  const KistStudentPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KINAP Lab Request',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(), 
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFE31837), // KINAP Red
        ),
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep sleek black
      ),
      home: const ToolRequestScreen(),
    );
  }
}

class ToolEntry {
  TextEditingController nameCtrl = TextEditingController();
  int qty = 1;
  void dispose() { nameCtrl.dispose(); }
}

class ToolRequestScreen extends StatefulWidget {
  const ToolRequestScreen({super.key});
  @override
  State<ToolRequestScreen> createState() => _ToolRequestScreenState();
}

class _ToolRequestScreenState extends State<ToolRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _admController = TextEditingController();
  final _phoneController = TextEditingController();
  final _classController = TextEditingController(); 
  
  // NEW: Focus node for Admission Number auto-fill
  final _admFocusNode = FocusNode();
  bool _isFetchingStudent = false;
  
  String? _selectedClass;
  final List<String> _hardcodedClasses = [
    'Diploma in Mechatronics (Y1)',
    'Diploma in Mechatronics (Y2)',
    'Certificate in Mechatronics',
    'Short Course / Artisan',
    'Other',
    // Added your actual db groups here to prevent dropdown errors if they auto-fill
    'DIM2509B', 'DIM2509A', 'DIM2505B', 'DIM2505A', 'DIM2409B', 'DIM2409A', 'DIM2405', 'DIM2309'
  ];

  bool _requestLockerKey = false;
  List<ToolEntry> _requestedTools = [ToolEntry()]; 
  
  bool _isSubmitting = false;
  bool _isReturningUser = false;
  List<Map<String, dynamic>> _dbStudents = [];
  
  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _syncOfflineRequests());
    
    // NEW: Listen to focus changes on ADM field
    _admFocusNode.addListener(() {
      if (!_admFocusNode.hasFocus) {
        _autoFillFromAdm();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _nameController.dispose(); 
    _admController.dispose(); 
    _phoneController.dispose(); 
    _classController.dispose();
    _admFocusNode.dispose();
    for (var t in _requestedTools) { t.dispose(); }
    super.dispose();
  }

  // NEW: Search by ADM function
  Future<void> _autoFillFromAdm() async {
    final adm = _admController.text.trim().toUpperCase();
    if (adm.isEmpty) return;

    setState(() => _isFetchingStudent = true);
    Map<String, dynamic>? foundStudent;

    // 1. Try instant local cache first (from _loadInitialData)
    try {
      foundStudent = _dbStudents.firstWhere((s) => (s['adm_number'] ?? '').toString().toUpperCase() == adm);
    } catch (e) {
      // 2. If not in local cache, try Supabase fallback
      try {
        final response = await Supabase.instance.client.from('students').select().eq('adm_number', adm).maybeSingle();
        if (response != null) foundStudent = response;
      } catch (err) { /* Ignore network errors here */ }
    }

    if (foundStudent != null && mounted) {
      setState(() {
        _nameController.text = foundStudent!['name'] ?? '';
        String dbClass = foundStudent!['group_name'] ?? '';
        if (_hardcodedClasses.contains(dbClass)) {
          _selectedClass = dbClass;
        } else if (dbClass.isNotEmpty) {
          _selectedClass = 'Other';
          _classController.text = dbClass;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student found! Details auto-filled.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
    }
    
    if (mounted) setState(() => _isFetchingStudent = false);
  }

  Future<void> _syncOfflineRequests() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList('student_offline_queue') ?? [];
    if (queue.isEmpty) { _isSyncing = false; return; }

    List<String> failedQueue = [];
    for (var item in queue) {
      try {
        final payload = jsonDecode(item);
        await Supabase.instance.client.from('tool_requests').insert(payload);
      } catch (e) {
        failedQueue.add(item); 
      }
    }
    
    await prefs.setStringList('student_offline_queue', failedQueue);
    _isSyncing = false;
  }

  Future<void> _loadInitialData() async {
    try {
      final data = await Supabase.instance.client.from('students').select();
      if (mounted) setState(() { _dbStudents = List<Map<String, dynamic>>.from(data); });
    } catch (e) {
      debugPrint("Offline: Cannot fetch auto-complete list.");
    }

    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('saved_name');
    if (savedName != null && savedName.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isReturningUser = true;
          _nameController.text = savedName;
          _admController.text = prefs.getString('saved_adm') ?? '';
          _phoneController.text = prefs.getString('saved_phone') ?? '';
          String savedClass = prefs.getString('saved_class') ?? '';
          if (_hardcodedClasses.contains(savedClass)) {
            _selectedClass = savedClass;
          } else if (savedClass.isNotEmpty) {
            _selectedClass = 'Other';
            _classController.text = savedClass;
          }
        });
      }
    }
  }

  void _resetUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_name');
    setState(() {
      _isReturningUser = false;
      _nameController.clear(); _admController.clear(); _phoneController.clear(); _classController.clear();
      _selectedClass = null;
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    final validTools = _requestedTools.where((t) => t.nameCtrl.text.trim().isNotEmpty).toList();
    if (validTools.isEmpty && !_requestLockerKey) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please request at least one tool or a locker key!'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String finalClass = _selectedClass == 'Other' ? _classController.text.trim() : (_selectedClass ?? 'Unknown');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_name', _nameController.text.trim());
      await prefs.setString('saved_adm', _admController.text.trim().toUpperCase());
      await prefs.setString('saved_phone', _phoneController.text.trim());
      await prefs.setString('saved_class', finalClass);

      final toolsJson = validTools.map((t) => {'tool': t.nameCtrl.text.trim(), 'qty': t.qty}).toList();
      if (_requestLockerKey) toolsJson.insert(0, {'tool': 'Locker Key', 'qty': 1});

      final payload = {
        'student_name': _nameController.text.trim(),
        'adm_number': _admController.text.trim().toUpperCase(),
        'phone_number': _phoneController.text.trim(),
        'class_name': finalClass,
        'tools_requested': toolsJson,
        'status': 'PENDING'
      };

      bool wentOffline = false;
      try {
        await Supabase.instance.client.from('tool_requests').insert(payload);
      } catch (e) {
        wentOffline = true;
        final queue = prefs.getStringList('student_offline_queue') ?? [];
        queue.add(jsonEncode(payload));
        await prefs.setStringList('student_offline_queue', queue);
      }

      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SuccessScreen(isOffline: wentOffline)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  // NEW: Updated to accept a suffix icon for the loading spinner
  InputDecoration _kinapInput(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.black.withOpacity(0.4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE31837), width: 2)), // KINAP Red Focus
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E0000), Color(0xFF121212), Color(0xFF0A0A0A)], // Dark red to black gradient
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // --- BRANDED HEADER ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: const Color(0xFFE31837).withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]
                        ),
                        child: Image.asset('assets/kinap.png', height: 60), // Institutional Logo
                      ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2),
                      
                      const SizedBox(height: 20),
                      const Text("Lab Requisition", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2))
                          .animate().fadeIn(delay: 200.ms),
                      Text("Skip the line. Request your tools instantly.", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16))
                          .animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 30),

                      // --- PROFILE CARD ---
                      _buildGlassCard(
                        child: _isReturningUser 
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Welcome Back! 🤙", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  TextButton(
                                    onPressed: _resetUser,
                                    child: const Text("Not you?", style: TextStyle(color: Colors.white54)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 10),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(backgroundColor: Color(0xFFE31837), foregroundColor: Colors.white, child: Icon(Icons.person)),
                                title: Text(_nameController.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                subtitle: Text("${_admController.text} • ${_selectedClass == 'Other' ? _classController.text : _selectedClass}", style: TextStyle(color: Colors.white.withOpacity(0.7))),
                              )
                            ],
                          ).animate().fadeIn().scale()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Who are you?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              
                              // 1. ADMISSION NUMBER (Moved to top for Auto-Fill)
                              TextFormField(
                                controller: _admController, 
                                focusNode: _admFocusNode,
                                style: const TextStyle(color: Colors.white), 
                                textCapitalization: TextCapitalization.characters,
                                decoration: _kinapInput(
                                  'Admission Number', 
                                  Icons.badge,
                                  suffixIcon: _isFetchingStudent 
                                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE31837)))) 
                                    : null
                                ), 
                                validator: (val) => val!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 15),

                              // 2. NAME AUTOCOMPLETE (Backup if they don't know ADM)
                              Autocomplete<Map<String, dynamic>>(
                                optionsBuilder: (TextEditingValue textVal) {
                                  if (textVal.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                                  return _dbStudents.where((s) => s['name'].toString().toLowerCase().contains(textVal.text.toLowerCase()));
                                },
                                displayStringForOption: (option) => option['name'],
                                onSelected: (selection) {
                                  _nameController.text = selection['name'];
                                  _admController.text = selection['adm_number'] ?? '';
                                  String dbClass = selection['group_name'] ?? '';
                                  if (_hardcodedClasses.contains(dbClass)) {
                                    _selectedClass = dbClass;
                                  } else if (dbClass.isNotEmpty) {
                                    _selectedClass = 'Other';
                                    _classController.text = dbClass;
                                  }
                                  setState(() {});
                                },
                                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                  // Sync the autocomplete controller with our main name controller
                                  if (controller.text != _nameController.text) {
                                    controller.text = _nameController.text;
                                  }
                                  controller.addListener(() { _nameController.text = controller.text; });
                                  return TextFormField(
                                    controller: controller, focusNode: focusNode, onEditingComplete: onEditingComplete,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _kinapInput("Full Name", Icons.person_search).copyWith(
                                      hintText: "Or search by your name...",
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3))
                                    ),
                                    validator: (val) => val == null || val.isEmpty ? "Required" : null,
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        width: 300, margin: const EdgeInsets.only(top: 8),
                                        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE31837).withOpacity(0.5))),
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(8), shrinkWrap: true, itemCount: options.length,
                                          itemBuilder: (ctx, i) {
                                            final option = options.elementAt(i);
                                            return ListTile(
                                              title: Text(option['name'], style: const TextStyle(color: Colors.white)),
                                              subtitle: Text(option['adm_number'] ?? '', style: const TextStyle(color: Color(0xFFE31837), fontSize: 12)),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 15),

                              // 3. PHONE NUMBER
                              TextFormField(
                                controller: _phoneController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.phone,
                                decoration: _kinapInput('Phone Number', Icons.phone), validator: (val) => val!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 15),
                              
                              // 4. CLASS DROPDOWN
                              DropdownButtonFormField<String>(
                                value: _selectedClass, dropdownColor: const Color(0xFF1E1E1E), style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                                decoration: _kinapInput('Class / Group', Icons.group),
                                items: _hardcodedClasses.map((String c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                                onChanged: (val) => setState(() => _selectedClass = val),
                                validator: (val) => val == null ? 'Please select your class' : null,
                              ),
                              if (_selectedClass == 'Other') ...[
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: _classController, style: const TextStyle(color: Colors.white),
                                  decoration: _kinapInput('Type your class name', Icons.edit), validator: (val) => val!.isEmpty ? 'Required' : null,
                                ).animate().fadeIn().slideY(begin: -0.2),
                              ]
                            ],
                          ).animate().fadeIn().slideX(begin: -0.1),
                      ),

                      const SizedBox(height: 20),

                      // --- REQUEST SECTION ---
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("What do you need? 🔧", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),

                            // --- LOCKER KEY TOGGLE ---
                            GestureDetector(
                              onTap: () => setState(() => _requestLockerKey = !_requestLockerKey),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                decoration: BoxDecoration(
                                  color: _requestLockerKey ? const Color(0xFFE31837).withOpacity(0.2) : Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _requestLockerKey ? const Color(0xFFE31837) : Colors.transparent, width: 2)
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.vpn_key, color: _requestLockerKey ? const Color(0xFFE31837) : Colors.white54, size: 28),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Text("I need a Locker Key", style: TextStyle(color: _requestLockerKey ? Colors.white : Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                    if (_requestLockerKey) const Icon(Icons.check_circle, color: Color(0xFFE31837)).animate().scale(duration: 200.ms)
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            Divider(color: Colors.white.withOpacity(0.1), thickness: 1),
                            const SizedBox(height: 20),
                            
                            // --- DYNAMIC TOOLS ---
                            ..._requestedTools.asMap().entries.map((entry) {
                              int idx = entry.key; ToolEntry tool = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: tool.nameCtrl, style: const TextStyle(color: Colors.white),
                                        decoration: _kinapInput("Tool Name (e.g. Multimeter)", Icons.build_circle),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(16)),
                                      child: Row(
                                        children: [
                                          IconButton(icon: const Icon(Icons.remove, color: Colors.white54), onPressed: () { if (tool.qty > 1) setState(() => tool.qty--); }),
                                          Text('${tool.qty}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                          IconButton(icon: const Icon(Icons.add, color: Color(0xFFE31837)), onPressed: () { setState(() => tool.qty++); }),
                                        ],
                                      ),
                                    ),
                                    if (_requestedTools.length > 1)
                                      IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => setState(() { tool.dispose(); _requestedTools.removeAt(idx); }))
                                  ],
                                ).animate().fadeIn().slideX(begin: 0.1),
                              );
                            }),
                            
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () => setState(() => _requestedTools.add(ToolEntry())), 
                              icon: const Icon(Icons.add_circle, color: Colors.white70), 
                              label: const Text("Add another tool", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16))
                            )
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                      const SizedBox(height: 30),

                      // --- SUBMIT BUTTON ---
                      SizedBox(
                        width: double.infinity, height: 65,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE31837), // KINAP Red
                            foregroundColor: Colors.white,
                            elevation: 10,
                            shadowColor: const Color(0xFFE31837).withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: _isSubmitting ? null : _submitRequest,
                          child: _isSubmitting 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("BEAM IT TO ADMIN 🚀", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3)),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- SUCCESS SCREEN ---
class SuccessScreen extends StatelessWidget {
  final bool isOffline;
  const SuccessScreen({super.key, this.isOffline = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1E0000), Color(0xFF121212)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: isOffline ? Colors.orange.withOpacity(0.1) : const Color(0xFFE31837).withOpacity(0.1), 
                shape: BoxShape.circle, 
                border: Border.all(color: isOffline ? Colors.orange : const Color(0xFFE31837), width: 2)
              ),
              child: Icon(isOffline ? Icons.wifi_off : Icons.verified_rounded, color: isOffline ? Colors.orange : const Color(0xFFE31837), size: 100)
                  .animate().scale(duration: 600.ms, curve: Curves.elasticOut).then(delay: 200.ms).shake(hz: 4, curve: Curves.easeInOutCubic),
            ),
            const SizedBox(height: 40),
            Text(isOffline ? "SAVED OFFLINE" : "LOCKED IN!", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2))
                .animate().fadeIn(delay: 400.ms).slideY(begin: 0.5),
            const SizedBox(height: 15),
            
            Text(
              isOffline 
                ? "No internet connection detected.\nYour request is saved and will send automatically when you reconnect."
                : "Your request is on the trainer's screen.", 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.white70)
            ).animate().fadeIn(delay: 800.ms),
            
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ToolRequestScreen())),
              icon: const Icon(Icons.refresh),
              label: const Text("Submit another request", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
              ),
            ).animate().fadeIn(delay: 1200.ms)
          ],
        ),
      ),
    );
  }
}