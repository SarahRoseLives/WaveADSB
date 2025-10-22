// ui/configure/feeds.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/models/port_config.dart';
import 'package:waveadsb/services/adsb_service.dart'; // 1. IMPORT ADSB SERVICE
import 'package:waveadsb/services/settings_service.dart';

class ConfigurePortsScreen extends StatelessWidget {
  const ConfigurePortsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settingsService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Configure Feeds'),
          ),
          body: settingsService.ports.isEmpty
              ? _buildEmptyState()
              : _buildPortList(context, settingsService),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              _showAddPortDialog(context, settingsService);
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 60, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'No Feeds Configured',
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(height: 10),
          Text(
            'Click the "+" button to add a new feed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPortList(BuildContext context, SettingsService settingsService) {
    return ListView.builder(
      itemCount: settingsService.ports.length,
      itemBuilder: (context, index) {
        final port = settingsService.ports[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ListTile(
            leading: const Icon(Icons.lan),
            title: Text(port.name),
            subtitle: Text('SBS-1 Feed (TCP): ${port.host}:${port.port}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                _showDeleteConfirmation(context, settingsService, port);
              },
            ),
            onTap: () {
              _showAddPortDialog(
                context,
                settingsService,
                existingPort: port,
                index: index,
              );
            },
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, // This is the main screen's context
      SettingsService service,
      PortConfig port) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // ctx is the dialog's context
        title: const Text('Delete Feed?'),
        content: Text('Are you sure you want to delete "${port.name}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
            onPressed: () {
              service.removePort(port);

              // 3. TELL ADSB SERVICE TO RE-CONNECT
              context.read<AdsbService>().connectToFeeds();

              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showAddPortDialog(
    BuildContext context, // This is the main screen's context
    SettingsService settingsService, {
    PortConfig? existingPort,
    int? index,
  }) {
    final bool isEditing = existingPort != null;
    final nameController =
        TextEditingController(text: isEditing ? existingPort.name : '');
    final hostController = TextEditingController(
        text: isEditing ? existingPort.host : '127.0.0.1');
    final portController = TextEditingController(
        text: isEditing ? existingPort.port.toString() : '30003');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        // ctx is the dialog's context
        return AlertDialog(
          title: Text(isEditing ? 'Edit Feed' : 'Add SBS-1 (TCP) Feed'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name / Alias'),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Please enter a name'
                      : null,
                ),
                TextFormField(
                  controller: hostController,
                  decoration: const InputDecoration(
                      labelText: 'IP Address / Hostname'),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Please enter a host'
                      : null,
                ),
                TextFormField(
                  controller: portController,
                  decoration: const InputDecoration(labelText: 'Port Number'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a port';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Must be a valid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newPort = PortConfig(
                    name: nameController.text,
                    type: PortType.sbsFeed_TCP,
                    host: hostController.text,
                    port: int.parse(portController.text),
                  );

                  if (isEditing) {
                    settingsService.updatePort(index!, newPort);
                  } else {
                    settingsService.addPort(newPort);
                  }

                  // 4. TELL ADSB SERVICE TO RE-CONNECT
                  context.read<AdsbService>().connectToFeeds();

                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}