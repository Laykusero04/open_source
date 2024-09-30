import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_source_pdf/admin/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'folder_list_screen.dart';
import 'pdf_list_screen.dart';

enum AccessStatus { notRequested, pending, approved }

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _userDataFuture;
  AccessStatus _accessStatus = AccessStatus.notRequested;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _getUserData();
  }

  Future<Map<String, dynamic>> _getUserData() async {
    final String deviceUid = await _getDeviceUniqueId();
    await _checkAccessStatus(deviceUid);
    return {
      'deviceUid': deviceUid,
    };
  }

  Future<void> _checkAccessStatus(String deviceUid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(deviceUid)
        .get();

    if (userDoc.exists) {
      setState(() {
        _accessStatus = AccessStatus.approved;
      });
    } else {
      final pendingDoc = await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(deviceUid)
          .get();

      if (pendingDoc.exists) {
        setState(() {
          _accessStatus = AccessStatus.pending;
        });
      } else {
        // Automatically approve access if the device ID is not in pending_users
        await _approveAccess(deviceUid);
      }
    }
  }

  Future<void> _approveAccess(String deviceUid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(deviceUid).set({
        'deviceUniqueId': deviceUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'firstName': 'New',
        'lastName': 'User',
      });

      setState(() {
        _accessStatus = AccessStatus.approved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Access automatically approved.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving access: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<String> _getDeviceUniqueId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final prefs = await SharedPreferences.getInstance();
    String? storedDeviceId = prefs.getString('device_uid');

    if (storedDeviceId != null && storedDeviceId.isNotEmpty) {
      return storedDeviceId;
    }

    String deviceId = '';
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id ?? '';
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
      }

      if (deviceId.isEmpty) {
        deviceId = DateTime.now().millisecondsSinceEpoch.toString() +
            '-' +
            UniqueKey().toString();
      }

      await prefs.setString('device_uid', deviceId);
      return deviceId;
    } catch (e) {
      print('Error getting device info: $e');
      String fallbackId = DateTime.now().millisecondsSinceEpoch.toString() +
          '-fallback-' +
          UniqueKey().toString();
      await prefs.setString('device_uid', fallbackId);
      return fallbackId;
    }
  }

  void _navigateToFolderList(String deviceUid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderListScreen(deviceUuid: deviceUid),
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
            const Text(
              'Device Unique ID',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              userData['deviceUid'],
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            _buildAccessStatusButton(userData['deviceUid']),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessStatusButton(String uid) {
    switch (_accessStatus) {
      case AccessStatus.notRequested:
      case AccessStatus.pending:
      case AccessStatus.approved:
        return _buildStatusButton('Access Approved', Colors.green, null);
    }
  }

  Widget _buildStatusButton(String text, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _navigateToFolderList(userData['deviceUid']),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.deepOrange,
          ),
          icon: const Icon(Icons.folder),
          label: const Text("Access PDFs", style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
