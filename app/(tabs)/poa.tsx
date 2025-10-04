// app/(tabs)/poa.tsx
// POA Master screen - manage Power of Attorney records

import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  RefreshControl,
  Alert,
  TextInput
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { poaService, clientService } from '../../lib/api';
import { POARecord, Client } from '../../lib/types';

export default function POAScreen() {
  const [poaRecords, setPOARecords] = useState<POARecord[]>([]);
  const [clients, setClients] = useState<Client[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const router = useRouter();

  useEffect(() => {
    loadPOARecords();
  }, []);

  const loadPOARecords = async () => {
    try {
      const [poaData, clientData] = await Promise.all([
        poaService.getAll(),
        clientService.getAll()
      ]);

      console.log('Sample POA record:', poaData[0]); // DEBUG
      console.log('Sample client record:', clientData[0]); // DEBUG

      setPOARecords(poaData);
      setClients(clientData);
    } catch (error) {
      console.error('Error loading POA records:', error);
      Alert.alert('Error', 'Failed to load POA records');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const onRefresh = () => {
    setRefreshing(true);
    loadPOARecords();
  };

  const handleAddPOA = () => {
    router.push('/poa/add');
  };

  const handlePOAPress = (poa: POARecord) => {
    router.push({
      pathname: '/poa/[id]',
      params: { id: poa.id }
    });
  };

  const handleDeletePOA = (poa: POARecord) => {
    Alert.alert(
      'Delete POA',
      `Delete POA record for form ${poa.form}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await poaService.delete(poa.id);
              loadPOARecords();
            } catch (error) {
              Alert.alert('Error', 'Failed to delete POA record');
            }
          }
        }
      ]
    );
  };

  const getClientName = (clientId: string): string => {
    const client = clients.find(c => c.clientId === clientId || c.id === clientId);
    return client?.name || clientId;
  };

  const getFilteredPOAs = () => {
    if (!searchQuery.trim()) return poaRecords;

    const query = searchQuery.toLowerCase();
    return poaRecords.filter(poa =>
      poa.clientId.toLowerCase().includes(query) ||
      poa.form.toLowerCase().includes(query) ||
      getClientName(poa.clientId).toLowerCase().includes(query)
    );
  };

  const filteredPOAs = getFilteredPOAs();

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
        <Text style={styles.loadingText}>Loading POA records...</Text>
      </View>
    );
  }

  const renderPOA = ({ item }: { item: POARecord }) => {
    const clientName = getClientName(item.clientId);

    return (
      <TouchableOpacity
        style={styles.poaCard}
        onPress={() => handlePOAPress(item)}
      >
        <View style={styles.poaHeader}>
          <View style={styles.poaMain}>
            <Text style={styles.clientName}>{clientName}</Text>
            <Text style={styles.clientId}>{item.clientId}</Text>
          </View>
          <TouchableOpacity
            style={styles.deleteButton}
            onPress={() => handleDeletePOA(item)}
          >
            <Ionicons name="trash-outline" size={20} color="#F44336" />
          </TouchableOpacity>
        </View>

        <View style={styles.poaDetails}>
          <View style={styles.detailRow}>
            <Ionicons name="document-text" size={16} color="#666" />
            <Text style={styles.detailText}>Form: {item.form}</Text>
          </View>
          <View style={styles.detailRow}>
            <Ionicons name="calendar" size={16} color="#666" />
            <Text style={styles.detailText}>
              Period: {item.periodStart} - {item.periodEnd}
            </Text>
          </View>
        </View>

        <View style={styles.poaFlags}>
          {item.electronicCopy && (
            <View style={[styles.flag, { backgroundColor: '#4CAF50' }]}>
              <Ionicons name="cloud-done" size={12} color="#fff" />
              <Text style={styles.flagText}>Electronic</Text>
            </View>
          )}
          {item.cafVerified && (
            <View style={[styles.flag, { backgroundColor: '#2196F3' }]}>
              <Ionicons name="checkmark-circle" size={12} color="#fff" />
              <Text style={styles.flagText}>CAF Verified</Text>
            </View>
          )}
          {item.paperCopy && (
            <View style={[styles.flag, { backgroundColor: '#FF9800' }]}>
              <Ionicons name="document" size={12} color="#fff" />
              <Text style={styles.flagText}>Paper Copy</Text>
            </View>
          )}
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>POA Master</Text>
        <Text style={styles.headerSubtitle}>
          {poaRecords.length} record{poaRecords.length !== 1 ? 's' : ''}
        </Text>
      </View>

      {/* Search Bar */}
      <View style={styles.searchContainer}>
        <Ionicons name="search" size={20} color="#666" style={styles.searchIcon} />
        <TextInput
          style={styles.searchInput}
          placeholder="Search by client or form..."
          value={searchQuery}
          onChangeText={setSearchQuery}
        />
        {searchQuery.length > 0 && (
          <TouchableOpacity onPress={() => setSearchQuery('')}>
            <Ionicons name="close-circle" size={20} color="#666" />
          </TouchableOpacity>
        )}
      </View>

      {/* POA List */}
      {filteredPOAs.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Ionicons name="document-text-outline" size={64} color="#ccc" />
          <Text style={styles.emptyTitle}>
            {searchQuery ? 'No matching POAs' : 'No POA Records'}
          </Text>
          <Text style={styles.emptySubtitle}>
            {searchQuery
              ? 'Try a different search term'
              : 'Add POA records to track Power of Attorney authorizations'
            }
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredPOAs}
          renderItem={renderPOA}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
          }
        />
      )}

      {/* FAB */}
      <TouchableOpacity style={styles.fab} onPress={handleAddPOA}>
        <Ionicons name="add" size={32} color="#fff" />
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
  header: {
    padding: 20,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  headerSubtitle: {
    fontSize: 14,
    color: '#666',
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    marginHorizontal: 16,
    marginVertical: 12,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  searchIcon: {
    marginRight: 8,
  },
  searchInput: {
    flex: 1,
    paddingVertical: 12,
    fontSize: 16,
    color: '#333',
  },
  listContent: {
    padding: 16,
  },
  poaCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  poaHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  poaMain: {
    flex: 1,
  },
  clientName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  clientId: {
    fontSize: 14,
    color: '#666',
  },
  deleteButton: {
    padding: 4,
  },
  poaDetails: {
    marginBottom: 12,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    gap: 8,
  },
  detailText: {
    fontSize: 14,
    color: '#666',
  },
  poaFlags: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  flag: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    gap: 4,
  },
  flagText: {
    fontSize: 11,
    color: '#fff',
    fontWeight: '600',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginTop: 16,
    marginBottom: 8,
  },
  emptySubtitle: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
  fab: {
    position: 'absolute',
    right: 16,
    bottom: 16,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#2196F3',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
});