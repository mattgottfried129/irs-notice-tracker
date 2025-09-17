import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import 'client_detail_screen.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: dummyClients.length,
      itemBuilder: (context, index) {
        final client = dummyClients[index];
        return ListTile(
          title: Text(client.name),
          subtitle: Text(client.email),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientDetailScreen(client: client),
              ),
            );
          },
        );
      },
    );
  }
}
