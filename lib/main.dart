import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Connect to your existing Supabase project
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
      title: 'KIST Lab Request',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003366)),
        scaffoldBackgroundColor: const Color(0xFFF0F4F8), // Softer background
      ),
      home: const ToolRequestScreen(),
    );
  }
}

class ToolRequestScreen extends StatefulWidget {
  const ToolRequestScreen({super.key});

  @override
  State<ToolRequestScreen> createState() => _ToolRequestScreenState();
}

class _ToolRequestScreenState extends State<ToolRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _admController = TextEditingController();
  final _phoneController = TextEditingController();
  final _classController = TextEditingController();
  final _customToolsController = TextEditingController(); // NEW: For "Other" tools

  // The tools available to request
  final List<String> _availableTools = [
    "Fluke Multimeter",
    "Screwdriver Set (Precision)",
    "Soldering Station",
    "Wire Stripper",
    "Breadboard Kit",
    "Arduino Uno R3",
    "Oscilloscope Probe",
    "Allen Key Set"
  ];
  
  final Set<String> _selectedTools = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _admController.dispose();
    _phoneController.dispose();
    _classController.dispose();
    _customToolsController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    final customToolsText = _customToolsController.text.trim();
    
    // VALIDATION: Must pick a tool OR type a custom tool
    if (_selectedTools.isEmpty && customToolsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one tool or type one in the "Other Tools" box.', style: TextStyle(color: Colors.white)), 
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Format the checked tools
      final toolsJson = _selectedTools.map((t) => {'tool': t, 'qty': 1}).toList();
      
      // Add custom tools if typed
      if (customToolsText.isNotEmpty) {
        toolsJson.add({'tool': 'Other: $customToolsText', 'qty': 1});
      }

      // Push to Supabase
      await Supabase.instance.client.from('tool_requests').insert({
        'student_name': _nameController.text.trim(),
        'adm_number': _admController.text.trim().toUpperCase(),
        'phone_number': _phoneController.text.trim(),
        'class_name': _classController.text.trim(),
        'tools_requested': toolsJson,
        'status': 'PENDING'
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SuccessScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to lab server: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- MODERN INPUT DECORATION ---
  InputDecoration _modernInput(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF003366).withOpacity(0.6)),
      filled: true,
      fillColor: Colors.blueGrey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF003366), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KIST Mechatronics", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF003366),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Header Design
          Container(
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF003366),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          
          // Main Form Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 40),
                child: Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                                  child: const Icon(Icons.qr_code_scanner, size: 32, color: Color(0xFF003366)),
                                ),
                                const SizedBox(height: 15),
                                const Text("Lab Tool Requisition", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
                                const SizedBox(height: 5),
                                Text("Skip the line. Request your tools here.", style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // --- STUDENT DETAILS ---
                          const Text("Student Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _modernInput('Full Name', Icons.person),
                            validator: (val) => val!.isEmpty ? 'Please enter your name' : null,
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _admController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _modernInput('Admission Number', Icons.badge, hint: 'e.g. MECH/2026/001'),
                            validator: (val) => val!.isEmpty ? 'Please enter your admission number' : null,
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _classController,
                                  decoration: _modernInput('Class / Group', Icons.group),
                                  validator: (val) => val!.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: _modernInput('Phone Number', Icons.phone),
                                  validator: (val) => val!.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 35),
                          
                          // --- TOOL SELECTION ---
                          const Text("Required Tools", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blueGrey.shade100)
                            ),
                            child: Column(
                              children: _availableTools.asMap().entries.map((entry) {
                                final index = entry.key;
                                final tool = entry.value;
                                final isLast = index == _availableTools.length - 1;
                                
                                return Column(
                                  children: [
                                    CheckboxListTile(
                                      title: Text(tool, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      value: _selectedTools.contains(tool),
                                      activeColor: const Color(0xFF003366),
                                      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (bool? selected) {
                                        setState(() {
                                          if (selected == true) _selectedTools.add(tool);
                                          else _selectedTools.remove(tool);
                                        });
                                      },
                                    ),
                                    if (!isLast) Divider(height: 1, color: Colors.blueGrey.shade200, indent: 15, endIndent: 15),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          
                          const SizedBox(height: 25),
                          
                          // --- OTHER TOOLS ---
                          const Text("Other Tools", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _customToolsController,
                            maxLines: 2,
                            decoration: _modernInput('Type any other tools needed...', Icons.add_box, hint: 'e.g., 2 Pliers, 1 Roll of Tape'),
                          ),

                          const SizedBox(height: 40),
                          
                          // --- SUBMIT BUTTON ---
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F), // KIST Accent Red
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFFD32F2F).withOpacity(0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: _isSubmitting ? null : _submitRequest,
                              child: _isSubmitting 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("SEND TO TRAINER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// SUCCESS SCREEN
class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 80),
              ),
              const SizedBox(height: 30),
              const Text("Request Sent!", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF003366))),
              const SizedBox(height: 15),
              const Text(
                "Your request has instantly appeared on the trainer's screen.", 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),
              const SizedBox(height: 10),
              const Text(
                "Please proceed to the desk to collect your tools.", 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 50),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ToolRequestScreen()));
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Submit another request", style: TextStyle(fontSize: 16)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF003366)),
              )
            ],
          ),
        ),
      ),
    );
  }
}