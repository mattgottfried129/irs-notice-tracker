// app/client/[id].tsx
import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  Linking
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { clientService, noticeService } from '../../lib/api';
import { Client, Notice } from '../../lib/types';

export default function ClientDetailScreen() {
  const { id } = useLocalSearchParams();
  const router = useRouter();
  const [client, setClient] = useState<Client | null>(null);
  const [notices, setNotices] = useState<Notice[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadClientData();
  }, [id]);

  const loadClientData = async () => {
    try {
      const clientData = await clientService.getByClientId(id as string);
      const noticesData = await noticeService.getByClientId(id as string);

      setClient(clientData);
      setNotices(noticesData);
    } catch (error) {
      console.error('Error loading client:', error);
      Alert.alert('Error', 'Failed to load client data');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = () => {
    router.push({
      pathname: '/client/edit',
      params: { id: id as string }
    });
  };

  const handleDelete = () => {
    Alert.alert(
      'Delete Client',
      `Are you sure you want to delete ${client?.name}? This action cannot be undone.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await clientService.delete(id as string);
              Alert.alert('Success', 'Client deleted successfully');
              router.back();
            } catch (error) {
              Alert.alert('Error', 'Failed to delete client');
            }
          }
        }
      ]
    );
  };

  const handleCall = (phone: string) => {
    Linking.openURL(`tel:${phone}`);
  };

  const handleEmail = (email: string) => {
    Linking.openURL(`mailto:${email}`);
  };

  const handleAddNotice = () => {
    router.push({
      pathname: '/notice/add',
      params: { clientId: id as string }
    });
  };

  const handleNoticePress = (notice: Notice) => {
    router.push({
      pathname: '/notice/[id]',
      params: { id: notice.id }
    });
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
      </View>
    );
  }

  if (!client) {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.errorText}>Client not found</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scrollView}>
        {/* Client Info Card */}
        <View style={styles.card}>
          <View style={styles.header}>
            <View style={styles.avatar}>
              <Text style={styles.avatarText}>
                {client.name.charAt(0).toUpperCase()}
              </Text>
            </View>
            <View style={styles.headerInfo}>
              <Text style={styles.clientName}>{client.name}</Text>
              <Text style={styles.clientId}>ID: {client.id}</Text>
            </View>
          </View>

          <View style={styles.divider} />

          {/* Contact Information */}
          {client.email && (
            <TouchableOpacity
              style={styles.contactRow}
              onPress={() => handleEmail(client.email!)}
            >
              <Ionicons name="mail" size={20} color="#2196F3" />
              <Text style={styles.contactText}>{client.email}</Text>
              <Ionicons name="chevron-forward" size={20} color="#999" />
            </TouchableOpacity>
          )}

          {client.phone && (
            <TouchableOpacity
              style={styles.contactRow}
              onPress={() => handleCall(client.phone!)}
            >
              <Ionicons name="call" size={20} color="#2196F3" />
              <Text style={styles.contactText}>{client.phone}</Text>
              <Ionicons name="chevron-forward" size={20} color="#999" />
            </TouchableOpacity>
          )}

          {client.address && (
            <View style={styles.contactRow}>
              <Ionicons name="location" size={20} color="#2196F3" />
              <Text style={styles.contactText}>{client.address}</Text>
            </View>
          )}

          {!client.email && !client.phone && !client.address && (
            <Text style={styles.noContactText}>No contact information</Text>
          )}
        </View>

        {/* Notices Section */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Notices ({notices.length})</Text>
            <TouchableOpacity onPress={handleAddNotice}>
              <Ionicons name="add-circle" size={28} color="#2196F3" />
            </TouchableOpacity>
          </View>

          {notices.length === 0 ? (
            <View style={styles.emptyNotices}>
              <Ionicons name="document-text-outline" size={48} color="#ccc" />
              <Text style={styles.emptyNoticesText}>No notices yet</Text>
              <TouchableOpacity
                style={styles.addNoticeButton}
                onPress={handleAddNotice}
              >
                <Text style={styles.addNoticeButtonText}>Add Notice</Text>
              </TouchableOpacity>
            </View>
          ) : (
            notices.map((notice) => (
              <TouchableOpacity
                key={notice.id}
                style={styles.noticeCard}
                onPress={() => handleNoticePress(notice)}
              >
                <View style={styles.noticeHeader}>
                  <Text style={styles.noticeId}>{notice.autoId || notice.noticeNumber}</Text>
                  <View style={[
                    styles.statusBadge,
                    { backgroundColor: getStatusColor(notice.status) }
                  ]}>
                    <Text style={styles.statusText}>{notice.status}</Text>
                  </View>
                </View>
                {notice.noticeIssue && (
                  <Text style={styles.noticeIssue}>{notice.noticeIssue}</Text>
                )}
                {notice.dueDate && (
                  <Text style={styles.noticeDueDate}>
                    Due: {new Date(notice.dueDate).toLocaleDateString()}
                  </Text>
                )}
              </TouchableOpacity>
            ))
          )}
        </View>

        {/* Action Buttons */}
        <View style={styles.actions}>
          <TouchableOpacity
            style={styles.editButton}
            onPress={handleEdit}
          >
            <Ionicons name="create-outline" size={20} color="#fff" />
            <Text style={styles.editButtonText}>Edit Client</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.deleteButton}
            onPress={handleDelete}
          >
            <Ionicons name="trash-outline" size={20} color="#fff" />
            <Text style={styles.deleteButtonText}>Delete Client</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </View>
  );
}

function getStatusColor(status: string): string {
  switch (status.toLowerCase()) {
    case 'open':
      return '#2196F3';
    case 'in progress':
      return '#FF9800';
    case 'waiting on client':
    case 'awaiting irs response':
      return '#9C27B0';
    case 'escalated':
      return '#F44336';
    case 'closed':
      return '#4CAF50';
    default:
      return '#757575';
  }
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
  errorText: {
    fontSize: 16,
    color: '#666',
  },
  scrollView: {
    flex: 1,
  },
  card: {
    backgroundColor: '#fff',
    margin: 16,
    marginBottom: 8,
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  avatar: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#2196F3',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  avatarText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
  },
  headerInfo: {
    flex: 1,
  },
  clientName: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  clientId: {
    fontSize: 14,
    color: '#666',
  },
  divider: {
    height: 1,
    backgroundColor: '#eee',
    marginVertical: 16,
  },
  contactRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
  },
  contactText: {
    flex: 1,
    fontSize: 14,
    color: '#333',
    marginLeft: 12,
  },
  noContactText: {
    fontSize: 14,
    color: '#999',
    fontStyle: 'italic',
    textAlign: 'center',
    paddingVertical: 8,
  },
  section: {
    margin: 16,
    marginTop: 8,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  emptyNotices: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 32,
    alignItems: 'center',
  },
  emptyNoticesText: {
    fontSize: 16,
    color: '#666',
    marginTop: 12,
    marginBottom: 16,
  },
  addNoticeButton: {
    backgroundColor: '#2196F3',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  addNoticeButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
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
    alignItems: 'center',
    marginBottom: 8,
  },
  noticeId: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
  },
  statusBadge: {
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#fff',
  },
  noticeIssue: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  noticeDueDate: {
    fontSize: 12,
    color: '#999',
  },
  actions: {
    padding: 16,
    paddingTop: 8,
  },
  editButton: {
    flexDirection: 'row',
    backgroundColor: '#2196F3',
    borderRadius: 8,
    paddingVertical: 16,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  },
  editButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
  deleteButton: {
    flexDirection: 'row',
    backgroundColor: '#F44336',
    borderRadius: 8,
    paddingVertical: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  deleteButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
});