// app/notice/[id].tsx
// Notice Detail screen with POA integration and manual status update

import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  RefreshControl,
  Modal
} from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { noticeService, callService, clientService } from '../../lib/api';
import { Notice, Call, Client, POACheckResult, NoticeStatus } from '../../lib/types';
import { DateUtils, NoticeStatusUtils } from '../../lib/utils';
import { POAChecker } from '../../lib/poaChecker';

export default function NoticeDetailScreen() {
  const { id } = useLocalSearchParams();
  const router = useRouter();

  const [notice, setNotice] = useState<Notice | null>(null);
  const [client, setClient] = useState<Client | null>(null);
  const [calls, setCalls] = useState<Call[]>([]);
  const [poaResult, setPOAResult] = useState<POACheckResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  // Status update modal state
  const [statusModalVisible, setStatusModalVisible] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState<NoticeStatus>('Open');
  const [updatingStatus, setUpdatingStatus] = useState(false);

  // Available status options
  const statusOptions: NoticeStatus[] = [
    'Open',
    'In Progress',
    'Waiting on Client',
    'Awaiting IRS Response',
    'Escalated',
    'Closed'
  ];

  useEffect(() => {
    loadNoticeData();
  }, [id]);

  const loadNoticeData = async () => {
    try {
      const [noticeData, callsData] = await Promise.all([
        noticeService.getById(id as string),
        callService.getByNoticeId(id as string)
      ]);

      if (noticeData) {
        setNotice(noticeData);
        setSelectedStatus(noticeData.status as NoticeStatus);

        // Load client
        const clientData = await clientService.getByClientId(noticeData.clientId);
        setClient(clientData);

        // Check POA
        const poaCheck = await POAChecker.findValidPOA(noticeData);
        setPOAResult(poaCheck);

        // Update notice POA status if changed
        if (noticeData.poaOnFile !== poaCheck.hasValidPOA) {
          await noticeService.update(noticeData.id, {
            poaOnFile: poaCheck.hasValidPOA
          });
          noticeData.poaOnFile = poaCheck.hasValidPOA;
        }
      }

      setCalls(callsData);
    } catch (error) {
      console.error('Error loading notice:', error);
      Alert.alert('Error', 'Failed to load notice data');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const onRefresh = () => {
    setRefreshing(true);
    loadNoticeData();
  };

  const handleStatusUpdate = async () => {
    if (!notice) return;

    setUpdatingStatus(true);
    try {
      // Prepare update data
      const updateData: any = {
        status: selectedStatus
      };

      // If status is being set to "Closed", remove escalated flag
      if (selectedStatus === 'Closed') {
        updateData.escalated = false;
      }

      // If status is being set to "Escalated", set escalated flag
      if (selectedStatus === 'Escalated') {
        updateData.escalated = true;
      }

      await noticeService.update(notice.id, updateData);

      // Update local state
      setNotice({
        ...notice,
        status: selectedStatus,
        escalated: selectedStatus === 'Escalated' ? true :
                   selectedStatus === 'Closed' ? false :
                   notice.escalated
      });

      setStatusModalVisible(false);
      Alert.alert('Success', 'Status updated successfully');
    } catch (error) {
      console.error('Error updating status:', error);
      Alert.alert('Error', 'Failed to update status');
    } finally {
      setUpdatingStatus(false);
    }
  };

  const handleAddCall = () => {
    router.push({
      pathname: '/response/add',
      params: {
        noticeId: id as string,
        clientId: notice?.clientId
      }
    });
  };

  const handleEdit = () => {
    // TODO: Implement edit screen
    Alert.alert('Coming Soon', 'Edit notice functionality will be added');
  };

  const handleDelete = () => {
    Alert.alert(
      'Delete Notice',
      'Are you sure you want to delete this notice?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await noticeService.delete(id as string);
              Alert.alert('Success', 'Notice deleted', [
                { text: 'OK', onPress: () => router.back() }
              ]);
            } catch (error) {
              Alert.alert('Error', 'Failed to delete notice');
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

  if (!notice) {
    return (
      <View style={styles.errorContainer}>
        <Ionicons name="alert-circle-outline" size={64} color="#F44336" />
        <Text style={styles.errorText}>Notice not found</Text>
        <TouchableOpacity style={styles.backButton} onPress={() => router.back()}>
          <Text style={styles.backButtonText}>Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const statusColor = NoticeStatusUtils.getStatusColor(notice.status);

  return (
    <>
      <ScrollView
        style={styles.container}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => router.back()} style={styles.headerBack}>
            <Ionicons name="arrow-back" size={24} color="#333" />
          </TouchableOpacity>
          <View style={styles.headerTitle}>
            <Text style={styles.noticeNumber}>{notice.autoId || notice.noticeNumber}</Text>
            <TouchableOpacity
              style={[styles.statusBadge, { backgroundColor: statusColor }]}
              onPress={() => setStatusModalVisible(true)}
              activeOpacity={0.7}
            >
              <Text style={styles.statusText}>{notice.status}</Text>
              <Ionicons name="chevron-down" size={14} color="#fff" style={styles.statusChevron} />
            </TouchableOpacity>
          </View>
          <TouchableOpacity onPress={handleDelete} style={styles.deleteButton}>
            <Ionicons name="trash-outline" size={24} color="#F44336" />
          </TouchableOpacity>
        </View>

        {/* Status Update Hint */}
        <View style={styles.statusHint}>
          <Ionicons name="information-circle-outline" size={16} color="#666" />
          <Text style={styles.statusHintText}>Tap the status badge to update</Text>
        </View>

        {/* Client Info */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Client</Text>
          <TouchableOpacity
            style={styles.card}
            onPress={() => router.push({
              pathname: '/client/[id]',
              params: { id: notice.clientId }
            })}
          >
            <View style={styles.clientInfo}>
              <Text style={styles.clientName}>{client?.name || 'Unknown Client'}</Text>
              <Text style={styles.clientId}>ID: {notice.clientId}</Text>
            </View>
            <Ionicons name="chevron-forward" size={24} color="#999" />
          </TouchableOpacity>
        </View>

        {/* POA Status */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>POA Status</Text>
          <View style={styles.card}>
            {poaResult?.hasValidPOA ? (
              <View style={styles.poaValid}>
                <View style={styles.poaValidHeader}>
                  <Ionicons name="shield-checkmark" size={32} color="#4CAF50" />
                  <View style={styles.poaValidInfo}>
                    <Text style={styles.poaValidTitle}>Valid POA on File</Text>
                    {poaResult.matchingPOA && (
                      <>
                        <Text style={styles.poaDetail}>
                          Form {poaResult.matchingPOA.form}
                        </Text>
                        <Text style={styles.poaDetail}>
                          {POAChecker.formatPeriodRange(
                            poaResult.matchingPOA.periodStart,
                            poaResult.matchingPOA.periodEnd
                          )}
                        </Text>
                      </>
                    )}
                  </View>
                </View>
                {poaResult.matchingPOA && (
                  <TouchableOpacity
                    style={styles.viewPoaButton}
                    onPress={() => router.push({
                      pathname: '/poa/[id]',
                      params: { id: poaResult.matchingPOA!.id }
                    })}
                  >
                    <Text style={styles.viewPoaText}>View POA Details</Text>
                    <Ionicons name="arrow-forward" size={16} color="#2196F3" />
                  </TouchableOpacity>
                )}
              </View>
            ) : (
              <View style={styles.poaMissing}>
                <View style={styles.poaMissingHeader}>
                  <Ionicons name="alert-circle" size={32} color="#FF9800" />
                  <View style={styles.poaMissingInfo}>
                    <Text style={styles.poaMissingTitle}>Missing POA</Text>
                    <Text style={styles.poaReason}>{poaResult?.reason}</Text>
                  </View>
                </View>
                <TouchableOpacity
                  style={styles.addPoaButton}
                  onPress={() => router.push({
                    pathname: '/poa/add',
                    params: { clientId: notice.clientId }
                  })}
                >
                  <Ionicons name="add-circle" size={20} color="#fff" />
                  <Text style={styles.addPoaText}>Add POA Record</Text>
                </TouchableOpacity>
              </View>
            )}
          </View>
        </View>

        {/* Notice Details */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Notice Details</Text>
          <View style={styles.card}>
            {notice.noticeIssue && (
              <View style={styles.detailRow}>
                <Text style={styles.detailLabel}>Issue:</Text>
                <Text style={styles.detailValue}>{notice.noticeIssue}</Text>
              </View>
            )}

            {notice.formNumber && (
              <View style={styles.detailRow}>
                <Text style={styles.detailLabel}>Form:</Text>
                <Text style={styles.detailValue}>{notice.formNumber}</Text>
              </View>
            )}

            {notice.taxPeriod && (
              <View style={styles.detailRow}>
                <Text style={styles.detailLabel}>Tax Period:</Text>
                <Text style={styles.detailValue}>{notice.taxPeriod}</Text>
              </View>
            )}

            {notice.dateReceived && (
              <View style={styles.detailRow}>
                <Text style={styles.detailLabel}>Date Received:</Text>
                <Text style={styles.detailValue}>
                  {DateUtils.formatDate(notice.dateReceived)}
                </Text>
              </View>
            )}

            {notice.dueDate && (
              <View style={styles.detailRow}>
                <Text style={styles.detailLabel}>Due Date:</Text>
                <Text style={[
                  styles.detailValue,
                  notice.daysRemaining !== null && notice.daysRemaining <= 3 && styles.urgentText
                ]}>
                  {DateUtils.formatDate(notice.dueDate)}
                </Text>
              </View>
            )}

            {notice.daysRemaining !== null && notice.daysRemaining !== undefined && (
              <View style={styles.detailRow}>
                <Text style={styles.detailLabel}>Days Remaining:</Text>
                <Text style={[
                  styles.detailValue,
                  notice.daysRemaining <= 0 ? styles.overdueText :
                  notice.daysRemaining <= 3 ? styles.urgentText : {}
                ]}>
                  {notice.daysRemaining <= 0
                    ? `${Math.abs(notice.daysRemaining)} days overdue`
                    : `${notice.daysRemaining} days`
                  }
                </Text>
              </View>
            )}

            {notice.notes && (
              <View style={styles.detailRow}>
                <Text style={styles.detailLabel}>Notes:</Text>
                <Text style={styles.detailValue}>{notice.notes}</Text>
              </View>
            )}
          </View>
        </View>

        {/* Calls/Responses */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Responses ({calls.length})</Text>
            <TouchableOpacity style={styles.addCallButton} onPress={handleAddCall}>
              <Ionicons name="add" size={20} color="#2196F3" />
              <Text style={styles.addCallText}>Add Response</Text>
            </TouchableOpacity>
          </View>

          {calls.length === 0 ? (
            <View style={styles.card}>
              <Text style={styles.emptyText}>No responses logged yet</Text>
              <TouchableOpacity style={styles.emptyAddButton} onPress={handleAddCall}>
                <Ionicons name="add-circle" size={20} color="#2196F3" />
                <Text style={styles.emptyAddText}>Log First Response</Text>
              </TouchableOpacity>
            </View>
          ) : (
            calls.map((call) => (
              <TouchableOpacity
                key={call.id}
                style={styles.callCard}
                onPress={() => router.push({
                  pathname: '/response/[id]',
                  params: { id: call.id }
                })}
              >
                <View style={styles.callHeader}>
                  <Text style={styles.callDate}>
                    {DateUtils.formatDate(call.date)}
                  </Text>
                  {call.outcome && (
                    <View style={styles.outcomeBadge}>
                      <Text style={styles.outcomeText}>{call.outcome}</Text>
                    </View>
                  )}
                </View>

                {call.description && (
                  <Text style={styles.callDescription} numberOfLines={2}>
                    {call.description}
                  </Text>
                )}

                <View style={styles.callFooter}>
                  {call.responseMethod && (
                    <Text style={styles.callMethod}>{call.responseMethod}</Text>
                  )}
                  {call.durationMinutes && (
                    <Text style={styles.callDuration}>{call.durationMinutes} min</Text>
                  )}
                </View>
              </TouchableOpacity>
            ))
          )}
        </View>

        <View style={{ height: 32 }} />
      </ScrollView>

      {/* Status Update Modal */}
      <Modal
        animationType="slide"
        transparent={true}
        visible={statusModalVisible}
        onRequestClose={() => setStatusModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Update Notice Status</Text>
              <TouchableOpacity
                onPress={() => setStatusModalVisible(false)}
                style={styles.modalClose}
              >
                <Ionicons name="close" size={24} color="#666" />
              </TouchableOpacity>
            </View>

            <View style={styles.modalBody}>
              <Text style={styles.pickerLabel}>Select New Status:</Text>
              <View style={styles.pickerContainer}>
                <Picker
                  selectedValue={selectedStatus}
                  onValueChange={(value) => setSelectedStatus(value)}
                  style={styles.picker}
                >
                  {statusOptions.map((status) => (
                    <Picker.Item
                      key={status}
                      label={status}
                      value={status}
                      color={NoticeStatusUtils.getStatusColor(status)}
                    />
                  ))}
                </Picker>
              </View>

              {/* Status Preview */}
              <View style={styles.statusPreview}>
                <Text style={styles.previewLabel}>Preview:</Text>
                <View
                  style={[
                    styles.previewBadge,
                    { backgroundColor: NoticeStatusUtils.getStatusColor(selectedStatus) }
                  ]}
                >
                  <Text style={styles.previewBadgeText}>{selectedStatus}</Text>
                </View>
              </View>

              {/* Action Buttons */}
              <View style={styles.modalActions}>
                <TouchableOpacity
                  style={styles.cancelButton}
                  onPress={() => {
                    setSelectedStatus(notice.status as NoticeStatus);
                    setStatusModalVisible(false);
                  }}
                >
                  <Text style={styles.cancelButtonText}>Cancel</Text>
                </TouchableOpacity>

                <TouchableOpacity
                  style={[
                    styles.updateButton,
                    updatingStatus && styles.disabledButton
                  ]}
                  onPress={handleStatusUpdate}
                  disabled={updatingStatus}
                >
                  {updatingStatus ? (
                    <ActivityIndicator size="small" color="#fff" />
                  ) : (
                    <Text style={styles.updateButtonText}>Update Status</Text>
                  )}
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </View>
      </Modal>
    </>
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
    marginLeft: 12,
  },
  noticeNumber: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  statusBadge: {
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  statusChevron: {
    marginLeft: 4,
  },
  deleteButton: {
    padding: 4,
  },
  statusHint: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
    paddingHorizontal: 16,
    paddingVertical: 8,
    gap: 8,
  },
  statusHintText: {
    fontSize: 12,
    color: '#666',
    fontStyle: 'italic',
  },
  section: {
    marginTop: 16,
    paddingHorizontal: 16,
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
    marginBottom: 8,
    flexDirection: 'row',
    alignItems: 'center',
  },
  clientInfo: {
    flex: 1,
  },
  clientName: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  clientId: {
    fontSize: 14,
    color: '#666',
  },
  poaValid: {
    flex: 1,
  },
  poaValidHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 16,
    gap: 12,
  },
  poaValidInfo: {
    flex: 1,
  },
  poaValidTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#4CAF50',
    marginBottom: 8,
  },
  poaDetail: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  viewPoaButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#E3F2FD',
    padding: 12,
    borderRadius: 8,
    gap: 8,
  },
  viewPoaText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#2196F3',
  },
  poaMissing: {
    flex: 1,
  },
  poaMissingHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 16,
    gap: 12,
  },
  poaMissingInfo: {
    flex: 1,
  },
  poaMissingTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FF9800',
    marginBottom: 8,
  },
  poaReason: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
  },
  addPoaButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#2196F3',
    padding: 12,
    borderRadius: 8,
    gap: 8,
  },
  addPoaText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#fff',
  },
  detailRow: {
    marginBottom: 12,
  },
  detailLabel: {
    fontSize: 12,
    color: '#999',
    marginBottom: 4,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  detailValue: {
    fontSize: 16,
    color: '#333',
  },
  urgentText: {
    color: '#FF9800',
    fontWeight: '600',
  },
  overdueText: {
    color: '#F44336',
    fontWeight: '600',
  },
  addCallButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  addCallText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#2196F3',
  },
  emptyText: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
    marginBottom: 16,
  },
  emptyAddButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  emptyAddText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#2196F3',
  },
  callCard: {
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
  callHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  callDate: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
  },
  outcomeBadge: {
    backgroundColor: '#E3F2FD',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  outcomeText: {
    fontSize: 12,
    color: '#2196F3',
    fontWeight: '600',
  },
  callDescription: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
    lineHeight: 20,
  },
  callFooter: {
    flexDirection: 'row',
    gap: 16,
  },
  callMethod: {
    fontSize: 12,
    color: '#999',
  },
  callDuration: {
    fontSize: 12,
    color: '#999',
  },

  // Modal Styles
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderRadius: 16,
    width: '90%',
    maxWidth: 400,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
    elevation: 5,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  modalClose: {
    padding: 4,
  },
  modalBody: {
    padding: 20,
  },
  pickerLabel: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
  },
  pickerContainer: {
    backgroundColor: '#F5F5F5',
    borderRadius: 8,
    overflow: 'hidden',
    marginBottom: 20,
  },
  picker: {
    height: 200,
  },
  statusPreview: {
    marginBottom: 20,
  },
  previewLabel: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
  },
  previewBadge: {
    alignSelf: 'flex-start',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 16,
  },
  previewBadgeText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  modalActions: {
    flexDirection: 'row',
    gap: 12,
  },
  cancelButton: {
    flex: 1,
    backgroundColor: '#F5F5F5',
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  cancelButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#666',
  },
  updateButton: {
    flex: 1,
    backgroundColor: '#2196F3',
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  updateButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
  },
  disabledButton: {
    opacity: 0.6,
  },
});