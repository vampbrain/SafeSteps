import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, String>> _emergencyContacts = [];
  late SharedPreferences _prefs;
  String _userName = '';
  String _userPhone = '';

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    setState(() => _isLoading = true);
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadUserData();
      _loadEmergencyContacts();
    } catch (e) {
      print('Error initializing profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadUserData() {
    _userName = _prefs.getString('user_name') ?? '';
    _userPhone = _prefs.getString('user_phone') ?? '';
    setState(() {});
  }

  Future<void> _saveUserData() async {
    await _prefs.setString('user_name', _userName);
    await _prefs.setString('user_phone', _userPhone);
  }

  void _loadEmergencyContacts() {
    final contactsJson = _prefs.getString('emergency_contacts');
    if (contactsJson != null) {
      final List<dynamic> decoded = json.decode(contactsJson);
      _emergencyContacts =
          decoded.map((contact) => Map<String, String>.from(contact)).toList();
      setState(() {});
    }
  }

  Future<void> _saveEmergencyContacts() async {
    await _prefs.setString(
        'emergency_contacts', json.encode(_emergencyContacts));
  }

  Future<void> _updateUserProfile() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _userName = _nameController.text;
      _userPhone = _phoneController.text;
    });

    await _saveUserData();
    _nameController.clear();
    _phoneController.clear();
    Navigator.pop(context);
  }

  Future<void> _addEmergencyContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _emergencyContacts.add({
        'name': _nameController.text,
        'phone': _phoneController.text,
      });
    });

    await _saveEmergencyContacts();
    _nameController.clear();
    _phoneController.clear();
    Navigator.pop(context);
  }

  void _showEditProfileDialog() {
    _nameController.text = _userName;
    _phoneController.text = _userPhone;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _updateUserProfile,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addEmergencyContact,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeContact(int index) async {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
    await _saveEmergencyContacts();
  }

  Widget _buildUserSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const CircleAvatar(
          radius: 40,
          child: Icon(Icons.person, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          _userName.isEmpty ? 'Add Your Profile' : _userName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (_userPhone.isNotEmpty)
          Text(
            _userPhone,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showEditProfileDialog,
          icon: const Icon(Icons.edit),
          label: Text(_userName.isEmpty ? 'Add Profile' : 'Edit Profile'),
        ),
      ],
    );
  }

  Widget _buildEmergencyContactsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Emergency Contacts',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showAddContactDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Contact'),
              ),
            ],
          ),
        ),
        if (_emergencyContacts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No emergency contacts added yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _emergencyContacts.length,
            itemBuilder: (context, index) {
              final contact = _emergencyContacts[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(contact['name']!),
                subtitle: Text(contact['phone']!),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeContact(index),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: _buildUserSection(),
            ),
            const Divider(),
            _buildEmergencyContactsList(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
