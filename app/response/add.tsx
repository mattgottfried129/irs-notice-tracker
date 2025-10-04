// app/response/add.tsx
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
  Alert,
  Switch
} from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { Picker } from '@react-native-picker/picker';
import DateTimePicker from '@react-native-community/datetimepicker';
import { Ionicons } from '@expo/vector-icons';
import { callService, noticeService, clientService } from '../../lib/api';
import { Notice, Client } from '../../lib/types';

export default function AddResponseScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();
  const preSelectedNoticeId = params.noticeId as string | undefined;
  const preSelectedClientId = params.clientId as string | undefined;

  // Form state
  const [selectedNoticeId, setSelectedNoticeId] = useState(preSelectedNoticeId || '');
  const [selectedClientId, setSelectedClientId] = useState(preSelectedClientId || '');
  const [responseMethod, setResponseMethod] = useState('');
  const [irsLine, setIrsLine] = useState('');
  const [agentId, setAgentId] = useState('');
  const [description, setDescription] = useState('');
  const [issues, setIssues] = useState('');
  const [notes, setNotes] = useState('');
  const [outcome, setOutcome] = useState('');
  const [durationMinutes, setDurationMinutes] = useState('');
  const [hourlyRate, setHourlyRate] = useState('250');
  const [billable, setBillable] = useState(true);
  const [responseDate, setResponseDate] = useState(new Date());
  const [followUpDate, setFollowUpDate] = useState<Date | null>(null);

  // UI state
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showFollowUpPicker, setShowFollowUpPicker] = useState(false);
  const [notices, setNotices] = useState<Notice[]>([]);
  const [clients, setClients] = useState<Client[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [noticesData, clientsData] = await Promise.all([
        noticeService.getAll(),
        clientService.getAll()
      ]);
      setNotices(noticesData);
      setClients(clientsData);
    } catch (error) {
      console.error('Error loading data:', error);
      Alert.alert('Error', 'Failed to load data');
    }
  };

  const needsFollowUp = () => {
    return outcome.includes('Waiting') || 
           outcome === 'Monitor Account' || 
           outcome === 'Submit Documentation' ||
           outcome === 'Follow-Up Call';
  };

  const calculateAmount = () => {
    if (!billable) return 0;
    
    const duration = parseInt(durationMinutes) || 0;
    const rate = parseFloat(hourlyRate) || 250;
    const timeBasedAmount = (duration / 60) * rate;

    // Research: actual time rounded to $5
    if (responseMethod.toLowerCase().includes('research')) {
      return Math.ceil(timeBasedAmount / 5) * 5;
    }

    // Non-research: 1-hour minimum
    if (duration >= 60) {
      return Math.ceil(timeBasedAmount / 5) * 5;
    }
    
    return 250; // Minimum fee
  };

  const handleSave = async () => {
    // Validation
    if (!selectedNoticeId) {
      Alert.alert('Error', 'Please select a notice');
      return;
    }
    if (!responseMethod) {
      Alert.alert('Error', 'Please select a response method');
      return;
    }
    if (!outcome) {
      Alert.alert('Error', 'Please select an outcome');
      return;
    }
    if (needsFollowUp() && !followUpDate) {
      Alert.alert('Error', 'Follow-up date is required for this outcome');
      return;
    }

    setIsLoading(true);

    try {
      const duration = parseInt(durationMinutes) || 0;
      const rate = parseFloat(hourlyRate) || 250;

      await callService.create({
        noticeId: selectedNoticeId,
        clientId: selectedClientId || 'UNKNOWN',
        date: responseDate,
        responseMethod,
        irsLine: irsLine || 'N/A',
        agentId: agentId || undefined,
        description: description || undefined,
        issues: issues || undefined,
        notes: notes || undefined,
        outcome: outcome || undefined,
        durationMinutes: duration,
        hourlyRate: rate,
        billable,
        billing: 'Unbilled',
      });

      // Update notice status based on outcome
      await noticeService.updateStatusFromCalls(selectedNoticeId, outcome);

      Alert.alert('Success', 'Response logged successfully', [
        {
          text: 'OK',
          onPress: () => router.back()
        }
      ]);
    } catch (error: any) {
      console.error('Error saving response:', error);
      Alert.alert('Error', error.message || 'Failed to save response');
    } finally {
      setIsLoading(false);
    }
  };

  const filteredNotices = selectedClientId
    ? notices.filter(n => n.clientId === selectedClientId)
    : notices;

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      <ScrollView style={styles.scrollView}>
        <View style={styles.content}>
          {/* Notice Selection */}
          {!preSelectedNoticeId && (
            <View style={styles.inputContainer}>
              <Text style={styles.label}>Notice *</Text>
              <View style={styles.pickerContainer}>
                <Picker
                  selectedValue={selectedNoticeId}
                  onValueChange={(value) => {
                    setSelectedNoticeId(value);
                    const notice = notices.find(n => n.id === value);
                    if (notice) setSelectedClientId(notice.clientId);
                  }}
                >
                  <Picker.Item label="Select a notice..." value="" />
                  {filteredNotices.map(notice => (
                    <Picker.Item
                      key={notice.id}
                      label={`${notice.autoId || notice.noticeNumber} - ${notice.clientId}`}
                      value={notice.id}
                    />
                  ))}
                </Picker>
              </View>
            </View>
          )}

          {/* Response Method */}
          <View style={styles.inputContainer}>
            <Text style={styles.label}>Response Method *</Text>
            <View style={styles.pickerContainer}>
              <Picker selectedValue={responseMethod} onValueChange={setResponseMethod}>
                <Picker.Item label="Select method..." value="" />
                <Picker.Item label="Phone Call" value="Phone Call" />
                <Picker.Item label="Fax" value="Fax" />
                <Picker.Item label="Mail" value="Mail" />
                <Picker.Item label="e-services" value="e-services" />
                <Picker.Item label="Research" value="Research" />
              </Picker>
            </View>
          </View>

          {/* IRS Line */}
          <View style={styles.inputContainer}>
            <Text style={styles.label}>IRS Line Called</Text>
            <View style={styles.pickerContainer}>
              <Picker selectedValue={irsLine} onValueChange={setIrsLine}>
                <Picker.Item label="Select line..." value="" />
                <Picker.Item label="PPS" value="PPS" />
                <Picker.Item label="Collections" value="Collections" />
                <Picker.Item label="Examinations" value="Examinations" />
                <Picker.Item label="Taxpayer Advocate" value="Taxpayer Advocate" />
                <Picker.Item label="Other" value="Other" />
              </Picker>
            </View>
          </View>

          {/* Agent ID */}
          <View style={styles.inputContainer}>
            <Text style={styles.label}>Agent ID</Text>
            <TextInput
              style={styles.input}
              placeholder="IRS Agent ID"
              value={agentId}
              onChangeText={setAgentId}
            />
          </View>



          {/* Issues Discussed */}
          <View style={styles.inputContainer}>
            <Text style={styles.label}>Issues Discussed</Text>
            <TextInput
              style={[styles.input, styles.textArea]}
              placeholder="What was discussed..."
              value={issues}
              onChangeText={setIssues}
              multiline
              numberOfLines={3}
              textAlignVertical="top"
            />
          </View>

          {/* Notes */}
          <View style={styles.inputContainer}>
            <Text style={styles.label}>Notes</Text>
            <TextInput
              style={[styles.input, styles.textArea]}
              placeholder="Additional notes..."
              value={notes}
              onChangeText={setNotes}
              multiline
              numberOfLines={3}
              textAlignVertical="top"
            />
          </View>

          {/* Outcome */}
          <View style={styles.inputContainer}>
            <Text style={styles.label}>Outcome *</Text>
            <View style={styles.pickerContainer}>
              <Picker selectedValue={outcome} onValueChange={setOutcome}>
                <Picker.Item label="Select outcome..." value="" />
                <Picker.Item label="Resolved" value="Resolved" />
                <Picker.Item label="Waiting on Client" value="Waiting on Client" />
                <Picker.Item label="Waiting on IRS" value="Waiting on IRS" />
                <Picker.Item label="Monitor Account" value="Monitor Account" />
                <Picker.Item label="Submit Documentation" value="Submit Documentation" />
                <Picker.Item label="Follow-Up Call" value="Follow-Up Call" />
                <Picker.Item label="Other (Details in Notes)" value="Other (Details in Notes)" />
              </Picker>
            </View>
          </View>

          {/* Follow-up Date (if needed) */}
          {needsFollowUp() && (
            <View style={styles.inputContainer}>
              <Text style={styles.label}>Follow-Up Date *</Text>
              <TouchableOpacity
                style={styles.dateButton}
                onPress={() => setShowFollowUpPicker(true)}
              >
                <Ionicons name="calendar" size={20} color="#666" />
                <Text style={styles.dateButtonText}>
                  {followUpDate ? followUpDate.toLocaleDateString() : 'Select date'}
                </Text>
              </TouchableOpacity>
              {showFollowUpPicker && (
                <DateTimePicker
                  value={followUpDate || new Date()}
                  mode="date"
                  display="default"
                  onChange={(event, date) => {
                    setShowFollowUpPicker(false);
                    if (date) setFollowUpDate(date);
                  }}
                />
              )}
            </View>
          )}

          {/* Billing Section */}
          <View style={styles.billingCard}>
            <Text style={styles.sectionTitle}>Billing Information</Text>
            
            <View style={styles.row}>
              <View style={styles.halfInput}>
                <Text style={styles.label}>Duration (min)</Text>
                <TextInput
                  style={styles.input}
                  placeholder="0"
                  value={durationMinutes}
                  onChangeText={setDurationMinutes}
                  keyboardType="numeric"
                />
              </View>
              <View style={styles.halfInput}>
                <Text style={styles.label}>Hourly Rate ($)</Text>
                <TextInput
                  style={styles.input}
                  placeholder="250"
                  value={hourlyRate}
                  onChangeText={setHourlyRate}
                  keyboardType="numeric"
                />
              </View>
            </View>

            <View style={styles.switchRow}>
              <Text style={styles.label}>Billable</Text>
              <Switch value={billable} onValueChange={setBillable} />
            </View>

            {billable && (
              <View style={styles.amountContainer}>
                <Text style={styles.amountLabel}>Estimated Amount:</Text>
                <Text style={styles.amountValue}>${calculateAmount().toFixed(2)}</Text>
              </View>
            )}
          </View>

          {/* Save Button */}
          <TouchableOpacity
            style={[styles.saveButton, isLoading && styles.saveButtonDisabled]}
            onPress={handleSave}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.saveButtonText}>Save Response</Text>
            )}
          </TouchableOpacity>

          {/* Cancel Button */}
          <TouchableOpacity
            style={styles.cancelButton}
            onPress={() => router.back()}
            disabled={isLoading}
          >
            <Text style={styles.cancelButtonText}>Cancel</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollView: {
    flex: 1,
  },
  content: {
    padding: 16,
  },
  inputContainer: {
    marginBottom: 20,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  input: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    color: '#333',
  },
  textArea: {
    minHeight: 80,
    paddingTop: 12,
  },
  pickerContainer: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    overflow: 'hidden',
  },
  dateButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  dateButtonText: {
    fontSize: 16,
    color: '#333',
    marginLeft: 12,
  },
  billingCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 16,
  },
  row: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 16,
  },
  halfInput: {
    flex: 1,
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  amountContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#E8F5E9',
    padding: 12,
    borderRadius: 8,
  },
  amountLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
  },
  amountValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#4CAF50',
  },
  saveButton: {
    backgroundColor: '#2196F3',
    borderRadius: 8,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 8,
  },
  saveButtonDisabled: {
    opacity: 0.6,
  },
  saveButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  cancelButton: {
    backgroundColor: 'transparent',
    borderRadius: 8,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 8,
  },
  cancelButtonText: {
    color: '#666',
    fontSize: 16,
    fontWeight: '600',
  },
});