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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _selectedUsers = [];
  List<UserProfile> _availableUsers = [];
  bool _isLoading = false;
  StreamSubscription? _usersSubscription;

  @override
  void initState() {
    super.initState();
    _databaseService = _getIt.get<DatabaseService>();
    _alertService = _getIt.get<AlertService>();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Cancel any existing subscription
      await _usersSubscription?.cancel();
      
      // Get users from the chat list
      final usersStream = _databaseService.getUserProfiles();
      _usersSubscription = usersStream.listen(
        (users) {
          if (!mounted) return;
          setState(() {
            _availableUsers = users;
            _isLoading = false;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _alertService.showToast(
            text: "Error loading users: $error",
            icon: Icons.error,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _alertService.showToast(
        text: "Error loading users: $e",
        icon: Icons.error,
      );
    }
  }

  Future<void> _createGroup() async {
    if (_nameController.text.isEmpty) {
      _alertService.showToast(
        text: "Please enter a group name",
        icon: Icons.error,
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      _alertService.showToast(
        text: "Please select at least one participant",
        icon: Icons.error,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _databaseService.createGroup(
        name: _nameController.text,
        description: _descriptionController.text,
        participants: _selectedUsers,
      );

      if (!mounted) return;
      
      if (result.isSuccess) {
        _alertService.showToast(
          text: "Group created successfully!",
          icon: Icons.check,
        );
        Navigator.pop(context);
      } else {
        _alertService.showToast(
          text: "Error creating group: ${result.error}",
          icon: Icons.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _alertService.showToast(
        text: "Error creating group: $e",
        icon: Icons.error,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Participants',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _availableUsers.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  "No users available",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Start chatting with users first",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _availableUsers.length,
                            itemBuilder: (context, index) {
                              final user = _availableUsers[index];
                              return CheckboxListTile(
                                title: Text(user.name),
                                subtitle: Text(user.email ?? ''),
                                value: _selectedUsers.contains(user.uid),
                                onChanged: (bool? value) {
                                  if (!mounted) return;
                                  setState(() {
                                    if (value == true) {
                                      _selectedUsers.add(user.uid);
                                    } else {
                                      _selectedUsers.remove(user.uid);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _createGroup,
                    child: const Text('Create Group'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usersSubscription?.cancel();
    super.dispose();
  }
} 