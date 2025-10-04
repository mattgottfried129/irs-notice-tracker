// app/poa/[id].tsx
// POA Detail screen

import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { poaService, clientService, noticeService } from '../../lib/api';
import { POARecord, Client, Notice } from '../../lib/types';
import { POAChecker } from '../../lib/poaChecker';

export default function POADetailScreen() {
  const { id } = useLocalSearchParams();
  const router = useRouter();

  const [poa, setPOA] = useState<POARecord | null>(null);
  const [client, setClient] = useState<Client | null>(null);
  const [relatedNotices, setRelatedNotices] = useState<Notice[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadPOAData();
  }, [id]);

  const loadPOAData = async () => {
    try {
      const poaData = await poaService.getById(id as string);

      if (poaData) {
        setPOA(poaData);

        // Load client
        const clientData = await clientService.getByClientId(poaData.clientId);
        setClient(clientData);

        // Load related notices
        const allNotices = await noticeService.getByClientId(poaData.clientId);
        const related = allNotices.filter(notice =>
          notice.formNumber === poaData.form &&
          notice.taxPeriod &&
          POAChecker.coversPeriod(poaData.periodStart, poaData.periodEnd, notice.taxPeriod)
        );
        setRelatedNotices(related);
      }
    } catch (error) {
      console.error('Error loading POA:', error);
      Alert.alert('Error', 'Failed to load POA record');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = () => {
    Alert.alert(
      'Delete POA',
      'Are you sure you want to delete this POA record?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await poaService.delete(id as string);
              Alert.alert('Success', 'POA record deleted', [
                { text: 'OK', onPress: () => router.back() }
              ]);
            } catch (error) {
              Alert.alert('Error', 'Failed to delete POA record');
            }
          }
        }
      ]
    );
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
      </View>
    );
  }

  if (!poa) {
    return (
      <View style={styles.errorContainer}>
        <Ionicons name="alert-circle-outline" size={64} color="#F44336" />
        <Text style={styles.errorText}>POA record not found</Text>
        <TouchableOpacity style={styles.backButton} onPress={() => router.back()}>
          <Text style={styles.backButtonText}>Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.headerBack}>
          <Ionicons name="arrow-back" size={24} color="#333" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>POA Details</Text>
        <TouchableOpacity onPress={handleDelete} style={styles.deleteButton}>
          <Ionicons name="trash-outline" size={24} color="#F44336" />
        </TouchableOpacity>
      </View>

      {/* Client Info */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Client Information</Text>
        <View style={styles.card}>
          <Text style={styles.clientName}>{client?.name || 'Unknown Client'}</Text>
          <Text style={styles.clientId}>Client ID: {poa.clientId}</Text>
          {client?.email && (
            <Text style={styles.clientDetail}>Email: {client.email}</Text>
          )}
          {client?.phone && (
            <Text style={styles.clientDetail}>Phone: {client.phone}</Text>
          )}
        </View>
      </View>

      {/* POA Details */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>POA Details</Text>
        <View style={styles.card}>
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Form:</Text>
            <Text style={styles.detailValue}>
              {poa.form === '2848' ? 'Form 2848 (Power of Attorney)' : 'Form 8821 (Tax Info Auth)'}
            </Text>
          </View>

          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Coverage Period:</Text>
            <Text style={styles.detailValue}>
              {POAChecker.formatPeriodRange(poa.periodStart, poa.periodEnd)}
            </Text>
          </View>

          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Period Range:</Text>
            <Text style={styles.detailValue}>
              {poa.periodStart} - {poa.periodEnd}
            </Text>
          </View>
        </View>
      </View>

      {/* Status Flags */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Status</Text>
        <View style={styles.card}>
          <View style={styles.statusRow}>
            <Ionicons
              name={poa.electronicCopy ? "checkmark-circle" : "close-circle"}
              size={24}
              color={poa.electronicCopy ? "#4CAF50" : "#ccc"}
            />
            <Text style={styles.statusText}>Electronic Copy on File</Text>
          </View>

          <View style={styles.statusRow}>
            <Ionicons
              name={poa.cafVerified ? "checkmark-circle" : "close-circle"}
              size={24}
              color={poa.cafVerified ? "#4CAF50" : "#ccc"}
            />
            <Text style={styles.statusText}>CAF Verified</Text>
          </View>

          <View style={styles.statusRow}>
            <Ionicons
              name={poa.paperCopy ? "checkmark-circle" : "close-circle"}
              size={24}
              color={poa.paperCopy ? "#4CAF50" : "#ccc"}
            />
            <Text style={styles.statusText}>Paper Copy on File</Text>
          </View>
        </View>
      </View>

      {/* Notes */}
      {poa.notes && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Notes</Text>
          <View style={styles.card}>
            <Text style={styles.notesText}>{poa.notes}</Text>
          </View>
        </View>
      )}

      {/* Related Notices */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>
          Related Notices ({relatedNotices.length})
        </Text>
        {relatedNotices.length === 0 ? (
          <View style={styles.card}>
            <Text style={styles.emptyText}>
              No notices found using this POA
            </Text>
          </View>
        ) : (
          relatedNotices.map(notice => (
            <TouchableOpacity
              key={notice.id}
              style={styles.noticeCard}
              onPress={() => router.push({
                pathname: '/notice/[id]',
                params: { id: notice.id }
              })}
            >
              <Text style={styles.noticeNumber}>
                {notice.autoId || notice.noticeNumber}
              </Text>
              <Text style={styles.noticeIssue}>
                {notice.noticeIssue || 'No issue specified'}
              </Text>
              <Text style={styles.noticePeriod}>
                Period: {notice.taxPeriod}
              </Text>
            </TouchableOpacity>
          ))
        )}
      </View>

      <View style={{ height: 32 }} />
    </ScrollView>
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
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
    backgroundColor: '#f5f5f5',
  },
  errorText: {
    fontSize: 18,
    color: '#666',
    marginTop: 16,
    marginBottom: 24,
  },
  backButton: {
    backgroundColor: '#2196F3',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  backButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 20,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  headerBack: {
    padding: 4,
  },
  headerTitle: {
    flex: 1,
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginLeft: 12,
  },
  deleteButton: {
    padding: 4,
  },
  section: {
    marginTop: 16,
    paddingHorizontal: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  clientName: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  clientId: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
  },
  clientDetail: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  detailRow: {
    marginBottom: 12,
  },
  detailLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 4,
  },
  detailValue: {
    fontSize: 16,
    color: '#333',
    fontWeight: '500',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
    gap: 12,
  },
  statusText: {
    fontSize: 16,
    color: '#333',
  },
  notesText: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
  },
  noticeCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  noticeNumber: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  noticeIssue: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  noticePeriod: {
    fontSize: 12,
    color: '#999',
  },
  emptyText: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
    fontStyle: 'italic',
  },
});