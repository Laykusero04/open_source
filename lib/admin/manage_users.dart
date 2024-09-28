import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_service.dart';

class ManageUsers extends StatefulWidget {
  const ManageUsers({Key? key}) : super(key: key);

  @override
  State<ManageUsers> createState() => _ManageUsersState();
}

class _ManageUsersState extends State<ManageUsers>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Users',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepOrange,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4.0,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: 'Users'),
            Tab(text: 'Admins'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(),
          _buildAdminList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(isAdmin: true),
        icon: Icon(Icons.add),
        label: Text('Add Admin'),
        backgroundColor: Colors.orange[700],
      ),
    );
  }

  Widget _buildUserList() {
    return Container(
      color: Colors.white,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              return _buildInteractiveCard(userId, user, false);
            },
          );
        },
      ),
    );
  }

  Widget _buildAdminList() {
    return Container(
      color: Colors.white,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('admin').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final admins = snapshot.data!.docs;

          return ListView.builder(
            itemCount: admins.length,
            itemBuilder: (context, index) {
              final admin = admins[index].data() as Map<String, dynamic>;
              final adminId = admins[index].id;
              return _buildInteractiveCard(adminId, admin, true);
            },
          );
        },
      ),
    );
  }

  Widget _buildInteractiveCard(
      String id, Map<String, dynamic> data, bool isAdmin) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin ? Colors.orange[700] : Colors.blue[700],
          child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person,
              color: Colors.white),
        ),
        title: Text(isAdmin
            ? data['full_name']
            : '${data['firstName']} ${data['lastName']}'),
        subtitle: Text(isAdmin ? 'Admin' : 'User'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Device ID: ${isAdmin ? data['email'] : data['deviceUniqueId']}'),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(
                        Icons.edit,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Edit',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                      onPressed: () =>
                          _showEditDialog(id, data, isAdmin: isAdmin),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => _showDeleteDialog(id, isAdmin: isAdmin),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog({required bool isAdmin}) {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isAdmin ? 'Add Admin' : 'Add User'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Full Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a name' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter an email' : null,
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a password' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Add'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
              onPressed: () => _addUser(isAdmin),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(String id, Map<String, dynamic> data,
      {required bool isAdmin}) {
    _nameController.text = isAdmin
        ? data['full_name']
        : '${data['firstName']} ${data['lastName']}';
    _emailController.text = isAdmin ? data['email'] : data['deviceUniqueId'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit ${isAdmin ? 'Admin' : 'User'}'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Full Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a name' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: isAdmin ? 'Email' : 'Device ID',
                    filled: !isAdmin,
                    fillColor: Colors.grey[100],
                  ),
                  enabled: isAdmin, // This makes the field read-only for users
                  validator: (value) =>
                      value!.isEmpty ? 'This field cannot be empty' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Save'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
              onPressed: () => _updateUser(id, isAdmin),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(String id, {required bool isAdmin}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text(
              'Are you sure you want to delete this ${isAdmin ? 'admin' : 'user'}?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _deleteUser(id, isAdmin),
            ),
          ],
        );
      },
    );
  }

  void _addUser(bool isAdmin) async {
    if (_formKey.currentState!.validate()) {
      try {
        final userCredential =
            await _firebaseService.createUserWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );

        final userData = isAdmin
            ? {
                'full_name': _nameController.text,
                'email': _emailController.text,
                'role': 'admin',
              }
            : {
                'firstName': _nameController.text.split(' ').first,
                'lastName': _nameController.text.split(' ').last,
                'deviceUniqueId': _emailController.text,
              };

        await FirebaseFirestore.instance
            .collection(isAdmin ? 'admin' : 'users')
            .doc(userCredential.user!.uid)
            .set(userData);

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${isAdmin ? 'Admin' : 'User'} added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error adding ${isAdmin ? 'admin' : 'user'}: $e')),
        );
      }
    }
  }

  void _updateUser(String id, bool isAdmin) async {
    if (_formKey.currentState!.validate()) {
      try {
        final userData = isAdmin
            ? {
                'full_name': _nameController.text,
                'email': _emailController.text,
              }
            : {
                'firstName': _nameController.text.split(' ').first,
                'lastName': _nameController.text.split(' ').last,
                'deviceUniqueId': _emailController.text,
              };

        await FirebaseFirestore.instance
            .collection(isAdmin ? 'admin' : 'users')
            .doc(id)
            .update(userData);

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${isAdmin ? 'Admin' : 'User'} updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error updating ${isAdmin ? 'admin' : 'user'}: $e')),
        );
      }
    }
  }

  void _deleteUser(String id, bool isAdmin) async {
    try {
      await FirebaseFirestore.instance
          .collection(isAdmin ? 'admin' : 'users')
          .doc(id)
          .delete();

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${isAdmin ? 'Admin' : 'User'} deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error deleting ${isAdmin ? 'admin' : 'user'}: $e')),
      );
    }
  }
}
