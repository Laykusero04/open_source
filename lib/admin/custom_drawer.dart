import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_source_pdf/admin/dashboard.dart';
import 'package:open_source_pdf/admin/manage_folders.dart';
import 'package:open_source_pdf/home_screen.dart';
import 'manage_users.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String userId = currentUser?.uid ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('admin')
                .doc(userId)
                .get(),
            builder: (BuildContext context,
                AsyncSnapshot<DocumentSnapshot> snapshot) {
              if (snapshot.hasError) {
                return DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.deepOrange[400],
                  ),
                  child: Center(
                    child: Text(
                      'Error loading user data',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.done) {
                Map<String, dynamic> data =
                    snapshot.data!.data() as Map<String, dynamic>;
                String fullName = data['full_name'] ?? 'Admin';

                return DrawerHeader(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepOrange, Colors.orange[300]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Navigate to Profile page or settings
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.orange[100],
                              child: Icon(
                                Icons.person,
                                size: 35,
                                color: Colors.deepOrange,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              // Ensures text is responsive and fits
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OpenSource Admin',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Text(
                                    fullName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      overflow: TextOverflow
                                          .ellipsis, // Fixes overflow issue
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.deepOrange[400],
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard_rounded,
                  text: 'Dashboard',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => DashboardPage()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.picture_as_pdf_rounded,
                  text: 'Manage PDFs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ManageFolders(currentUserId: userId),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.people_alt_rounded,
                  text: 'Manage Users',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ManageUsers()),
                    );
                  },
                ),
                Divider(
                  thickness: 1.2,
                  color: Colors.grey[300],
                ),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  text: 'Logout',
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
      {required IconData icon,
      required String text,
      required GestureTapCallback onTap}) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.grey[800], // Adjusted to a lighter shade to match theme
        size: 28,
      ),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.grey[900], // Ensures text is more visible
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
      horizontalTitleGap: 12.0,
      hoverColor: Colors.orange[50], // Light hover effect
      splashColor: Colors.deepOrange.withOpacity(0.3), // Splash animation
    );
  }
}
