// app/poa/add.tsx
// Add POA Record screen

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
import { Ionicons } from '@expo/vector-icons';
import { poaService, clientService } from '../../lib/api';
import { Client } from '../../lib/types';

export default function AddPOAScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();
  const preSelectedClientId = params.clientId as string | undefined;

  // Form state
  const [selectedClientId, setSelectedClientId] = useState(preSelectedClientId || '');
  const [form, setForm] = useState('2848'); // Default to Form 2848
  const [periodStart, setPeriodStart] = useState('');
  const [periodEnd, setPeriodEnd] = useState('');
  const [electronicCopy, setElectronicCopy] = useState(false);
  const [cafVerified, setCafVerified] = useState(false);
  const [paperCopy, setPaperCopy] = useState(false);
  const [notes, setNotes] = useState('');

  // UI state
  const [clients, setClients] = useState<Client[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [errors, setErrors] = useState<{
    clientId?: string;
    periodStart?: string;
    periodEnd?: string;
  }>({});

  useEffect(() => {
    loadClients();
  }, []);

  const loadClients = async () => {
    try {
      const data = await clientService.getAll();
      console.log('Client data sample:', data[0]); // DEBUG: See what fields clients have
      setClients(data);
    } catch (error) {
      console.error('Error loading clients:', error);
      Alert.alert('Error', 'Failed to load clients');
    }
  };

  const validate = () => {
    const newErrors: {
      clientId?: string;
      periodStart?: string;
      periodEnd?: string;
    } = {};

    if (!selectedClientId) {
      newErrors.clientId = 'Please select a client';
    }

    if (!periodStart.trim()) {
      newErrors.periodStart = 'Start period is required';
    } else if (!/^\d{6}$/.test(periodStart)) {
      newErrors.periodStart = 'Format: YYYYMM (e.g., 202301)';
    }

    if (!periodEnd.trim()) {
      newErrors.periodEnd = 'End period is required';
    } else if (!/^\d{6}$/.test(periodEnd)) {
      newErrors.periodEnd = 'Format: YYYYMM (e.g., 202312)';
    }

    // Validate period range
    if (periodStart && periodEnd && periodStart > periodEnd) {
      newErrors.periodEnd = 'End period must be after start period';
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
      await poaService.create({
        clientId: selectedClientId,
        form,
        periodStart: periodStart.trim(),
        periodEnd: periodEnd.trim(),
        electronicCopy,
        cafVerified,
        paperCopy,
        notes: notes.trim() || undefined,
        dateReceived: new Date(),
      });

      Alert.alert('Success', 'POA record created successfully', [
        {
          text: 'OK',
          onPress: () => router.back()
        }
      ]);
    } catch (error: any) {
      console.error('Error saving POA:', error);
      Alert.alert('Error', error.message || 'Failed to save POA record');
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
          <Text style={styles.headerTitle}>Add POA Record</Text>
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
                    label={`${client.name} (${client.clientId || client.id})`}
                    value={client.clientId || client.id}
                  />
                ))}
              </Picker>
            </View>
            {errors.clientId && (
              <Text style={styles.errorText}>{errors.clientId}</Text>
            )}
          </View>

          {/* Form Type */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>Form Type</Text>
            <View style={styles.pickerContainer}>
              <Picker
                selectedValue={form}
                onValueChange={setForm}
                style={styles.picker}
              >
                <Picker.Item label="Form 2848 (Power of Attorney)" value="2848" />
                <Picker.Item label="Form 8821 (Tax Information Authorization)" value="8821" />
              </Picker>
            </View>
            <Text style={styles.hint}>
              Form 2848 for representation, Form 8821 for information only
            </Text>
          </View>

          {/* Period Start */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>
              Period Start <Text style={styles.required}>*</Text>
            </Text>
            <TextInput
              style={[styles.input, errors.periodStart && styles.inputError]}
              placeholder="YYYYMM (e.g., 202301)"
              value={periodStart}
              onChangeText={setPeriodStart}
              keyboardType="numeric"
              maxLength={6}
            />
            {errors.periodStart && (
              <Text style={styles.errorText}>{errors.periodStart}</Text>
            )}
            <Text style={styles.hint}>Format: YYYYMM (e.g., 202301 for Jan 2023)</Text>
          </View>

          {/* Period End */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>
              Period End <Text style={styles.required}>*</Text>
            </Text>
            <TextInput
              style={[styles.input, errors.periodEnd && styles.inputError]}
              placeholder="YYYYMM (e.g., 202312)"
              value={periodEnd}
              onChangeText={setPeriodEnd}
              keyboardType="numeric"
              maxLength={6}
            />
            {errors.periodEnd && (
              <Text style={styles.errorText}>{errors.periodEnd}</Text>
            )}
            <Text style={styles.hint}>Format: YYYYMM (e.g., 202312 for Dec 2023)</Text>
          </View>

          {/* Flags */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>POA Status</Text>

            <View style={styles.switchRow}>
              <Text style={styles.switchLabel}>Electronic Copy on File</Text>
              <Switch
                value={electronicCopy}
                onValueChange={setElectronicCopy}
                trackColor={{ false: '#ccc', true: '#4CAF50' }}
              />
            </View>

            <View style={styles.switchRow}>
              <Text style={styles.switchLabel}>CAF Verified</Text>
              <Switch
                value={cafVerified}
                onValueChange={setCafVerified}
                trackColor={{ false: '#ccc', true: '#2196F3' }}
              />
            </View>

            <View style={styles.switchRow}>
              <Text style={styles.switchLabel}>Paper Copy on File</Text>
              <Switch
                value={paperCopy}
                onValueChange={setPaperCopy}
                trackColor={{ false: '#ccc', true: '#FF9800' }}
              />
            </View>
          </View>

          {/* Notes */}
          <View style={styles.inputGroup}>
            <Text style={styles.label}>Notes (Optional)</Text>
            <TextInput
              style={[styles.input, styles.textArea]}
              placeholder="Additional notes about this POA..."
              value={notes}
              onChangeText={setNotes}
              multiline
              numberOfLines={4}
              textAlignVertical="top"
            />
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
              <>
                <Ionicons name="checkmark" size={20} color="#fff" />
                <Text style={styles.saveButtonText}>Save POA Record</Text>
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
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
  },
  switchLabel: {
    fontSize: 14,
    color: '#333',
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