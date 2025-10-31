import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MedicalAssistantApp());
}

class MedicalAssistantApp extends StatelessWidget {
  const MedicalAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Assistant',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  File? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  bool _showEmergencyButton = false;
  bool _darkMode = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Speech to text variables
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _spokenText = '';
  double _confidence = 1.0;

  // User profile data
  Map<String, dynamic> _userProfile = {
    'name': 'User',
    'age': '',
    'bloodType': '',
    'allergies': '',
    'conditions': '',
    'medications': '',
  };

  // Health metrics
  Map<String, dynamic> _healthMetrics = {
    'lastBP': '',
    'lastHeartRate': '',
    'lastWeight': '',
    'lastTemperature': '',
  };

  // Quick responses
  final List<String> _quickResponses = [
    "What are the symptoms of flu?",
    "How to lower blood pressure?",
    "Best exercises for back pain",
    "Healthy diet recommendations",
    "Stress management techniques",
  ];

  static const String _groqApiKey = "Use Your Groq Api kwy in this ";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
    _loadUserData();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _messages.add(ChatMessage(
      text: _getWelcomeMessage(),
      isUser: false,
      timestamp: DateTime.now(),
    ));

    _scrollController.addListener(() {
      if (_scrollController.position.atEdge) {
        if (_scrollController.position.pixels != 0) {
          _showEmergencyButton = false;
        } else {
          _showEmergencyButton = true;
        }
      }
    });
  }

  String _getWelcomeMessage() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return "$greeting! I'm your medical assistant. How can I help you today?";
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _userProfile = {
        'name': prefs.getString('userName') ?? 'User',
        'age': prefs.getString('userAge') ?? '',
        'bloodType': prefs.getString('userBloodType') ?? '',
        'allergies': prefs.getString('userAllergies') ?? '',
        'conditions': prefs.getString('userConditions') ?? '',
        'medications': prefs.getString('userMedications') ?? '',
      };
    });
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setString('userName', _userProfile['name']);
    await prefs.setString('userAge', _userProfile['age']);
    await prefs.setString('userBloodType', _userProfile['bloodType']);
    await prefs.setString('userAllergies', _userProfile['allergies']);
    await prefs.setString('userConditions', _userProfile['conditions']);
    await prefs.setString('userMedications', _userProfile['medications']);
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _stopListening();
          }
        },
        onError: (error) {
          print('Speech error: ${error.errorMsg}');
          _handleError(error.errorMsg);
        },
      );

      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Speech recognition not available")),
          );
        }
      }
    } catch (e) {
      print('Speech initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech recognition failed: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isListening) {
      _stopListening();
    }

    String userMessage = _messageController.text.trim();
    if (userMessage.isEmpty && _imageFile == null && _imageBytes == null) return;

    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        image: _imageFile,
        imageBytes: _imageBytes,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
      _messageController.clear();
      _spokenText = '';
    });

    _scrollToBottom();

    if (_imageFile != null || _imageBytes != null) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Analyzing image...",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }

    try {
      String imageAnalysis = '';
      if (_imageFile != null || _imageBytes != null) {
        imageAnalysis = await _analyzeImage();
      }

      final String botResponse = await _getGroqResponse(userMessage, imageAnalysis);
      setState(() {
        if (_messages.last.text == "Analyzing image...") {
          _messages.removeLast();
        }
        _messages.add(ChatMessage(
          text: botResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
        _imageFile = null;
        _imageBytes = null;
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        if (_messages.last.text == "Analyzing image...") {
          _messages.removeLast();
        }
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error. Please try again.\nError: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> _analyzeImage() async {
    await Future.delayed(const Duration(seconds: 1));
    return "User has uploaded an image for medical analysis. ";
  }

  Future<String> _getGroqResponse(String message, String imageAnalysis) async {
    if (_groqApiKey.isEmpty || _groqApiKey.contains("your_actual_api_key")) {
      return "Please configure your Groq API key in the code.";
    }

    const String model = "Use your Model ";
    const String apiUrl = "Api URL";

    String userContext = "";
    if (_userProfile['age'].isNotEmpty || _userProfile['conditions'].isNotEmpty) {
      userContext = """
        User Profile Context:
        - Age: ${_userProfile['age']}
        - Blood Type: ${_userProfile['bloodType']}
        - Allergies: ${_userProfile['allergies']}
        - Medical Conditions: ${_userProfile['conditions']}
        - Current Medications: ${_userProfile['medications']}
        
        """;
    }

    String systemPrompt = """
      You are an advanced medical assistant.
      Provide accurate, evidence-based medical information in English.

      Current date: ${DateFormat('MMMM d, y').format(DateTime.now())}

      $userContext

      Guidelines:
      1. Be concise but thorough in responses
      2. Use bullet points for lists of symptoms or treatments
      3. Highlight urgent concerns in bold
      4. Always recommend consulting a doctor for serious symptoms
      5. Do not include any references or citations in your responses
      6. Provide information in your own words without attribution

      Image Analysis Guidelines:
      1. Carefully consider any image descriptions provided
      2. Describe visible medical conditions or features
      3. Provide differential diagnoses when appropriate
      4. Suggest possible causes for visible symptoms
      5. Recommend next steps or treatments
      6. Always advise consulting a doctor for proper diagnosis
      """;

    String fullMessage = imageAnalysis.isNotEmpty
        ? "Image Context: $imageAnalysis\n\nUser Question: $message"
        : message;

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Authorization": "Bearer $_groqApiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": model,
        "messages": [
          {
            "role": "system",
            "content": systemPrompt
          },
          {
            "role": "user",
            "content": fullMessage
          }
        ],
        "temperature": 0.7,
        "max_tokens": 1024,
        "stream": false,
      }),
    );

    print('API Response Status: ${response.statusCode}');
    print('API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String responseText = data['choices'][0]['message']['content'] ?? "Sorry, I encountered an error.";

      responseText = responseText.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '');
      responseText = responseText.replaceAll(RegExp(r'Source:.*'), '');
      responseText = responseText.replaceAll(RegExp(r'Reference:.*'), '');

      return responseText.trim();
    } else {
      throw Exception('API request failed: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await showModalBottomSheet<XFile>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context, await _picker.pickImage(source: ImageSource.gallery));
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context, await _picker.pickImage(source: ImageSource.camera));
                },
              ),
            ],
          ),
        ),
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imageFile = null;
          });
        } else {
          setState(() {
            _imageFile = File(image.path);
            _imageBytes = null;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to pick image: ${e.toString()}")),
      );
    }
  }

  ImageProvider _getImageProvider() {
    if (kIsWeb) {
      return MemoryImage(_imageBytes!);
    } else {
      return FileImage(_imageFile!);
    }
  }

  Future<void> _listen() async {
    if (_isListening) {
      _stopListening();
      return;
    }

    try {
      if (!kIsWeb) {
        var status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Microphone permission not granted")),
            );
          }
          return;
        }
      }

      bool available = await _speech.isAvailable;

      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Speech recognition not available")),
          );
        }
        return;
      }

      setState(() {
        _isListening = true;
        _spokenText = '';
        _messageController.clear();
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _spokenText = result.recognizedWords;
            _messageController.text = _spokenText;
            if (result.hasConfidenceRating && result.confidence > 0) {
              _confidence = result.confidence;
            }
          });
        },
        localeId: 'en-US',
        listenFor: const Duration(seconds: 30),
        cancelOnError: true,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      print('Speech listening error: $e');
      _stopListening();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech listening failed: $e')),
        );
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _handleError(String errorMsg) {
    print('Speech error: $errorMsg');
    String translatedError;
    switch (errorMsg) {
      case 'error_no_match':
        translatedError = "No speech detected";
        break;
      case 'error_not_available':
        translatedError = "Speech recognition not available";
        break;
      case 'error_permission_denied':
        translatedError = "Microphone permission not granted";
        break;
      default:
        translatedError = errorMsg;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translatedError)),
      );
    }

    _stopListening();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text: _getWelcomeMessage(),
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: _darkMode ? Colors.grey[800] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_imageFile != null || _imageBytes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: _getImageProvider(),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    margin: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => setState(() {
                        _imageFile = null;
                        _imageBytes = null;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _darkMode ? Colors.grey[700] : Colors.grey[200],
                ),
                child: IconButton(
                  icon: Icon(Icons.add, color: _darkMode ? Colors.white : Colors.blue),
                  onPressed: _showAttachmentMenu,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _darkMode ? Colors.grey[700] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _messageController,
                            maxLines: null,
                            style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: "Type your message...",
                              hintStyle: TextStyle(color: _darkMode ? Colors.grey[400] : Colors.grey[600]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: _isListening ? Colors.red : (_darkMode ? Colors.white : Colors.blue),
                        ),
                        onPressed: _listen,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
          if (_isListening)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    "Listening...",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  if (_spokenText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"$_spokenText"',
                        style: TextStyle(
                          color: _darkMode ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add Attachment",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildAttachmentOption(Icons.photo_library, "Gallery", _pickImage),
                  _buildAttachmentOption(Icons.camera_alt, "Camera", _pickImage),
                  _buildAttachmentOption(Icons.medical_services, "Vitals", _showVitalsInput),
                  _buildAttachmentOption(Icons.medication, "Medication", _showMedicationInput),
                  _buildAttachmentOption(Icons.note_add, "Symptoms", _showSymptomsInput),
                  _buildAttachmentOption(Icons.calendar_today, "Appointment", _scheduleAppointment),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: _darkMode ? Colors.grey[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.blue),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _darkMode ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleDarkMode() {
    setState(() {
      _darkMode = !_darkMode;
    });
    _saveUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _darkMode ? Colors.grey[900] : Colors.grey[50],
      child: Scaffold(
        backgroundColor: _darkMode ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.medical_services, color: Colors.blue.shade600, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "MedAssistant",
                    style: TextStyle(
                      color: _darkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Online",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _clearChat,
              tooltip: "Clear Chat",
            ),
            IconButton(
              icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleDarkMode,
              tooltip: _darkMode ? "Light Mode" : "Dark Mode",
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    _showUserProfile();
                    break;
                  case 'history':
                    _showChatHistory();
                    break;
                  case 'settings':
                    _showSettings();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('My Profile'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Chat History'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildQuickActions(),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _darkMode
                            ? LinearGradient(
                          colors: [Colors.grey[850]!, Colors.grey[900]!],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                            : LinearGradient(
                          colors: [Colors.blue.shade50, Colors.grey[50]!],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return _messages[index];
                              },
                            ),
                            if (_isTyping)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: TypingIndicator(text: "Doctor is typing..."),
                              ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildMessageInput(),
                ],
              ),
              Positioned(
                right: 20,
                bottom: 100,
                child: Column(
                  children: [
                    FloatingActionButton(
                      mini: true,
                      heroTag: 'scrollDown',
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.arrow_downward),
                    ),
                    const SizedBox(height: 8),
                    if (_showEmergencyButton)
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'emergency',
                        onPressed: _showEmergencyDialog,
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.emergency, color: Colors.white),
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

  Widget _buildQuickActions() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildQuickAction("Symptoms", Icons.medical_services, Colors.blue, _showSymptomsChecker),
          _buildQuickAction("Medication", Icons.medication, Colors.green, _showMedicationInfo),
          _buildQuickAction("First Aid", Icons.emergency, Colors.orange, _showFirstAid),
          _buildQuickAction("Health Tips", Icons.health_and_safety, Colors.purple, _showHealthTips),
          _buildQuickAction("Find Doctors", Icons.local_hospital, Colors.red, _findDoctors),
        ],
      ),
    );
  }

  Widget _buildQuickAction(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _darkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: _darkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.medical_services, size: 30, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                Text(
                  "MedAssistant",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Your Personal Health Assistant',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.person, "My Profile", _showUserProfile),
          _buildDrawerItem(Icons.medical_services, "Health Dashboard", _showHealthDashboard),
          _buildDrawerItem(Icons.emergency, "Emergency", _showEmergencyDialog),
          _buildDrawerItem(Icons.medication, "Medication Tracker", _showMedicationTracker),
          _buildDrawerItem(Icons.favorite, "Vitals Tracker", _showVitalsTracker),
          _buildDrawerItem(Icons.calendar_today, "Appointments", _showAppointments),
          _buildDrawerItem(Icons.history, "Chat History", _showChatHistory),
          _buildDrawerItem(Icons.health_and_safety, "Health Records", _showHealthRecords),
          _buildDrawerItem(Icons.local_hospital, "Find Hospitals", _findHospitals),
          _buildDrawerItem(Icons.settings, "Settings", _showSettings),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Disclaimer: This is an AI assistant for informational purposes only. '
                  'It does not replace professional medical advice. Always consult a healthcare provider.',
              style: TextStyle(
                fontSize: 12,
                color: _darkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: _darkMode ? Colors.white : Colors.black),
      title: Text(title, style: TextStyle(color: _darkMode ? Colors.white : Colors.black)),
      onTap: onTap,
    );
  }

  // Enhanced UI Components and Features

  void _showUserProfile() {
    final TextEditingController nameController = TextEditingController(text: _userProfile['name']);
    final TextEditingController ageController = TextEditingController(text: _userProfile['age']);
    final TextEditingController bloodController = TextEditingController(text: _userProfile['bloodType']);
    final TextEditingController allergiesController = TextEditingController(text: _userProfile['allergies']);
    final TextEditingController conditionsController = TextEditingController(text: _userProfile['conditions']);
    final TextEditingController medicationsController = TextEditingController(text: _userProfile['medications']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.blue),
            SizedBox(width: 8),
            Text("My Medical Profile"),
          ],
        ),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue.shade100,
                child: Icon(Icons.person, size: 40, color: Colors.blue),
              ),
              SizedBox(height: 16),
              _buildProfileField("Full Name", nameController, Icons.person),
              _buildProfileField("Age", ageController, Icons.cake),
              _buildProfileField("Blood Type", bloodController, Icons.bloodtype),
              _buildProfileField("Allergies", allergiesController, Icons.warning, maxLines: 2),
              _buildProfileField("Medical Conditions", conditionsController, Icons.medical_services, maxLines: 2),
              _buildProfileField("Current Medications", medicationsController, Icons.medication, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _userProfile = {
                  'name': nameController.text,
                  'age': ageController.text,
                  'bloodType': bloodController.text,
                  'allergies': allergiesController.text,
                  'conditions': conditionsController.text,
                  'medications': medicationsController.text,
                };
              });
              _saveUserData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Profile updated successfully!")),
              );
            },
            child: Text("Save Profile"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(),
          filled: true,
          fillColor: _darkMode ? Colors.grey[700] : Colors.grey[100],
        ),
        style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
      ),
    );
  }

  void _showHealthDashboard() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.dashboard, color: Colors.green),
            SizedBox(width: 8),
            Text("Health Dashboard"),
          ],
        ),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildHealthMetric("Heart Rate", "72", "bpm", Icons.favorite, Colors.red),
                  SizedBox(width: 8),
                  _buildHealthMetric("BP", "120/80", "mmHg", Icons.monitor_heart, Colors.blue),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  _buildHealthMetric("Weight", "68", "kg", Icons.monitor_weight, Colors.orange),
                  SizedBox(width: 8),
                  _buildHealthMetric("Temp", "36.6", "°C", Icons.thermostat, Colors.purple),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _darkMode ? Colors.grey[700] : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Health Score",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _darkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.85,
                      backgroundColor: _darkMode ? Colors.grey[600] : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "85% - Excellent",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
          ElevatedButton(
            onPressed: _showVitalsInput,
            child: Text("Update Vitals"),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String title, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _darkMode ? Colors.grey[700] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkMode ? Colors.white : Colors.black,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: _darkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 8,
                color: _darkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVitalsInput() {
    final TextEditingController bpController = TextEditingController();
    final TextEditingController hrController = TextEditingController();
    final TextEditingController weightController = TextEditingController();
    final TextEditingController tempController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Record Vitals"),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildVitalInput("Blood Pressure", bpController, "120/80"),
              _buildVitalInput("Heart Rate", hrController, "72"),
              _buildVitalInput("Weight (kg)", weightController, "68"),
              _buildVitalInput("Temperature (°C)", tempController, "36.6"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              // Save vitals logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Vitals recorded successfully!")),
              );
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalInput(String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(),
          filled: true,
          fillColor: _darkMode ? Colors.grey[700] : Colors.grey[100],
        ),
        style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
        keyboardType: TextInputType.number,
      ),
    );
  }

  void _showMedicationTracker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.medication, color: Colors.green),
            SizedBox(width: 8),
            Text("Medication Tracker"),
          ],
        ),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMedicationCard("Metformin", "500mg", "2 times daily", "08:00, 20:00"),
              _buildMedicationCard("Aspirin", "81mg", "1 time daily", "08:00"),
              _buildMedicationCard("Vitamin D", "1000IU", "1 time daily", "12:00"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
          ElevatedButton(
            onPressed: _showMedicationInput,
            child: Text("Add Medication"),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(String name, String dosage, String frequency, String times) {
    return Card(
      color: _darkMode ? Colors.grey[700] : Colors.white,
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.medication, color: Colors.green),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$dosage - $frequency"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(times.split(',')[0], style: TextStyle(fontSize: 12)),
            if (times.split(',').length > 1)
              Text(times.split(',')[1], style: TextStyle(fontSize: 12)),
          ],
        ),
        onTap: () {
          // Mark as taken
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Marked $name as taken")),
          );
        },
      ),
    );
  }

  void _showMedicationInput() {
    // Implementation for adding new medication
  }

  void _showFirstAid() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("First Aid Guide"),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildFirstAidItem("CPR", "30 chest compressions, 2 breaths"),
              _buildFirstAidItem("Choking", "5 back blows, 5 abdominal thrusts"),
              _buildFirstAidItem("Bleeding", "Apply direct pressure"),
              _buildFirstAidItem("Burns", "Cool with running water for 20 min"),
              _buildFirstAidItem("Fracture", "Immobilize, don't move"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstAidItem(String title, String description) {
    return ListTile(
      leading: Icon(Icons.emergency, color: Colors.red),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(description),
      onTap: () {
        _messageController.text = "Tell me about first aid for $title";
        _sendMessage();
        Navigator.pop(context);
      },
    );
  }

  void _findDoctors() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Find Doctors Nearby"),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDoctorCard("Dr. Smith", "Cardiologist", "4.8", "2 km away"),
              _buildDoctorCard("Dr. Johnson", "General Physician", "4.6", "1 km away"),
              _buildDoctorCard("Dr. Williams", "Dermatologist", "4.9", "3 km away"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              // Open maps or call functionality
            },
            child: Text("View All Doctors"),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(String name, String specialty, String rating, String distance) {
    return Card(
      color: _darkMode ? Colors.grey[700] : Colors.white,
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(specialty),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                Text(rating, style: TextStyle(fontSize: 12)),
              ],
            ),
            Text(distance, style: TextStyle(fontSize: 10)),
          ],
        ),
        onTap: () {
          // Show doctor details or initiate call
        },
      ),
    );
  }

  void _showVitalsTracker() {
    // Implementation for detailed vitals tracking
  }

  void _showAppointments() {
    // Implementation for appointment management
  }

  void _showHealthRecords() {
    // Implementation for health records
  }

  void _findHospitals() {
    // Implementation for finding hospitals
  }

  void _showSettings() {
    // Implementation for app settings
  }



  void _showSymptomsInput() {
    // Implementation for symptoms input
  }

  void _scheduleAppointment() {
    // Implementation for appointment scheduling
  }

  // Keep existing methods for emergency dialog, symptoms checker, etc.
  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            SizedBox(width: 8),
            Text("Emergency Contacts"),
          ],
        ),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🚑 Emergency Contacts:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _darkMode ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '• Ambulance: 102 (India-wide)\n'
                    '• Police: 100\n'
                    '• Fire Brigade: 101\n'
                    '• Women Helpline: 1091\n'
                    '• Disaster Management: 108\n'
                    '• Child Helpline: 1098\n'
                    '• National Emergency Number: 112\n\n'
                    'For life-threatening emergencies, call local emergency number immediately!',
                style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              const url = 'tel:911';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
            child: Text('Call Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSymptomsChecker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Symptoms Checker"),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildSymptomCategory('General Symptoms', ['Fever', 'Fatigue', 'Weight loss', 'Weight gain']),
              _buildSymptomCategory('Head & Neck', ['Headache', 'Dizziness', 'Sore throat', 'Vision problems']),
              _buildSymptomCategory('Chest & Heart', ['Chest pain', 'Palpitations', 'Shortness of breath', 'Cough']),
              _buildSymptomCategory('Abdomen', ['Abdominal pain', 'Nausea', 'Diarrhea', 'Constipation']),
              _buildSymptomCategory('Extremities', ['Joint pain', 'Swelling', 'Muscle weakness', 'Numbness']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomCategory(String title, List<String> symptoms) {
    return ExpansionTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _darkMode ? Colors.white : Colors.black,
        ),
      ),
      children: symptoms.map((symptom) => ListTile(
        title: Text(symptom, style: TextStyle(color: _darkMode ? Colors.white : Colors.black)),
        onTap: () {
          Navigator.pop(context);
          _messageController.text = "I have $symptom";
          _sendMessage();
        },
      )).toList(),
    );
  }

  void _showMedicationInfo() {
    final TextEditingController medicationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Medication Information"),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: medicationController,
              decoration: InputDecoration(
                hintText: 'Enter medication name',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: _darkMode ? Colors.grey[700] : Colors.grey[100],
              ),
              style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (medicationController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _messageController.text = "Tell me about ${medicationController.text.trim()}";
                  _sendMessage();
                }
              },
              child: Text('Get Info'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHealthTips() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Health Tips"),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHealthTipCard('💧 Stay Hydrated', 'Drink at least 8 glasses of water daily'),
              _buildHealthTipCard('🏃 Exercise Regularly', '30 minutes of moderate activity daily'),
              _buildHealthTipCard('🥗 Eat Balanced Diet', 'Include fruits, vegetables, and whole grains'),
              _buildHealthTipCard('😴 Get Enough Sleep', '7-9 hours of quality sleep each night'),
              _buildHealthTipCard('🧘 Manage Stress', 'Practice mindfulness or meditation'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTipCard(String title, String description) {
    return Card(
      color: _darkMode ? Colors.grey[700] : Colors.white,
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _darkMode ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: _darkMode ? Colors.white70 : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Chat History"),
        backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
        content: SizedBox(
          width: double.maxFinite,
          child: _messages.isEmpty
              ? Center(child: Text('No chat history available', style: TextStyle(color: _darkMode ? Colors.white : Colors.black)))
              : ListView.builder(
            shrinkWrap: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: message.isUser ? Colors.blue.shade100 : Colors.green.shade100,
                  child: Icon(message.isUser ? Icons.person : Icons.medical_services, color: message.isUser ? Colors.blue : Colors.green),
                ),
                title: Text(
                  message.text.length > 30 ? '${message.text.substring(0, 30)}...' : message.text,
                  style: TextStyle(color: _darkMode ? Colors.white : Colors.black),
                ),
                subtitle: Text(
                  DateFormat('MMM d, h:mm a').format(message.timestamp),
                  style: TextStyle(color: _darkMode ? Colors.white60 : Colors.black54),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _animationController.dispose();
    super.dispose();
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final File? image;
  final Uint8List? imageBytes;
  final DateTime timestamp;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.image,
    this.imageBytes,
    required this.timestamp,
  });

  ImageProvider _getImageProvider() {
    if (imageBytes != null) {
      return MemoryImage(imageBytes!);
    } else if (image != null) {
      return FileImage(image!);
    }
    throw Exception('No image provided');
  }

  @override
  Widget build(BuildContext context) {
    final bool darkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  margin: EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    child: Icon(Icons.medical_services, size: 16),
                    radius: 12,
                    backgroundColor: Colors.green.shade100,
                  ),
                ),
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUser
                      ? (darkMode ? Colors.blue[800] : Colors.blue)
                      : (darkMode ? Colors.grey[800] : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(isUser ? 12 : 0),
                    bottomRight: Radius.circular(isUser ? 0 : 12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (image != null || imageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image(
                            image: _getImageProvider(),
                            width: 200,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Text(
                      text,
                      style: TextStyle(
                        color: isUser ? Colors.white : (darkMode ? Colors.white : Colors.black),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('h:mm a').format(timestamp),
                      style: TextStyle(
                        color: isUser ? Colors.white70 : (darkMode ? Colors.white60 : Colors.black54),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUser)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  child: CircleAvatar(
                    child: Icon(Icons.person, size: 16),
                    radius: 12,
                    backgroundColor: Colors.blue.shade100,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  final String text;

  const TypingIndicator({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 8,
            width: 8,
            margin: EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            height: 8,
            width: 8,
            margin: EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}