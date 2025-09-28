import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';

class ClientService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'clients';

  // Add a new client
  static Future<void> addClient(Client client) async {
    try {
      await _db.collection(_collection).add(client.toMap());
    } catch (e) {
      throw Exception('Failed to add client: $e');
    }
  }

  // Get all clients
  static Future<List<Client>> getClients() async {
    try {
      final querySnapshot = await _db
          .collection(_collection)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => Client.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get clients: $e');
    }
  }

  // Get all clients as a stream
  static Stream<List<Client>> getClientsStream() {
    return _db
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Client.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Get a single client by ID
  static Future<Client?> getClient(String clientId) async {
    try {
      final doc = await _db.collection(_collection).doc(clientId).get();
      if (doc.exists) {
        return Client.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get client: $e');
    }
  }

  // Update a client
  static Future<void> updateClient(String clientId, Client client) async {
    try {
      await _db.collection(_collection).doc(clientId).update(client.toMap());
    } catch (e) {
      throw Exception('Failed to update client: $e');
    }
  }

  // Delete a client
  static Future<void> deleteClient(String clientId) async {
    try {
      await _db.collection(_collection).doc(clientId).delete();
    } catch (e) {
      throw Exception('Failed to delete client: $e');
    }
  }

  // Search clients by name
  static Future<List<Client>> searchClients(String searchTerm) async {
    try {
      final querySnapshot = await _db
          .collection(_collection)
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThan: searchTerm + 'z')
          .get();

      return querySnapshot.docs
          .map((doc) => Client.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to search clients: $e');
    }
  }
}