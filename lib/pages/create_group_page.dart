import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../models/user_profile.dart';
import '../services/database_services.dart';
import '../services/alert_service.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({Key? key}) : super(key: key);

  @override
  _CreateGroupPageState createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final GetIt _getIt = GetIt.instance;
  late DatabaseService _databaseService;
  late AlertService _alertService;
  final TextEditingController _groupNameController = TextEditingController();
  List<UserProfile> _selectedUsers = [];
  List<UserProfile> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _databaseService = _getIt.get<DatabaseService>();
    _alertService = _getIt.get<AlertService>();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _databaseService.getUserProfiles().first;
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _alertService.showToast(
        text: "Error loading users",
        icon: Icons.error,
      );
    }
  }

  void _showUserSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Users'),
        content: SizedBox(
          width: double.maxFinite,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allUsers.length,
                  itemBuilder: (context, index) {
                    final user = _allUsers[index];
                    final isSelected = _selectedUsers.contains(user);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedUsers.add(user);
                          } else {
                            _selectedUsers.remove(user);
                          }
                        });
                      },
                      title: Text(user.name ?? 'Unknown User'),
                      subtitle: Text(user.email ?? ''),
                      secondary: CircleAvatar(
                        backgroundImage: user.pfpURL != null
                            ? NetworkImage(user.pfpURL!)
                            : null,
                        child: user.pfpURL == null
                            ? Text(user.name?[0].toUpperCase() ?? 'U')
                            : null,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.isEmpty) {
      _alertService.showToast(
        text: "Please enter a group name",
        icon: Icons.error,
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      _alertService.showToast(
        text: "Please select at least one user",
        icon: Icons.error,
      );
      return;
    }

    try {
      final result = await _databaseService.createGroup(
        name: _groupNameController.text,
        description: '',  // Optional description
        participants: _selectedUsers.map((user) => user.uid).toList(),
      );

      if (result.isSuccess) {
        _alertService.showToast(
          text: "Group created successfully",
          icon: Icons.check,
        );
        Navigator.pop(context);
      } else {
        _alertService.showToast(
          text: "Failed to create group: ${result.error}",
          icon: Icons.error,
        );
      }
    } catch (e) {
      _alertService.showToast(
        text: "Error creating group",
        icon: Icons.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0XFFA65B17),
        title: const Text('New Group', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _selectedUsers.isEmpty ? null : _createGroup,
            child: Text(
              'Create',
              style: TextStyle(
                color: _selectedUsers.isEmpty ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.camera_alt, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      hintText: 'Group name',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.grey),
                const SizedBox(width: 16),
                Text(
                  '${_selectedUsers.length} participants',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: _databaseService.getUserProfiles(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUsers.contains(user);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedUsers.add(user);
                          } else {
                            _selectedUsers.remove(user);
                          }
                        });
                      },
                      title: Text(user.name ?? 'Unknown User'),
                      subtitle: Text(user.email ?? ''),
                      secondary: CircleAvatar(
                        backgroundImage: user.pfpURL != null
                            ? NetworkImage(user.pfpURL!)
                            : null,
                        child: user.pfpURL == null
                            ? Text(user.name?[0].toUpperCase() ?? 'U')
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
} 