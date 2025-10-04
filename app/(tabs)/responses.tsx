// app/(tabs)/responses.tsx
import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  RefreshControl,
  Alert
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { callService } from '../../lib/api';
import { Call } from '../../lib/types';
import { DateUtils, BillingUtils } from '../../lib/utils';

type TabType = 'unbilled' | 'all';

export default function ResponseLogScreen() {
  const [calls, setCalls] = useState<Call[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [activeTab, setActiveTab] = useState<TabType>('unbilled');
  const router = useRouter();

  const loadCalls = async () => {
    try {
      const data = await callService.getAll();
      // Sort by date descending
      data.sort((a, b) => {
        const dateA = a.date instanceof Date ? a.date : new Date(a.date);
        const dateB = b.date instanceof Date ? b.date : new Date(b.date);
        return dateB.getTime() - dateA.getTime();
      });
      setCalls(data);
    } catch (error) {
      console.error('Error loading calls:', error);
      Alert.alert('Error', 'Failed to load responses');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadCalls();
  }, []);

  const onRefresh = () => {
    setRefreshing(true);
    loadCalls();
  };

  const handleCallPress = (call: Call) => {
    router.push({
      pathname: '/response/[id]',
      params: { id: call.id }
    });
  };

  const handleAddResponse = () => {
    router.push('/response/add');
  };

  const getFilteredCalls = () => {
    if (activeTab === 'unbilled') {
      return calls.filter(c => c.billing === 'Unbilled');
    }
    return calls;
  };

  const calculateTotal = (callsList: Call[]) => {
    return callsList
      .filter(c => c.billable)
      .reduce((sum, c) => sum + (c.billableAmount || 0), 0);
  };

  const filteredCalls = getFilteredCalls();
  const unbilledCalls = calls.filter(c => c.billing === 'Unbilled');
  const billedCalls = calls.filter(c => c.billing === 'Billed');

  const unbilledTotal = calculateTotal(unbilledCalls);
  const billedTotal = calculateTotal(billedCalls);

  const renderCall = ({ item }: { item: Call }) => {
    const amount = item.billable ? (item.billableAmount || 0) : 0;

    return (
      <TouchableOpacity
        style={styles.callCard}
        onPress={() => handleCallPress(item)}
      >
        <View style={styles.callHeader}>
          <View style={styles.callInfo}>
            <View style={styles.callTitleRow}>
              <Ionicons
                name={
                  item.responseMethod === 'Phone Call' ? 'call' :
                  item.responseMethod === 'Fax' ? 'document' :
                  item.responseMethod === 'Mail' ? 'mail' :
                  item.responseMethod === 'e-services' ? 'globe' :
                  'search'
                }
                size={16}
                color="#2196F3"
              />
              <Text style={styles.callMethod}>{item.responseMethod}</Text>
            </View>
            <Text style={styles.callClient}>
              Client: {item.clientId} • Notice: {item.noticeId}
            </Text>
            <Text style={styles.callDate}>
              {DateUtils.formatDate(item.date)} • {item.durationMinutes} min
            </Text>
          </View>

          <View style={styles.callAmountContainer}>
            <Text style={styles.callAmount}>
              {BillingUtils.formatCurrency(amount)}
            </Text>
            <View
              style={[
                styles.billingBadge,
                { backgroundColor: item.billing === 'Billed' ? '#4CAF50' : '#FF9800' }
              ]}
            >
              <Text style={styles.billingText}>{item.billing}</Text>
            </View>
          </View>
        </View>

        {item.description && (
          <Text style={styles.callDescription} numberOfLines={2}>
            {item.description}
          </Text>
        )}
      </TouchableOpacity>
    );
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Tabs */}
      <View style={styles.tabContainer}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'unbilled' && styles.tabActive]}
          onPress={() => setActiveTab('unbilled')}
        >
          <Text style={[styles.tabText, activeTab === 'unbilled' && styles.tabTextActive]}>
            Unbilled
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'all' && styles.tabActive]}
          onPress={() => setActiveTab('all')}
        >
          <Text style={[styles.tabText, activeTab === 'all' && styles.tabTextActive]}>
            All Calls
          </Text>
        </TouchableOpacity>
      </View>

      {/* Summary Bar */}
      <View style={styles.summaryBar}>
        {activeTab === 'unbilled' ? (
          <View style={styles.summaryRow}>
            <Text style={styles.summaryLabel}>Unbilled Total:</Text>
            <Text style={styles.summaryAmount}>{BillingUtils.formatCurrency(unbilledTotal)}</Text>
          </View>
        ) : (
          <View style={styles.summaryRow}>
            <View style={styles.summaryItem}>
              <Text style={styles.summaryLabel}>Billed:</Text>
              <Text style={[styles.summaryAmount, { color: '#4CAF50' }]}>
                {BillingUtils.formatCurrency(billedTotal)}
              </Text>
            </View>
            <View style={styles.summaryItem}>
              <Text style={styles.summaryLabel}>Unbilled:</Text>
              <Text style={[styles.summaryAmount, { color: '#FF9800' }]}>
                {BillingUtils.formatCurrency(unbilledTotal)}
              </Text>
            </View>
          </View>
        )}
      </View>

      {/* Call List */}
      {filteredCalls.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Ionicons name="call-outline" size={64} color="#ccc" />
          <Text style={styles.emptyTitle}>
            {activeTab === 'unbilled' ? 'No unbilled calls' : 'No calls logged'}
          </Text>
          <Text style={styles.emptySubtitle}>
            {activeTab === 'unbilled'
              ? 'All calls have been billed'
              : 'Tap the + button to log a response'}
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredCalls}
          renderItem={renderCall}
          keyExtractor={item => item.id || `${item.noticeId}-${item.date}`}
          contentContainerStyle={styles.listContent}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
          }
        />
      )}

      {/* Floating Add Button */}
      <TouchableOpacity style={styles.fab} onPress={handleAddResponse}>
        <Ionicons name="add" size={28} color="#fff" />
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
  tabContainer: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  tab: {
    flex: 1,
    paddingVertical: 16,
    alignItems: 'center',
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  tabActive: {
    borderBottomColor: '#2196F3',
  },
  tabText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#666',
  },
  tabTextActive: {
    color: '#2196F3',
  },
  summaryBar: {
    backgroundColor: '#fff',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  summaryItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  summaryLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
    marginRight: 8,
  },
  summaryAmount: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
  },
  listContent: {
    padding: 16,
  },
  callCard: {
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
  callHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  callInfo: {
    flex: 1,
  },
  callTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  callMethod: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginLeft: 8,
  },
  callClient: {
    fontSize: 13,
    color: '#666',
    marginBottom: 2,
  },
  callDate: {
    fontSize: 12,
    color: '#999',
  },
  callAmountContainer: {
    alignItems: 'flex-end',
  },
  callAmount: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  billingBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
  },
  billingText: {
    fontSize: 11,
    fontWeight: '600',
    color: '#fff',
  },
  callDescription: {
    fontSize: 14,
    color: '#666',
    fontStyle: 'italic',
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