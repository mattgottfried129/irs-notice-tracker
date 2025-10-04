// app/response/[id].tsx
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
import { callService, clientService, noticeService } from '../../lib/api';
import { Call, Client, Notice } from '../../lib/types';
import { DateUtils, BillingUtils } from '../../lib/utils';

export default function ResponseDetailScreen() {
  const { id } = useLocalSearchParams();
  const router = useRouter();

  const [call, setCall] = useState<Call | null>(null);
  const [client, setClient] = useState<Client | null>(null);
  const [notice, setNotice] = useState<Notice | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadCallData();
  }, [id]);

  const loadCallData = async () => {
    try {
      const callData = await callService.getById(id as string);

      if (callData) {
        setCall(callData);

        // Load related data
        const [clientData, noticeData] = await Promise.all([
          clientService.getById(callData.clientId),
          noticeService.getById(callData.noticeId)
        ]);

        setClient(clientData);
        setNotice(noticeData);
      }
    } catch (error) {
      console.error('Error loading call:', error);
      Alert.alert('Error', 'Failed to load response details');
    } finally {
      setLoading(false);
    }
  };

  const handleToggleBilling = async () => {
    if (!call) return;

    const newStatus = call.billing === 'Billed' ? 'Unbilled' : 'Billed';

    Alert.alert(
      `Mark as ${newStatus}`,
      `Are you sure you want to mark this call as ${newStatus.toLowerCase()}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Confirm',
          onPress: async () => {
            try {
              await callService.update(call.id!, { billing: newStatus });
              Alert.alert('Success', `Call marked as ${newStatus.toLowerCase()}`);
              setCall({ ...call, billing: newStatus });
            } catch (error) {
              Alert.alert('Error', 'Failed to update billing status');
            }
          }
        }
      ]
    );
  };

  const handleDelete = () => {
    Alert.alert(
      'Delete Response',
      'Are you sure you want to delete this response? This action cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await callService.delete(id as string);
              Alert.alert('Success', 'Response deleted');
              router.back();
            } catch (error) {
              Alert.alert('Error', 'Failed to delete response');
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

  if (!call) {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.errorText}>Response not found</Text>
      </View>
    );
  }

  const amount = call.billable ? (call.billableAmount || 0) : 0;

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scrollView}>
        {/* Header Card */}
        <View style={styles.card}>
          <View style={styles.headerRow}>
            <View style={styles.methodContainer}>
              <Ionicons
                name={
                  call.responseMethod === 'Phone Call' ? 'call' :
                  call.responseMethod === 'Fax' ? 'document' :
                  call.responseMethod === 'Mail' ? 'mail' :
                  call.responseMethod === 'e-services' ? 'globe' :
                  'search'
                }
                size={24}
                color="#2196F3"
              />
              <Text style={styles.methodText}>{call.responseMethod}</Text>
            </View>
            <View
              style={[
                styles.billingBadge,
                { backgroundColor: call.billing === 'Billed' ? '#4CAF50' : '#FF9800' }
              ]}
            >
              <Text style={styles.billingText}>{call.billing}</Text>
            </View>
          </View>

          <Text style={styles.dateText}>{DateUtils.formatDate(call.date)}</Text>
        </View>

        {/* Client & Notice Info */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Related Information</Text>

          <DetailRow
            label="Client"
            value={client?.name || call.clientId}
            icon="person"
          />
          <DetailRow
            label="Notice"
            value={notice?.autoId || notice?.noticeNumber || call.noticeId}
            icon="document-text"
          />
        </View>

        {/* Call Details */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Call Details</Text>

          {call.irsLine && (
            <DetailRow label="IRS Line" value={call.irsLine} />
          )}
          {call.agentId && (
            <DetailRow label="Agent ID" value={call.agentId} />
          )}
          <DetailRow
            label="Duration"
            value={`${call.durationMinutes} minutes`}
          />
        </View>

        {/* Description & Notes */}
        {call.description && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Description</Text>
            <Text style={styles.contentText}>{call.description}</Text>
          </View>
        )}

        {call.issues && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Issues Discussed</Text>
            <Text style={styles.contentText}>{call.issues}</Text>
          </View>
        )}

        {call.notes && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Notes</Text>
            <Text style={styles.contentText}>{call.notes}</Text>
          </View>
        )}

        {call.outcome && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Outcome</Text>
            <Text style={styles.contentText}>{call.outcome}</Text>
          </View>
        )}

        {/* Billing Information */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Billing Information</Text>

          <DetailRow
            label="Billable"
            value={call.billable ? 'Yes' : 'No'}
          />

          {call.billable && (
            <>
              <DetailRow
                label="Duration"
                value={`${call.durationMinutes} minutes`}
              />
              <DetailRow
                label="Hourly Rate"
                value={BillingUtils.formatCurrency(call.hourlyRate || 250)}
              />
              <View style={styles.amountRow}>
                <Text style={styles.amountLabel}>Amount:</Text>
                <Text style={styles.amountValue}>
                  {BillingUtils.formatCurrency(amount)}
                </Text>
              </View>
            </>
          )}
        </View>

        {/* Action Buttons */}
        <View style={styles.actions}>
          <TouchableOpacity
            style={styles.billingButton}
            onPress={handleToggleBilling}
          >
            <Ionicons
              name={call.billing === 'Billed' ? 'close-circle' : 'checkmark-circle'}
              size={20}
              color="#fff"
            />
            <Text style={styles.billingButtonText}>
              Mark as {call.billing === 'Billed' ? 'Unbilled' : 'Billed'}
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.deleteButton}
            onPress={handleDelete}
          >
            <Ionicons name="trash-outline" size={20} color="#fff" />
            <Text style={styles.deleteButtonText}>Delete Response</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </View>
  );
}

function DetailRow({ label, value, icon }: { label: string; value: string; icon?: string }) {
  return (
    <View style={styles.detailRow}>
      {icon && (
        <Ionicons name={icon as any} size={16} color="#666" style={styles.detailIcon} />
      )}
      <Text style={styles.detailLabel}>{label}:</Text>
      <Text style={styles.detailValue}>{value}</Text>
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
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  methodContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  methodText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginLeft: 12,
  },
  billingBadge: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 16,
  },
  billingText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#fff',
  },
  dateText: {
    fontSize: 14,
    color: '#666',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  detailIcon: {
    marginRight: 8,
  },
  detailLabel: {
    fontSize: 14,
    color: '#666',
    fontWeight: '600',
    width: 100,
  },
  detailValue: {
    flex: 1,
    fontSize: 14,
    color: '#333',
  },
  contentText: {
    fontSize: 14,
    color: '#333',
    lineHeight: 20,
  },
  amountRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopColor: '#eee',
    marginTop: 8,
  },
  amountLabel: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
  },
  amountValue: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#4CAF50',
  },
  actions: {
    padding: 16,
    paddingTop: 8,
  },
  billingButton: {
    flexDirection: 'row',
    backgroundColor: '#2196F3',
    borderRadius: 8,
    paddingVertical: 16,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  },
  billingButtonText: {
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