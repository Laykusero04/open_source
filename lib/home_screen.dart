import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_source_pdf/admin/login.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pdf_list_screen.dart';
import 'register_account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _getUserData();
  }

  Future<Map<String, dynamic>> _getUserData() async {
    final String deviceUid = await _getOrGenerateUniqueId();
    final userDoc = await _getUserDocument(deviceUid);
    return {
      'deviceUid': deviceUid,
      'isRegistered': userDoc != null,
      'firstName': userDoc?['firstName'],
      'lastName': userDoc?['lastName'],
    };
  }

  Future<String> _getOrGenerateUniqueId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedUid = prefs.getString('device_uid');

      if (storedUid == null) {
        storedUid = Uuid().v4();
        await prefs.setString('device_uid', storedUid);
      }

      return storedUid;
    } catch (e) {
      print('Error accessing SharedPreferences: $e');
      return Uuid().v4();
    }
  }

  Future<DocumentSnapshot?> _getUserDocument(String deviceUid) async {
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection('users')
        .where('deviceUniqueId', isEqualTo: deviceUid)
        .limit(1)
        .get();

    if (result.docs.isNotEmpty) {
      return result.docs.first;
    }
    return null;
  }

  void _navigateToAccountScreen(String deviceUniqueId, bool isRegistered) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterAccountScreen(
          deviceUniqueId: deviceUniqueId,
          isUpdate: isRegistered,
        ),
      ),
    ).then((_) {
      // Refresh the user data when returning from the account screen
      setState(() {
        _userDataFuture = _getUserData();
      });
    });
  }

  void _navigateToPdfList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfListScreen(),
      ),
    );
  }

  void _copyDeviceUID(String uid) {
    Clipboard.setData(ClipboardData(text: uid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Device Unique ID copied to clipboard'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _userDataFuture,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('OpenSource',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.deepOrange,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.login, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.deepOrange, Colors.orange.shade300],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    else if (snapshot.hasError)
                      Expanded(
                        child: Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                        ),
                      )
                    else if (snapshot.hasData)
                      _buildContent(snapshot.data!)
                    else
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No user data available',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUserInfoCard(userData),
        const SizedBox(height: 20),
        _buildActionButtons(userData),
      ],
    );
  }

  Widget _buildUserInfoCard(Map<String, dynamic> userData) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Device Unique ID',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.deepOrange),
                  onPressed: () => _copyDeviceUID(userData['deviceUid']),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              userData['deviceUid'],
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            if (userData['isRegistered']) ...[
              const SizedBox(height: 20),
              const Text(
                'Registered User',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${userData['firstName']} ${userData['lastName']}',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _navigateToPdfList,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.deepOrange,
          ),
          icon: const Icon(Icons.list),
          label: const Text("PDF List", style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          onPressed: () => _navigateToAccountScreen(
            userData['deviceUid'],
            userData['isRegistered'],
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.deepOrange,
          ),
          icon: Icon(userData['isRegistered'] ? Icons.edit : Icons.account_box),
          label: Text(
            userData['isRegistered'] ? "Update Account" : "Register Account",
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
