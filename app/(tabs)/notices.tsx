// app/(tabs)/notices.tsx
// Notice List screen with POA integration

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
import { noticeService } from '../../lib/api';
import { Notice } from '../../lib/types';
import { NoticeStatusUtils, DateUtils } from '../../lib/utils';

export default function NoticesScreen() {
  const [notices, setNotices] = useState<Notice[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [filter, setFilter] = useState<string>('all');
  const router = useRouter();

  const loadNotices = async () => {
    try {
      const data = await noticeService.getAll();
      setNotices(data);
    } catch (error) {
      console.error('Error loading notices:', error);
      Alert.alert('Error', 'Failed to load notices');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadNotices();
  }, []);

  const onRefresh = () => {
    setRefreshing(true);
    loadNotices();
  };

  const handleNoticePress = (notice: Notice) => {
    router.push({
      pathname: '/notice/[id]',
      params: { id: notice.id }
    });
  };

  const handleAddNotice = () => {
    router.push('/notice/add');
  };

  const getFilteredNotices = () => {
    if (filter === 'all') return notices;
    if (filter === 'missing-poa') {
      return notices.filter(n => !n.poaOnFile && n.status !== 'Closed');
    }
    return notices.filter(n => n.status === filter);
  };

  const filteredNotices = getFilteredNotices();

  const renderNotice = ({ item }: { item: Notice }) => {
    const daysRemaining = item.dueDate
      ? DateUtils.daysRemaining(item.dueDate)
      : null;

    const statusColor = NoticeStatusUtils.getStatusColor(item.status);

    return (
      <TouchableOpacity
        style={styles.noticeCard}
        onPress={() => handleNoticePress(item)}
      >
        <View style={styles.noticeHeader}>
          <View style={styles.noticeTitle}>
            <Text style={styles.noticeNumber}>{item.autoId || item.noticeNumber}</Text>
            <View style={[styles.statusBadge, { backgroundColor: statusColor }]}>
              <Text style={styles.statusText}>{item.status}</Text>
            </View>
          </View>
          <Ionicons name="chevron-forward" size={20} color="#999" />
        </View>

        {item.noticeIssue && (
          <Text style={styles.noticeIssue} numberOfLines={2}>
            {item.noticeIssue}
          </Text>
        )}

        <View style={styles.noticeInfo}>
          {item.clientId && (
            <View style={styles.infoRow}>
              <Ionicons name="person" size={14} color="#666" />
              <Text style={styles.infoText}>{item.clientId}</Text>
            </View>
          )}

          {item.formNumber && (
            <View style={styles.infoRow}>
              <Ionicons name="document-text" size={14} color="#666" />
              <Text style={styles.infoText}>Form {item.formNumber}</Text>
            </View>
          )}

          {item.taxPeriod && (
            <View style={styles.infoRow}>
              <Ionicons name="calendar" size={14} color="#666" />
              <Text style={styles.infoText}>{item.taxPeriod}</Text>
            </View>
          )}
        </View>

        {item.dueDate && (
          <View style={styles.dueDateContainer}>
            <Ionicons
              name="time"
              size={14}
              color={daysRemaining !== null && daysRemaining <= 3 ? '#FF9800' : '#666'}
            />
            <Text style={[
              styles.dueDate,
              daysRemaining !== null && daysRemaining <= 0 && styles.overdue,
              daysRemaining !== null && daysRemaining > 0 && daysRemaining <= 3 && styles.dueSoon
            ]}>
              Due: {DateUtils.formatDate(item.dueDate)}
              {daysRemaining !== null && (
                <Text style={styles.daysRemaining}>
                  {' '}({daysRemaining <= 0
                    ? `${Math.abs(daysRemaining)} days overdue`
                    : `${daysRemaining} days`
                  })
                </Text>
              )}
            </Text>
          </View>
        )}

        {/* POA Status Indicators */}
        <View style={styles.indicators}>
          {item.escalated && (
            <View style={styles.escalatedBadge}>
              <Ionicons name="warning" size={12} color="#fff" />
              <Text style={styles.escalatedText}>ESCALATED</Text>
            </View>
          )}

          {!item.poaOnFile && item.formNumber && item.taxPeriod && item.status !== 'Closed' && (
            <View style={styles.poaWarning}>
              <Ionicons name="alert-circle" size={12} color="#FF9800" />
              <Text style={styles.poaWarningText}>Missing POA</Text>
            </View>
          )}

          {item.poaOnFile && (
            <View style={styles.poaValid}>
              <Ionicons name="shield-checkmark" size={12} color="#4CAF50" />
              <Text style={styles.poaValidText}>POA on File</Text>
            </View>
          )}
        </View>
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
      {/* Filter Tabs */}
      <View style={styles.filterContainer}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <TouchableOpacity
            style={[styles.filterTab, filter === 'all' && styles.filterTabActive]}
            onPress={() => setFilter('all')}
          >
            <Text style={[styles.filterText, filter === 'all' && styles.filterTextActive]}>
              All ({notices.length})
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.filterTab, filter === 'Open' && styles.filterTabActive]}
            onPress={() => setFilter('Open')}
          >
            <Text style={[styles.filterText, filter === 'Open' && styles.filterTextActive]}>
              Open
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.filterTab, filter === 'Escalated' && styles.filterTabActive]}
            onPress={() => setFilter('Escalated')}
          >
            <Text style={[styles.filterText, filter === 'Escalated' && styles.filterTextActive]}>
              Escalated
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.filterTab, filter === 'missing-poa' && styles.filterTabActive]}
            onPress={() => setFilter('missing-poa')}
          >
            <Text style={[styles.filterText, filter === 'missing-poa' && styles.filterTextActive]}>
              Missing POA
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.filterTab, filter === 'Closed' && styles.filterTabActive]}
            onPress={() => setFilter('Closed')}
          >
            <Text style={[styles.filterText, filter === 'Closed' && styles.filterTextActive]}>
              Closed
            </Text>
          </TouchableOpacity>
        </ScrollView>
      </View>

      {/* Notice List */}
      {filteredNotices.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Ionicons name="document-text-outline" size={64} color="#ccc" />
          <Text style={styles.emptyTitle}>No Notices Found</Text>
          <Text style={styles.emptySubtitle}>
            {filter === 'all'
              ? 'Add a notice to get started'
              : `No notices with status "${filter}"`
            }
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredNotices}
          renderItem={renderNotice}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
          }
        />
      )}

      {/* FAB */}
      <TouchableOpacity style={styles.fab} onPress={handleAddNotice}>
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
  filterContainer: {
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  filterTab: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    marginRight: 8,
    borderRadius: 20,
    backgroundColor: '#f5f5f5',
  },
  filterTabActive: {
    backgroundColor: '#2196F3',
  },
  filterText: {
    fontSize: 14,
    color: '#666',
    fontWeight: '500',
  },
  filterTextActive: {
    color: '#fff',
    fontWeight: '600',
  },
  listContent: {
    padding: 16,
  },
  noticeCard: {
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
  noticeHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  noticeTitle: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    flexWrap: 'wrap',
  },
  noticeNumber: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    fontSize: 10,
    color: '#fff',
    fontWeight: '600',
  },
  noticeIssue: {
    fontSize: 14,
    color: '#666',
    marginBottom: 12,
    lineHeight: 20,
  },
  noticeInfo: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
    marginBottom: 8,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  infoText: {
    fontSize: 12,
    color: '#666',
  },
  dueDateContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
    marginBottom: 8,
    gap: 4,
  },
  dueDate: {
    fontSize: 12,
    color: '#666',
  },
  overdue: {
    color: '#F44336',
    fontWeight: '600',
  },
  dueSoon: {
    color: '#FF9800',
    fontWeight: '600',
  },
  daysRemaining: {
    fontSize: 11,
  },
  indicators: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 8,
  },
  escalatedBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F44336',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    gap: 4,
  },
  escalatedText: {
    fontSize: 10,
    color: '#fff',
    fontWeight: '600',
  },
  poaWarning: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF3E0',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    gap: 4,
  },
  poaWarningText: {
    fontSize: 10,
    color: '#FF9800',
    fontWeight: '600',
  },
  poaValid: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#E8F5E9',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    gap: 4,
  },
  poaValidText: {
    fontSize: 10,
    color: '#4CAF50',
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