import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'custom_drawer.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepOrange,
      ),
      drawer: CustomDrawer(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            return Container(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Welcome, ${userData?['full_name'] ?? 'Admin'}!',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.bold,
                                )),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCard(
                              'Users', Icons.person, _fetchUserCount),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildCard(
                              'PDFs', Icons.picture_as_pdf, _fetchPdfCount),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            Container(
                              constraints: BoxConstraints.expand(height: 50),
                              child: TabBar(
                                tabs: [
                                  Tab(text: "Recent PDFs"),
                                  Tab(text: "Recent Users"),
                                ],
                                labelColor: Colors.deepOrange,
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: Colors.deepOrange,
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildRecentPdfsList(),
                                  _buildRecentUsersList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildCard(
      String title, IconData icon, Future<int> Function() countFuture) {
    return FutureBuilder<int>(
      future: countFuture(),
      builder: (context, snapshot) {
        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: Colors.deepOrange),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.hasData ? snapshot.data.toString() : '...',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int> _fetchUserCount() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('users').get();
    return snapshot.size;
  }

  Future<int> _fetchPdfCount() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('pdfs').get();
    return snapshot.size;
  }

  Widget _buildRecentPdfsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pdfs')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var pdf = snapshot.data!.docs[index];
            return ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.deepOrange),
              title: Text(pdf['title'] ?? 'No Title'),
              subtitle: Text(pdf['fileName'] ?? 'No File Name'),
              trailing: Text(pdf['timestamp'] != null
                  ? (pdf['timestamp'] as Timestamp)
                      .toDate()
                      .toString()
                      .split(' ')[0]
                  : 'No Date'),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var user = snapshot.data!.docs[index];
            return ListTile(
              leading: Icon(Icons.person, color: Colors.deepOrange),
              title:
                  Text('${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
              subtitle: Text(user['deviceUniqueId'] ?? 'No Device ID'),
              trailing: Text(user['timestamp'] != null
                  ? (user['timestamp'] as Timestamp)
                      .toDate()
                      .toString()
                      .split(' ')[0]
                  : 'No Date'),
            );
          },
        );
      },
    );
  }
}
