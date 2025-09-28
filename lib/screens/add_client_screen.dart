import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/client_service.dart';

class AddClientScreen extends StatefulWidget {
  final Client? client;

  const AddClientScreen({super.key, this.client});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  // All the controllers needed
  late TextEditingController _idController;
  late TextEditingController _taxpayerNameController;
  late TextEditingController _spouseNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isMarriedFiling = false;

  @override
  void initState() {
    super.initState();

    // Initialize all controllers
    _idController = TextEditingController(text: widget.client?.id ?? '');
    _taxpayerNameController = TextEditingController(text: widget.client?.taxpayerName ?? '');
    _spouseNameController = TextEditingController(text: widget.client?.spouseName ?? '');
    _emailController = TextEditingController(text: widget.client?.email ?? '');
    _phoneController = TextEditingController(text: widget.client?.phone ?? '');
    _addressController = TextEditingController(text: widget.client?.address ?? '');

    // Set married filing status
    _isMarriedFiling = widget.client?.isMarriedFiling ?? false;
  }

  @override
  void dispose() {
    // Dispose all controllers
    _idController.dispose();
    _taxpayerNameController.dispose();
    _spouseNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newClient = Client(
        id: _idController.text.trim(),
        taxpayerName: _taxpayerNameController.text.trim(),
        spouseName: _isMarriedFiling ? _spouseNameController.text.trim() : null,
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        isMarriedFiling: _isMarriedFiling,
      );

      if (widget.client != null) {
        // Edit mode: update existing client
        await ClientService.updateClient(widget.client!.id, newClient);
      } else {
        // Add mode: create new client
        await ClientService.addClient(newClient);
      }

      Navigator.pop(context, newClient.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving client: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? 'Add Client' : 'Edit Client'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: "Client ID",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 16),

              // Married Filing Toggle
              Card(
                child: SwitchListTile(
                  title: const Text("Married Filing Joint/Separate"),
                  subtitle: const Text("Enable if this client has a spouse"),
                  value: _isMarriedFiling,
                  onChanged: (value) {
                    setState(() {
                      _isMarriedFiling = value;
                      if (!value) {
                        _spouseNameController.clear();
                      }
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _taxpayerNameController,
                decoration: const InputDecoration(
                  labelText: "Taxpayer Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 16),

              // Spouse Name (only shown if married filing)
              if (_isMarriedFiling) ...[
                TextFormField(
                  controller: _spouseNameController,
                  decoration: const InputDecoration(
                    labelText: "Spouse Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: _isMarriedFiling
                      ? (value) => value == null || value.isEmpty ? "Required for married filing" : null
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email (Optional)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone (Optional)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: "Address (Optional)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveClient,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Save Client"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}