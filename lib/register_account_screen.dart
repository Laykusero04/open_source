import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterAccountScreen extends StatefulWidget {
  final String deviceUniqueId;
  final bool isUpdate;

  const RegisterAccountScreen({
    Key? key,
    required this.deviceUniqueId,
    required this.isUpdate,
  }) : super(key: key);

  @override
  _RegisterAccountScreenState createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  late Future<void> _loadUserDataFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserDataFuture = _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (widget.isUpdate) {
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('deviceUniqueId', isEqualTo: widget.deviceUniqueId)
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        final userData = result.docs.first.data() as Map<String, dynamic>;
        _firstNameController.text = userData['firstName'] ?? '';
        _lastNameController.text = userData['lastName'] ?? '';
      }
    }
  }

  Future<void> _saveAccount() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final usersCollection = FirebaseFirestore.instance.collection('users');
        final QuerySnapshot existingUser = await usersCollection
            .where('deviceUniqueId', isEqualTo: widget.deviceUniqueId)
            .limit(1)
            .get();

        if (existingUser.docs.isNotEmpty) {
          await existingUser.docs.first.reference.update({
            'firstName': _firstNameController.text,
            'lastName': _lastNameController.text,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          await usersCollection.add({
            'deviceUniqueId': widget.deviceUniqueId,
            'firstName': _firstNameController.text,
            'lastName': _lastNameController.text,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        _showSnackBar(
          widget.isUpdate
              ? 'Account updated successfully'
              : 'Account registered successfully',
          Colors.green,
        );
        Navigator.pop(context);
      } catch (e) {
        _showSnackBar('Error saving account: $e', Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.isUpdate ? 'Update Account' : 'Register Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _loadUserDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                ),
              );
            }
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller:
                            TextEditingController(text: widget.deviceUniqueId),
                        labelText: 'Device Unique ID',
                        readOnly: true,
                        icon: Icons.devices,
                      ),
                      SizedBox(height: 24),
                      _buildTextField(
                        controller: _firstNameController,
                        labelText: 'First Name',
                        validator: (value) => value!.isEmpty
                            ? 'Please enter your first name'
                            : null,
                        icon: Icons.person,
                      ),
                      SizedBox(height: 24),
                      _buildTextField(
                        controller: _lastNameController,
                        labelText: 'Last Name',
                        validator: (value) => value!.isEmpty
                            ? 'Please enter your last name'
                            : null,
                        icon: Icons.person_outline,
                      ),
                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveAccount,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.deepOrange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                widget.isUpdate
                                    ? 'Update Account'
                                    : 'Register Account',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    bool readOnly = false,
    String? Function(String?)? validator,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      style: TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.deepOrange, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}
