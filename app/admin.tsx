// app/admin.tsx
// Admin screen with cleanup tools

import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Alert
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { cleanupClosedNotices } from '../lib/cleanupClosedNotices';
import { EscalationService } from '../lib/escalationService';
import { debugEscalatedNotices } from '../lib/debugEscalated';

export default function AdminScreen() {
  const router = useRouter();
  const [isRunningCleanup, setIsRunningCleanup] = useState(false);
  const [isRunningUpdate, setIsRunningUpdate] = useState(false);
  const [isDebugging, setIsDebugging] = useState(false);
  const [cleanupResults, setCleanupResults] = useState<{
    total: number;
    fixed: number;
    errors: string[];
  } | null>(null);

  const handleCleanupClosed = async () => {
    Alert.alert(
      'Cleanup Closed Notices',
      'This will remove escalation flags from all closed notices. Continue?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Run Cleanup',
          style: 'destructive',
          onPress: async () => {
            setIsRunningCleanup(true);
            setCleanupResults(null);

            try {
              const results = await cleanupClosedNotices();
              setCleanupResults(results);

              if (results.errors.length === 0) {
                Alert.alert(
                  'Success!',
                  `Fixed ${results.fixed} of ${results.total} notices. Please go back to refresh the dashboard.`,
                  [
                    {
                      text: 'Go to Dashboard',
                      onPress: () => router.replace('/(tabs)/dashboard')
                    }
                  ]
                );
              } else {
                Alert.alert(
                  'Partially Complete',
                  `Fixed ${results.fixed} of ${results.total} notices. ${results.errors.length} errors occurred.`
                );
              }
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Cleanup failed');
            } finally {
              setIsRunningCleanup(false);
            }
          }
        }
      ]
    );
  };

  const handleUpdateAll = async () => {
    Alert.alert(
      'Update All Notices',
      'This will recalculate status and escalation for all active notices. Continue?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Update All',
          onPress: async () => {
            setIsRunningUpdate(true);

            try {
              const count = await EscalationService.updateAllNotices();
              Alert.alert('Success!', `Updated ${count} notices`);
            } catch (error: any) {
              Alert.alert('Error', error.message || 'Update failed');
            } finally {
              setIsRunningUpdate(false);
            }
          }
        }
      ]
    );
  };

  const handleDebug = async () => {
    setIsDebugging(true);
    try {
      const results = await debugEscalatedNotices();
      if (results && results.closedButEscalated > 0) {
        Alert.alert(
          'Issues Found',
          `Found ${results.closedButEscalated} closed notices still marked as escalated. Check console for details.`,
          [
            {
              text: 'Run Cleanup',
              onPress: () => handleCleanupClosed()
            },
            {
              text: 'OK',
              style: 'cancel'
            }
          ]
        );
      } else {
        Alert.alert('All Good!', 'No issues found with escalated notices.');
      }
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Debug failed');
    } finally {
      setIsDebugging(false);
    }
  };

  return (
    <ScrollView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Ionicons name="arrow-back" size={24} color="#333" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Admin Tools</Text>
      </View>

      {/* Warning Banner */}
      <View style={styles.warningBanner}>
        <Ionicons name="warning" size={24} color="#FF9800" />
        <Text style={styles.warningText}>
          These tools modify database records. Use with caution.
        </Text>
      </View>

      {/* Debug Escalated - FIRST for quick access */}
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Ionicons name="bug" size={24} color="#9C27B0" />
          <Text style={styles.cardTitle}>Debug Escalated Notices</Text>
        </View>
        <Text style={styles.cardDescription}>
          Checks Firestore database for notices marked as escalated and verifies they should be.
          Check console output for detailed results.
        </Text>
        <TouchableOpacity
          style={[styles.button, { backgroundColor: '#9C27B0' }]}
          onPress={handleDebug}
          disabled={isDebugging}
        >
          {isDebugging ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <>
              <Ionicons name="search" size={20} color="#fff" />
              <Text style={styles.buttonText}>Run Debug</Text>
            </>
          )}
        </TouchableOpacity>
      </View>

      {/* Cleanup Closed Notices */}
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Ionicons name="construct" size={24} color="#F44336" />
          <Text style={styles.cardTitle}>Cleanup Closed Notices</Text>
        </View>
        <Text style={styles.cardDescription}>
          Removes escalation flags from all closed/resolved notices. Use this to fix
          notices that were incorrectly marked as escalated before the logic was fixed.
        </Text>
        <TouchableOpacity
          style={[styles.button, styles.dangerButton]}
          onPress={handleCleanupClosed}
          disabled={isRunningCleanup}
        >
          {isRunningCleanup ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <>
              <Ionicons name="checkmark-done" size={20} color="#fff" />
              <Text style={styles.buttonText}>Run Cleanup</Text>
            </>
          )}
        </TouchableOpacity>

        {/* Cleanup Results */}
        {cleanupResults && (
          <View style={styles.results}>
            <Text style={styles.resultsTitle}>Results:</Text>
            <Text style={styles.resultsText}>
              • Found: {cleanupResults.total} notices
            </Text>
            <Text style={styles.resultsText}>
              • Fixed: {cleanupResults.fixed} notices
            </Text>
            {cleanupResults.errors.length > 0 && (
              <Text style={[styles.resultsText, { color: '#F44336' }]}>
                • Errors: {cleanupResults.errors.length}
              </Text>
            )}
          </View>
        )}
      </View>

      {/* Update All Notices */}
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Ionicons name="refresh" size={24} color="#2196F3" />
          <Text style={styles.cardTitle}>Update All Notices</Text>
        </View>
        <Text style={styles.cardDescription}>
          Recalculates status, escalation, and days remaining for all active notices.
          This runs automatically on dashboard load, but you can manually trigger it here.
        </Text>
        <TouchableOpacity
          style={[styles.button, styles.primaryButton]}
          onPress={handleUpdateAll}
          disabled={isRunningUpdate}
        >
          {isRunningUpdate ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <>
              <Ionicons name="sync" size={20} color="#fff" />
              <Text style={styles.buttonText}>Update All</Text>
            </>
          )}
        </TouchableOpacity>
      </View>

      {/* Instructions */}
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Ionicons name="information-circle" size={24} color="#00BCD4" />
          <Text style={styles.cardTitle}>When to Use</Text>
        </View>
        <Text style={styles.instructionText}>
          <Text style={styles.bold}>Debug:</Text> Run this first to see what's actually in
          the database. Check console for detailed output.
        </Text>
        <Text style={styles.instructionText}>
          <Text style={styles.bold}>Cleanup Closed Notices:</Text> Run this once if you notice
          closed notices showing as escalated. This is typically only needed after upgrading
          the escalation logic.
        </Text>
        <Text style={styles.instructionText}>
          <Text style={styles.bold}>Update All Notices:</Text> Use this if notice statuses
          seem outdated or incorrect. The app already runs this automatically, so manual
          use is rarely needed.
        </Text>
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
  warningBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF3E0',
    padding: 16,
    margin: 16,
    borderRadius: 8,
    gap: 12,
  },
  warningText: {
    flex: 1,
    fontSize: 14,
    color: '#E65100',
    fontWeight: '500',
  },
  card: {
    backgroundColor: '#fff',
    marginHorizontal: 16,
    marginBottom: 16,
    borderRadius: 12,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
    gap: 12,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  cardDescription: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
    marginBottom: 16,
  },
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
    borderRadius: 8,
    gap: 8,
  },
  primaryButton: {
    backgroundColor: '#2196F3',
  },
  dangerButton: {
    backgroundColor: '#F44336',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  results: {
    marginTop: 16,
    padding: 12,
    backgroundColor: '#f9f9f9',
    borderRadius: 8,
  },
  resultsTitle: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  resultsText: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  instructionText: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
    marginBottom: 12,
  },
  bold: {
    fontWeight: 'bold',
    color: '#333',
  },
});