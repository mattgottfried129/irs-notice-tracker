// app/(tabs)/billing.tsx
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
  ScrollView
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { callService, clientService } from '../../lib/api';
import { Call, Client } from '../../lib/types';
import { DateUtils, BillingUtils } from '../../lib/utils';
import { collection, doc, setDoc } from 'firebase/firestore';
import { db } from '../../lib/firebase';

type TabType = 'unbilled' | 'billed' | 'all';

interface ClientBilling {
  client: Client;
  calls: Call[];
  totalAmount: number;
  billableHours: number;
}

export default function BillingScreen() {
  const [calls, setCalls] = useState<Call[]>([]);
  const [clients, setClients] = useState<Client[]>([]);
  const [clientBilling, setClientBilling] = useState<ClientBilling[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [activeTab, setActiveTab] = useState<TabType>('unbilled');
  const [selectedCallIds, setSelectedCallIds] = useState<Set<string>>(new Set());
  const [missingClientIds, setMissingClientIds] = useState<string[]>([]);
  const router = useRouter();

  const loadData = async () => {
    try {
      const [callsData, clientsData] = await Promise.all([
        callService.getAll(),
        clientService.getAll()
      ]);

      console.log('📞 Raw calls loaded:', callsData.length);
      console.log('👥 Clients loaded:', clientsData.length);

      if (callsData.length > 0) {
        console.log('Sample call:', callsData[0]);
      }

      if (clientsData.length > 0) {
        console.log('Sample client:', clientsData[0]);
        console.log('All client IDs:', clientsData.map(c => c.id));

        // Check which call client IDs exist in our clients
        const callClientIds = [...new Set(callsData.map(c => c.clientId))];
        console.log('Unique client IDs from calls:', callClientIds);

        const missingClients = callClientIds.filter(callClientId =>
          !clientsData.some(client => client.id === callClientId)
        );

        if (missingClients.length > 0) {
          console.error('❌ These client IDs from calls are NOT in the clients collection:', missingClients);
        } else {
          console.log('✅ All call client IDs match clients in database');
        }
      }

      // Calculate billable amounts for each call with proper per-notice logic
      const callsWithAmounts = callsData.map(call => {
        if (!call.billable) {
          return { ...call, billableAmount: 0 };
        }

        const rate = call.hourlyRate || 250;
        const timeBasedAmount = (call.durationMinutes / 60) * rate;
        const isResearch = call.responseMethod?.toLowerCase().includes('research') || false;

        if (isResearch) {
          // Research: bill actual time, rounded to $5
          return {
            ...call,
            billableAmount: Math.ceil(timeBasedAmount / 5) * 5
          };
        }

        // Non-research: Get all calls for this notice
        const noticeCalls = callsData.filter(c =>
          c.noticeId === call.noticeId &&
          c.billable &&
          !c.responseMethod?.toLowerCase().includes('research')
        );

        const totalNoticeMinutes = noticeCalls.reduce((sum, c) => sum + c.durationMinutes, 0);
        const totalNoticeHours = totalNoticeMinutes / 60;

        // If total >= 1 hour, bill each call at actual time
        if (totalNoticeHours >= 1.0) {
          return {
            ...call,
            billableAmount: Math.ceil(timeBasedAmount / 5) * 5
          };
        }

        // If total < 1 hour, apply $250 to first call only
        const sortedCalls = [...noticeCalls].sort((a, b) => {
          const dateA = a.date instanceof Date ? a.date : new Date(a.date);
          const dateB = b.date instanceof Date ? b.date : new Date(b.date);
          return dateA.getTime() - dateB.getTime();
        });

        if (sortedCalls.length > 0 && sortedCalls[0].id === call.id) {
          return { ...call, billableAmount: 250 }; // First call gets minimum
        }

        return { ...call, billableAmount: 0 }; // Subsequent calls covered by minimum
      });

      // Sort calls by date descending
      callsWithAmounts.sort((a, b) => {
        const dateA = a.date instanceof Date ? a.date : new Date(a.date);
        const dateB = b.date instanceof Date ? b.date : new Date(b.date);
        return dateB.getTime() - dateA.getTime();
      });

      console.log('✅ Calls with calculated amounts:', callsWithAmounts.length);

      setCalls(callsWithAmounts);
      setClients(clientsData);

      // Group calls by client
      const grouped = groupCallsByClient(callsWithAmounts, clientsData);
      setClientBilling(grouped);
    } catch (error) {
      console.error('Error loading billing data:', error);
      Alert.alert('Error', 'Failed to load billing data');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const groupCallsByClient = (calls: Call[], clients: Client[]): ClientBilling[] => {
    const grouped = new Map<string, ClientBilling>();

    console.log('🔄 Grouping calls by client...');
    console.log('Calls to group:', calls.length);
    console.log('Clients available:', clients.length);

    calls.forEach(call => {
      // Try to find client by id field OR by _docId (Firestore document ID)
      let client = clients.find(c => c.id === call.clientId);

      // If not found by id field, try matching by document ID
      if (!client) {
        client = clients.find(c => (c as any)._docId === call.clientId);
      }

      // If still not found, create a placeholder
      if (!client) {
        console.log(`⚠️ No client found for call with clientId: ${call.clientId} - using placeholder`);
        client = {
          id: call.clientId,
          name: `Client ${call.clientId}`,
          email: null,
          phone: null,
          address: null
        };
      }

      if (!grouped.has(client.id)) {
        grouped.set(client.id, {
          client,
          calls: [],
          totalAmount: 0,
          billableHours: 0
        });
      }

      const billing = grouped.get(client.id)!;
      billing.calls.push(call);

      if (call.billable) {
        billing.totalAmount += call.billableAmount || 0;
        billing.billableHours += call.durationMinutes / 60;
      }
    });

    const result = Array.from(grouped.values()).sort((a, b) =>
      b.totalAmount - a.totalAmount
    );

    console.log('✅ Grouped into', result.length, 'clients');
    if (result.length > 0) {
      console.log('First client billing:', {
        clientId: result[0].client.id,
        clientName: result[0].client.name,
        callCount: result[0].calls.length,
        totalAmount: result[0].totalAmount
      });
    }

    return result;
  };

  useEffect(() => {
    loadData();
  }, []);

  const onRefresh = () => {
    setRefreshing(true);
    setSelectedCallIds(new Set());
    loadData();
  };

  const handleCallPress = (call: Call) => {
    router.push({
      pathname: '/response/[id]',
      params: { id: call.id }
    });
  };

  const toggleCallSelection = (callId: string) => {
    const newSelection = new Set(selectedCallIds);
    if (newSelection.has(callId)) {
      newSelection.delete(callId);
    } else {
      newSelection.add(callId);
    }
    setSelectedCallIds(newSelection);
  };

  const handleMarkAsBilled = async () => {
    if (selectedCallIds.size === 0) {
      Alert.alert('No Selection', 'Please select calls to mark as billed');
      return;
    }

    Alert.alert(
      'Mark as Billed',
      `Mark ${selectedCallIds.size} call(s) as billed?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Confirm',
          onPress: async () => {
            try {
              const selectedIds = Array.from(selectedCallIds);
              await callService.markAsBilled(selectedIds);
              Alert.alert('Success', 'Calls marked as billed');
              setSelectedCallIds(new Set());
              loadData();
            } catch (error) {
              Alert.alert('Error', 'Failed to update billing status');
            }
          }
        }
      ]
    );
  };

  const handleSelectAllUnbilled = () => {
    const unbilledCalls = calls.filter(c => c.billing === 'Unbilled' && c.billable);
    const newSelection = new Set(unbilledCalls.map(c => c.id!));
    setSelectedCallIds(newSelection);
  };

  const getFilteredCalls = () => {
    if (activeTab === 'unbilled') {
      return calls.filter(c => c.billing === 'Unbilled');
    } else if (activeTab === 'billed') {
      return calls.filter(c => c.billing === 'Billed');
    }
    return calls;
  };

  const getFilteredClientBilling = (): ClientBilling[] => {
    return clientBilling.map(cb => {
      const filteredCalls = cb.calls.filter(call => {
        if (activeTab === 'unbilled') return call.billing === 'Unbilled';
        if (activeTab === 'billed') return call.billing === 'Billed';
        return true;
      });

      const totalAmount = filteredCalls
        .filter(c => c.billable)
        .reduce((sum, c) => sum + (c.billableAmount || 0), 0);

      const billableHours = filteredCalls
        .filter(c => c.billable)
        .reduce((sum, c) => sum + c.durationMinutes / 60, 0);

      return {
        ...cb,
        calls: filteredCalls,
        totalAmount,
        billableHours
      };
    }).filter(cb => cb.calls.length > 0);
  };

  const filteredCalls = getFilteredCalls();
  const filteredClientBilling = getFilteredClientBilling();

  const unbilledTotal = calls
    .filter(c => c.billing === 'Unbilled' && c.billable)
    .reduce((sum, c) => sum + (c.billableAmount || 0), 0);

  const billedTotal = calls
    .filter(c => c.billing === 'Billed' && c.billable)
    .reduce((sum, c) => sum + (c.billableAmount || 0), 0);

  const selectedTotal = Array.from(selectedCallIds)
    .map(id => calls.find(c => c.id === id))
    .filter(c => c && c.billable)
    .reduce((sum, c) => sum + (c!.billableAmount || 0), 0);

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color="#2196F3" />
      </View>
    );
  }

  const renderClientBilling = ({ item }: { item: ClientBilling }) => {
    // Check if this client has any unbilled calls
    const hasUnbilledCalls = item.calls.some(c => c.billing === 'Unbilled' && c.billable);

    return (
      <View style={styles.clientCard}>
        <View style={styles.clientHeader}>
          <View style={styles.clientInfo}>
            <Text style={styles.clientName}>{item.client.name}</Text>
            <Text style={styles.clientId}>ID: {item.client.id}</Text>
          </View>
          <View style={styles.clientTotals}>
            <Text style={[
              styles.totalAmount,
              hasUnbilledCalls ? styles.totalAmountUnbilled : styles.totalAmountBilled
            ]}>
              {BillingUtils.formatCurrency(item.totalAmount)}
            </Text>
            <Text style={styles.totalHours}>
              {item.billableHours.toFixed(2)} hrs
            </Text>
          </View>
        </View>

        {item.calls.map(call => renderCall(call))}
      </View>
    );
  };

  const renderCall = (call: Call) => {
    const isSelected = selectedCallIds.has(call.id!);
    const amount = call.billable ? (call.billableAmount || 0) : 0;
    const canSelect = activeTab === 'unbilled' && call.billable;

    return (
      <TouchableOpacity
        key={call.id}
        style={[
          styles.callItem,
          isSelected && styles.callItemSelected
        ]}
        onPress={() => handleCallPress(call)}
        onLongPress={() => canSelect && toggleCallSelection(call.id!)}
      >
        {canSelect && (
          <TouchableOpacity
            style={styles.checkbox}
            onPress={() => toggleCallSelection(call.id!)}
          >
            <Ionicons
              name={isSelected ? 'checkbox' : 'square-outline'}
              size={24}
              color={isSelected ? '#2196F3' : '#999'}
            />
          </TouchableOpacity>
        )}

        <View style={styles.callContent}>
          <View style={styles.callHeader}>
            <View style={styles.callTitleRow}>
              <Ionicons
                name={
                  call.responseMethod === 'Phone Call' ? 'call' :
                  call.responseMethod === 'Fax' ? 'document' :
                  call.responseMethod === 'Mail' ? 'mail' :
                  'globe'
                }
                size={16}
                color="#666"
                style={styles.callIcon}
              />
              <Text style={styles.callMethod}>{call.responseMethod}</Text>
              <Text style={styles.callDate}>
                {DateUtils.formatDate(call.date)}
              </Text>
            </View>
          </View>

          {call.description && (
            <Text style={styles.callDescription} numberOfLines={2}>
              {call.description}
            </Text>
          )}

          <View style={styles.callFooter}>
            <Text style={styles.callDuration}>
              {call.durationMinutes} min
            </Text>
            {call.billable && (
              <Text style={[
                styles.callAmount,
                call.billing === 'Unbilled' ? styles.callAmountUnbilled : styles.callAmountBilled
              ]}>
                {BillingUtils.formatCurrency(amount)}
              </Text>
            )}
          </View>
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.container}>
      {/* Summary Cards */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.summaryContainer}
      >
        <View style={[styles.summaryCard, { backgroundColor: '#FFF3E0' }]}>
          <Text style={styles.summaryLabel}>Unbilled</Text>
          <Text style={[styles.summaryValue, { color: '#F57C00' }]}>
            {BillingUtils.formatCurrency(unbilledTotal)}
          </Text>
        </View>

        <View style={[styles.summaryCard, { backgroundColor: '#E8F5E9' }]}>
          <Text style={styles.summaryLabel}>Billed</Text>
          <Text style={[styles.summaryValue, { color: '#388E3C' }]}>
            {BillingUtils.formatCurrency(billedTotal)}
          </Text>
        </View>

        <View style={[styles.summaryCard, { backgroundColor: '#E3F2FD' }]}>
          <Text style={styles.summaryLabel}>Total</Text>
          <Text style={[styles.summaryValue, { color: '#1976D2' }]}>
            {BillingUtils.formatCurrency(unbilledTotal + billedTotal)}
          </Text>
        </View>
      </ScrollView>

      {/* Tabs */}
      <View style={styles.tabs}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'unbilled' && styles.activeTab]}
          onPress={() => {
            setActiveTab('unbilled');
            setSelectedCallIds(new Set());
          }}
        >
          <Text style={[
            styles.tabText,
            activeTab === 'unbilled' && styles.activeTabText
          ]}>
            Unbilled ({calls.filter(c => c.billing === 'Unbilled').length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.tab, activeTab === 'billed' && styles.activeTab]}
          onPress={() => {
            setActiveTab('billed');
            setSelectedCallIds(new Set());
          }}
        >
          <Text style={[
            styles.tabText,
            activeTab === 'billed' && styles.activeTabText
          ]}>
            Billed ({calls.filter(c => c.billing === 'Billed').length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.tab, activeTab === 'all' && styles.activeTab]}
          onPress={() => {
            setActiveTab('all');
            setSelectedCallIds(new Set());
          }}
        >
          <Text style={[
            styles.tabText,
            activeTab === 'all' && styles.activeTabText
          ]}>
            All ({calls.length})
          </Text>
        </TouchableOpacity>
      </View>

      {/* Bulk Actions */}
      {activeTab === 'unbilled' && (
        <View style={styles.bulkActions}>
          <TouchableOpacity
            style={styles.selectAllButton}
            onPress={handleSelectAllUnbilled}
          >
            <Ionicons name="checkmark-done" size={20} color="#2196F3" />
            <Text style={styles.selectAllText}>Select All</Text>
          </TouchableOpacity>

          {selectedCallIds.size > 0 && (
            <View style={styles.selectionInfo}>
              <Text style={styles.selectionText}>
                {selectedCallIds.size} selected • {BillingUtils.formatCurrency(selectedTotal)}
              </Text>
              <TouchableOpacity
                style={styles.markBilledButton}
                onPress={handleMarkAsBilled}
              >
                <Ionicons name="checkmark-circle" size={20} color="#fff" />
                <Text style={styles.markBilledText}>Mark as Billed</Text>
              </TouchableOpacity>
            </View>
          )}
        </View>
      )}

      {/* Client Billing List */}
      <FlatList
        data={filteredClientBilling}
        renderItem={renderClientBilling}
        keyExtractor={(item) => item.client.id}
        contentContainerStyle={styles.listContent}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="receipt-outline" size={64} color="#ccc" />
            <Text style={styles.emptyText}>No billing records found</Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  summaryContainer: {
    backgroundColor: '#fff',
    paddingHorizontal: 16,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  summaryCard: {
    padding: 16,
    borderRadius: 8,
    marginRight: 12,
    minWidth: 120,
  },
  summaryLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 4,
  },
  summaryValue: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  tabs: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  tab: {
    flex: 1,
    paddingVertical: 12,
    alignItems: 'center',
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  activeTab: {
    borderBottomColor: '#2196F3',
  },
  tabText: {
    fontSize: 14,
    color: '#666',
  },
  activeTabText: {
    color: '#2196F3',
    fontWeight: '600',
  },
  bulkActions: {
    backgroundColor: '#fff',
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  selectAllButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
  },
  selectAllText: {
    fontSize: 14,
    color: '#2196F3',
    marginLeft: 8,
    fontWeight: '600',
  },
  selectionInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 8,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#eee',
  },
  selectionText: {
    fontSize: 14,
    color: '#333',
    fontWeight: '600',
  },
  markBilledButton: {
    flexDirection: 'row',
    backgroundColor: '#4CAF50',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
    alignItems: 'center',
  },
  markBilledText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 6,
  },
  listContent: {
    padding: 16,
  },
  clientCard: {
    backgroundColor: '#fff',
    borderRadius: 8,
    marginBottom: 16,
    overflow: 'hidden',
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  clientHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#f8f8f8',
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  clientInfo: {
    flex: 1,
  },
  clientName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 2,
  },
  clientId: {
    fontSize: 12,
    color: '#666',
  },
  clientTotals: {
    alignItems: 'flex-end',
  },
  totalAmount: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#4CAF50',
    marginBottom: 2,
  },
  totalHours: {
    fontSize: 12,
    color: '#666',
  },
  callItem: {
    flexDirection: 'row',
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
    alignItems: 'center',
  },
  callItemSelected: {
    backgroundColor: '#E3F2FD',
  },
  checkbox: {
    marginRight: 12,
  },
  callContent: {
    flex: 1,
  },
  callHeader: {
    marginBottom: 4,
  },
  callTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  callIcon: {
    marginRight: 6,
  },
  callMethod: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    flex: 1,
  },
  callDate: {
    fontSize: 12,
    color: '#666',
  },
  callDescription: {
    fontSize: 13,
    color: '#666',
    marginBottom: 4,
  },
  callFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  callDuration: {
    fontSize: 12,
    color: '#999',
  },
  callAmount: {
    fontSize: 14,
    fontWeight: 'bold',
  },
  callAmountUnbilled: {
    color: '#FF9800', // Orange for unbilled
  },
  callAmountBilled: {
    color: '#4CAF50', // Green for billed
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 64,
  },
  emptyText: {
    marginTop: 16,
    fontSize: 16,
    color: '#999',
  },
});