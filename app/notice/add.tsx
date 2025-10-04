// app/notice/add.tsx
// Add Notice screen with POA auto-check

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
  Alert
} from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { Picker } from '@react-native-picker/picker';
import DateTimePicker from '@react-native-community/datetimepicker';
import { Ionicons } from '@expo/vector-icons';
import { clientService, noticeService } from '../../lib/api';
import { Client } from '../../lib/types';
import { POAChecker } from '../../lib/poaChecker';

export default function AddNoticeScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();
  const preSelectedClientId = params.clientId as string | undefined;

  // Form state
  const [selectedClientId, setSelectedClientId] = useState(preSelectedClientId || '');
  const [noticeNumber, setNoticeNumber] = useState('');
  const [noticeIssue, setNoticeIssue] = useState('');
  const [formNumber, setFormNumber] = useState('');
  const [taxPeriod, setTaxPeriod] = useState('');
  const [notes, setNotes] = useState('');
  const [noticeDate, setNoticeDate] = useState(new Date());
  const [daysToRespond, setDaysToRespond] = useState('30');

  // UI state
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [clients, setClients] = useState<Client[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [errors, setErrors] = useState<{
    clientId?: string;
    noticeNumber?: string;
  }>({});

  useEffect(() => {
    loadClients();
  }, []);

  const loadClients = async () => {
    try {
      const data = await clientService.getAll();
      setClients(data);
    } catch (error) {
      console.error('Error loading clients:', error);
      Alert.alert('Error', 'Failed to load clients');
    }
  };

  const validate = () => {
    const newErrors: { clientId?: string; noticeNumber?: string } = {};

    if (!selectedClientId) {
      newErrors.clientId = 'Please select a client';
    }

    if (!noticeNumber.trim()) {
      newErrors.noticeNumber = 'Notice number is required';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSave = async () => {
    if (!validate()) {
      return;
    }

    setIsLoading(true);

    try {
      // Generate auto ID
      const autoId = await noticeService.generateAutoId(selectedClientId);

      // Calculate due date
      const dueDate = new Date(noticeDate);
      const daysNum = parseInt(daysToRespond) || 30;
      dueDate.setDate(dueDate.getDate() + daysNum);

      // Create notice
      const newNotice = await noticeService.create({
        clientId: selectedClientId,
        autoId,
        noticeNumber: noticeNumber.trim(),
        noticeIssue: noticeIssue.trim() || undefined,
        formNumber: formNumber.trim() || undefined,
        taxPeriod: taxPeriod.trim() || undefined,
        notes: notes.trim() || undefined,
        dateReceived: noticeDate,
        daysToRespond: daysNum,
        dueDate,
        status: 'Open',
        poaOnFile: false,
        needsPoa: false,
      });

      // Check POA if form and period provided
      if (formNumber.trim() && taxPeriod.trim()) {
        const poaCheck = await POAChecker.findValidPOA({
          ...newNotice,
          formNumber: formNumber.trim(),
          taxPeriod: taxPeriod.trim(),
        } as any);

        // Update notice with POA status
        await noticeService.update(newNotice.id, {
          poaOnFile: poaCheck.hasValidPOA
        });

        // Show alert based on POA status
        if (!poaCheck.hasValidPOA) {
          Alert.alert(
            'Notice Created',
            `Notice ${autoId} created successfully.\n\nNo valid POA found. Would you like to add one?`,
            [
              {
                text: 'Later',
                onPress: () => router.back()
              },
              {
                text: 'Add POA',
                onPress: () => router.replace({
                  pathname: '/poa/add',
                  params: { clientId: selectedClientId }
                })
              }
            ]
          );
        } else {
          Alert.alert(
            'Success',
            `Notice ${autoId} created successfully with valid POA on file.`,
            [{ text: 'OK', onPress: () => router.back() }]
          );
        }
      } else {
        // No form/period to check POA
        Alert.alert(
          'Success',
          `Notice ${autoId} created successfully.`,
          [{ text: 'OK', onPress: () => router.back() }]
        );
      }
    } catch (error: any) {
      console.error('Error saving notice:', error);
      Alert.alert('Error', error.message || 'Failed to save notice');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      <ScrollView style={styles.scrollView}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
            <Ionicons name="arrow-back" size={24} color="#333" />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Add Notice</Text>
        </View>

        <View style={styles.form}>
          {/* Client Selection */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>
              Client <Text style={styles.required}>*</Text>
            </Text>
            <View style={[styles.pickerContainer, errors.clientId && styles.inputError]}>
              <Picker
                selectedValue={selectedClientId}
                onValueChange={setSelectedClientId}
                style={styles.picker}
              >
                <Picker.Item label="Select Client" value="" />
                {clients.map((client) => (
                  <Picker.Item
                    key={client.id}
                    label={`${client.name} (${client.clientId})`}
                    value={client.id}
                  />
                ))}
              </Picker>
            </View>
            {errors.clientId && (
              <Text style={styles.errorText}>{errors.clientId}</Text>
            )}
          </View>

          {/* Notice Number */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>
              Notice Number <Text style={styles.required}>*</Text>
            </Text>
            <TextInput
              style={[styles.input, errors.noticeNumber && styles.inputError]}
              placeholder="Enter notice number"
              value={noticeNumber}
              onChangeText={setNoticeNumber}
            />
            {errors.noticeNumber && (
              <Text style={styles.errorText}>{errors.noticeNumber}</Text>
            )}
          </View>

          {/* Notice Issue */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>Notice Issue</Text>
            <TextInput
              style={styles.input}
              placeholder="e.g., Balance Due, Missing W-2"
              value={noticeIssue}
              onChangeText={setNoticeIssue}
            />
          </View>

          {/* Form Number */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>Form Number</Text>
            <TextInput
              style={styles.input}
              placeholder="e.g., 2848, 8821"
              value={formNumber}
              onChangeText={setFormNumber}
            />
            <Text style={styles.hint}>Required for POA validation</Text>
          </View>

          {/* Tax Period */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>Tax Period</Text>
            <TextInput
              style={styles.input}
              placeholder="e.g., 202301 (YYYYMM)"
              value={taxPeriod}
              onChangeText={setTaxPeriod}
              keyboardType="numeric"
              maxLength={6}
            />
            <Text style={styles.hint}>Format: YYYYMM (Required for POA validation)</Text>
          </View>

          {/* Notice Date */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>Notice Date</Text>
            <TouchableOpacity
              style={styles.dateButton}
              onPress={() => setShowDatePicker(true)}
            >
              <Ionicons name="calendar" size={20} color="#666" />
              <Text style={styles.dateText}>
                {noticeDate.toLocaleDateString()}
              </Text>
            </TouchableOpacity>
            {showDatePicker && (
              <DateTimePicker
                value={noticeDate}
                mode="date"
                display="default"
                onChange={(event, selectedDate) => {
                  setShowDatePicker(false);
                  if (selectedDate) {
                    setNoticeDate(selectedDate);
                  }
                }}
              />
            )}
          </View>

          {/* Days to Respond */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>Days to Respond</Text>
            <TextInput
              style={styles.input}
              placeholder="30"
              value={daysToRespond}
              onChangeText={setDaysToRespond}
              keyboardType="numeric"
            />
          </View>

          {/* Notes */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>Notes</Text>
            <TextInput
              style={[styles.input, styles.textArea]}
              placeholder="Additional notes..."
              value={notes}
              onChangeText={setNotes}
              multiline
              numberOfLines={4}
              textAlignVertical="top"
            />
          </View>

          {/* POA Info Box */}
          {formNumber.trim() && taxPeriod.trim() && (
            <View style={styles.infoBox}>
              <Ionicons name="information-circle" size={20} color="#2196F3" />
              <Text style={styles.infoText}>
                POA status will be automatically checked for Form {formNumber}, Period {taxPeriod}
              </Text>
            </View>
          )}

          {/* Save Button */}
          <TouchableOpacity
            style={[styles.saveButton, isLoading && styles.saveButtonDisabled]}
            onPress={handleSave}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <>
                <Ionicons name="checkmark" size={20} color="#fff" />
                <Text style={styles.saveButtonText}>Create Notice</Text>
              </>
            )}
          </TouchableOpacity>
        </View>

        <View style={{ height: 32 }} />
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
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  backButton: {
    marginRight: 16,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  form: {
    padding: 16,
  },
  inputGroup: {
    marginBottom: 20,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  required: {
    color: '#F44336',
  },
  input: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    color: '#333',
  },
  inputError: {
    borderColor: '#F44336',
  },
  textArea: {
    minHeight: 100,
  },
  pickerContainer: {
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    overflow: 'hidden',
  },
  picker: {
    height: 50,
  },
  hint: {
    fontSize: 12,
    color: '#666',
    marginTop: 4,
    fontStyle: 'italic',
  },
  errorText: {
    fontSize: 12,
    color: '#F44336',
    marginTop: 4,
  },
  dateButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    padding: 12,
    gap: 8,
  },
  dateText: {
    fontSize: 16,
    color: '#333',
  },
  infoBox: {
    flexDirection: 'row',
    backgroundColor: '#E3F2FD',
    padding: 12,
    borderRadius: 8,
    marginBottom: 20,
    gap: 8,
  },
  infoText: {
    flex: 1,
    fontSize: 14,
    color: '#1976D2',
    lineHeight: 20,
  },
  saveButton: {
    flexDirection: 'row',
    backgroundColor: '#2196F3',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 8,
    gap: 8,
  },
  saveButtonDisabled: {
    backgroundColor: '#ccc',
  },
  saveButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});