// app/(tabs)/dashboard.tsx
// Responsive dashboard with adaptive card sizing for web and mobile

import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  RefreshControl,
  Alert,
  Dimensions,
  Platform
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { noticeService, clientService, callService } from '../../lib/api';
import { Notice } from '../../lib/types';
import { DateUtils } from '../../lib/utils';
import { useAutoEscalation } from '../../hooks/useEscalation';
import { EscalationService } from '../../lib/escalationService';

interface DashboardStats {
  totalClients: number;
  activeNotices: number;
  escalatedNotices: number;
  dueThisWeek: number;
  missingPOA: number;
  closedThisMonth: number;
  totalResponses: number;
}

// Get screen dimensions for responsive design
const windowDimensions = Dimensions.get('window');

export default function DashboardScreen() {
  const router = useRouter();
  const [screenWidth, setScreenWidth] = useState(windowDimensions.width);

  // Auto-escalation on mount
  const { isUpdating: autoUpdating, updateCount } = useAutoEscalation(true);

  const [stats, setStats] = useState<DashboardStats>({
    totalClients: 0,
    activeNotices: 0,
    escalatedNotices: 0,
    dueThisWeek: 0,
    missingPOA: 0,
    closedThisMonth: 0,
    totalResponses: 0,
  });

  const [dueSoonNotices, setDueSoonNotices] = useState<Notice[]>([]);
  const [escalatedNotices, setEscalatedNotices] = useState<Notice[]>([]);
  const [missingPOANotices, setMissingPOANotices] = useState<Notice[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);

  // Update screen width on dimension change
  useEffect(() => {
    const subscription = Dimensions.addEventListener('change', ({ window }) => {
      setScreenWidth(window.width);
    });
    return () => subscription?.remove();
  }, []);

  useEffect(() => {
    loadDashboard();
  }, [refreshKey]);

  const loadDashboard = async () => {
    try {
      // Load all data
      const [clients, notices, calls] = await Promise.all([
        clientService.getAll(),
        noticeService.getAll(),
        callService.getAll()
      ]);

      // Calculate stats
      const activeNotices = notices.filter(n =>
        n.status !== 'Closed' && n.status !== 'Resolved'
      );

      // Filter escalated - MUST be active AND escalated
      const escalated = notices.filter(n =>
        n.escalated === true &&
        n.status !== 'Closed' &&
        n.status !== 'Resolved'
      );

      const dueSoon = await EscalationService.getNoticesDueSoon(7);

      const missingPOA = notices.filter(n =>
        !n.poaOnFile &&
        n.status !== 'Closed' &&
        n.status !== 'Resolved'
      );

      const now = new Date();
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      const closedThisMonth = notices.filter(n => {
        if (!n.dateCompleted) return false;
        const completedDate = new Date(n.dateCompleted);
        return completedDate >= startOfMonth && n.status === 'Closed';
      });

      setStats({
        totalClients: clients.length,
        activeNotices: activeNotices.length,
        escalatedNotices: escalated.length,
        dueThisWeek: dueSoon.length,
        missingPOA: missingPOA.length,
        closedThisMonth: closedThisMonth.length,
        totalResponses: calls.length,
      });

      // Set lists
      setDueSoonNotices(dueSoon.slice(0, 10));
      setEscalatedNotices(escalated.slice(0, 10));
      setMissingPOANotices(missingPOA.slice(0, 10));

    } catch (error) {
      console.error('Error loading dashboard:', error);
      Alert.alert('Error', 'Failed to load dashboard data');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    // Trigger manual escalation update on refresh
    try {
      await EscalationService.updateAllNotices();
    } catch (error) {
      console.error('Error updating notices:', error);
    }
    await loadDashboard();
  };

  const handleNoticePress = (notice: Notice) => {
    router.push({
      pathname: '/notice/[id]',
      params: { id: notice.id }
    });
  };

  // Responsive style calculations
  const getResponsiveStyles = () => {
    const isWeb = Platform.OS === 'web';
    const isLargeScreen = screenWidth >= 1024;
    const isMediumScreen = screenWidth >= 768 && screenWidth < 1024;
    const isSmallScreen = screenWidth < 768;

    // Calculate card width based on screen size
    let cardWidth = '47%'; // Default for mobile (2 columns)
    let cardAspectRatio = 1;
    let cardPadding = 16;
    let iconSize = 32;
    let statFontSize = 36;
    let labelFontSize = 14;
    let maxCardWidth = undefined;

    if (isWeb) {
      if (isLargeScreen) {
        // Large screens (desktop) - 3 columns
        cardWidth = '31%';
        cardAspectRatio = 1.2;
        maxCardWidth = 250;
        cardPadding = 20;
        iconSize = 28;
        statFontSize = 32;
        labelFontSize = 13;
      } else if (isMediumScreen) {
        // Medium screens (tablet) - 3 columns but smaller
        cardWidth = '31%';
        cardAspectRatio = 1.1;
        maxCardWidth = 200;
        cardPadding = 16;
        iconSize = 26;
        statFontSize = 28;
        labelFontSize = 12;
      } else {
        // Small screens - 2 columns
        cardWidth = '47%';
        cardAspectRatio = 1;
        cardPadding = 14;
        iconSize = 28;
        statFontSize = 28;
        labelFontSize = 12;
      }
    }

    return {
      cardWidth,
      cardAspectRatio,
      cardPadding,
      iconSize,
      statFontSize,
      labelFontSize,
      maxCardWidth,
      isWeb,
      isLargeScreen,
      isMediumScreen,
      isSmallScreen
    };
  };

  const responsiveStyles = getResponsiveStyles();

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2196F3" />
        <Text style={styles.loadingText}>Loading dashboard...</Text>
        {autoUpdating && (
          <Text style={styles.updateText}>Updating notice statuses...</Text>
        )}
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      {/* Auto-update banner */}
      {autoUpdating && (
        <View style={styles.updateBanner}>
          <ActivityIndicator size="small" color="#fff" />
          <Text style={styles.updateBannerText}>
            Updating notice statuses...
          </Text>
        </View>
      )}

      {/* Update success message */}
      {updateCount > 0 && !autoUpdating && (
        <View style={styles.successBanner}>
          <Ionicons name="checkmark-circle" size={20} color="#fff" />
          <Text style={styles.successBannerText}>
            {updateCount} notice{updateCount !== 1 ? 's' : ''} updated
          </Text>
        </View>
      )}

      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.headerTitle}>IRS Notice Tracker</Text>
          <Text style={styles.headerSubtitle}>
            {new Date().toLocaleDateString('en-US', {
              weekday: 'long',
              year: 'numeric',
              month: 'long',
              day: 'numeric'
            })}
          </Text>
        </View>
        <TouchableOpacity
          style={styles.adminButton}
          onPress={() => router.push('/admin')}
        >
          <Ionicons name="settings" size={24} color="#666" />
        </TouchableOpacity>
      </View>

      {/* Stats Grid - Responsive */}
      <View style={[
        styles.statsGrid,
        responsiveStyles.isWeb && responsiveStyles.isLargeScreen && styles.statsGridWeb
      ]}>
        <TouchableOpacity
          style={[
            styles.statCard,
            {
              backgroundColor: '#FF9800',
              width: responsiveStyles.cardWidth,
              aspectRatio: responsiveStyles.cardAspectRatio,
              padding: responsiveStyles.cardPadding,
              maxWidth: responsiveStyles.maxCardWidth
            }
          ]}
          onPress={() => router.push('/(tabs)/notices')}
        >
          <Ionicons name="document-text" size={responsiveStyles.iconSize} color="#fff" />
          <Text style={[styles.statNumber, { fontSize: responsiveStyles.statFontSize }]}>
            {stats.activeNotices}
          </Text>
          <Text style={[styles.statLabel, { fontSize: responsiveStyles.labelFontSize }]}>
            Active Notices
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.statCard,
            {
              backgroundColor: '#F44336',
              width: responsiveStyles.cardWidth,
              aspectRatio: responsiveStyles.cardAspectRatio,
              padding: responsiveStyles.cardPadding,
              maxWidth: responsiveStyles.maxCardWidth
            }
          ]}
          onPress={() => router.push('/(tabs)/notices')}
        >
          <Ionicons name="warning" size={responsiveStyles.iconSize} color="#fff" />
          <Text style={[styles.statNumber, { fontSize: responsiveStyles.statFontSize }]}>
            {stats.escalatedNotices}
          </Text>
          <Text style={[styles.statLabel, { fontSize: responsiveStyles.labelFontSize }]}>
            Escalated
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.statCard,
            {
              backgroundColor: '#9C27B0',
              width: responsiveStyles.cardWidth,
              aspectRatio: responsiveStyles.cardAspectRatio,
              padding: responsiveStyles.cardPadding,
              maxWidth: responsiveStyles.maxCardWidth
            }
          ]}
        >
          <Ionicons name="time" size={responsiveStyles.iconSize} color="#fff" />
          <Text style={[styles.statNumber, { fontSize: responsiveStyles.statFontSize }]}>
            {stats.dueThisWeek}
          </Text>
          <Text style={[styles.statLabel, { fontSize: responsiveStyles.labelFontSize }]}>
            Due This Week
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.statCard,
            {
              backgroundColor: '#FF6B6B',
              width: responsiveStyles.cardWidth,
              aspectRatio: responsiveStyles.cardAspectRatio,
              padding: responsiveStyles.cardPadding,
              maxWidth: responsiveStyles.maxCardWidth
            }
          ]}
        >
          <Ionicons name="document-lock" size={responsiveStyles.iconSize} color="#fff" />
          <Text style={[styles.statNumber, { fontSize: responsiveStyles.statFontSize }]}>
            {stats.missingPOA}
          </Text>
          <Text style={[styles.statLabel, { fontSize: responsiveStyles.labelFontSize }]}>
            Missing POA
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.statCard,
            {
              backgroundColor: '#4CAF50',
              width: responsiveStyles.cardWidth,
              aspectRatio: responsiveStyles.cardAspectRatio,
              padding: responsiveStyles.cardPadding,
              maxWidth: responsiveStyles.maxCardWidth
            }
          ]}
        >
          <Ionicons name="checkmark-circle" size={responsiveStyles.iconSize} color="#fff" />
          <Text style={[styles.statNumber, { fontSize: responsiveStyles.statFontSize }]}>
            {stats.closedThisMonth}
          </Text>
          <Text style={[styles.statLabel, { fontSize: responsiveStyles.labelFontSize }]}>
            Closed This Month
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.statCard,
            {
              backgroundColor: '#00BCD4',
              width: responsiveStyles.cardWidth,
              aspectRatio: responsiveStyles.cardAspectRatio,
              padding: responsiveStyles.cardPadding,
              maxWidth: responsiveStyles.maxCardWidth
            }
          ]}
          onPress={() => router.push('/(tabs)/responses')}
        >
          <Ionicons name="call" size={responsiveStyles.iconSize} color="#fff" />
          <Text style={[styles.statNumber, { fontSize: responsiveStyles.statFontSize }]}>
            {stats.totalResponses}
          </Text>
          <Text style={[styles.statLabel, { fontSize: responsiveStyles.labelFontSize }]}>
            Total Responses
          </Text>
        </TouchableOpacity>
      </View>

      {/* Content wrapper for large screens */}
      <View style={[
        styles.contentWrapper,
        responsiveStyles.isWeb && responsiveStyles.isLargeScreen && styles.contentWrapperWeb
      ]}>
        {/* Due Soon Section - FIRST */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Ionicons name="time" size={24} color="#FF9800" />
            <Text style={styles.sectionTitle}>Due Soon (Next 7 Days)</Text>
          </View>
          {dueSoonNotices.length === 0 ? (
            <View style={styles.emptyState}>
              <Ionicons name="checkmark-circle-outline" size={48} color="#4CAF50" />
              <Text style={styles.emptyStateText}>No notices due in the next 7 days</Text>
            </View>
          ) : (
            dueSoonNotices.map(notice => (
              <TouchableOpacity
                key={notice.id}
                style={styles.noticeItem}
                onPress={() => handleNoticePress(notice)}
              >
                <View style={styles.noticeHeader}>
                  <Text style={styles.noticeNumber}>{notice.autoId || notice.noticeNumber}</Text>
                  {notice.escalated && (
                    <View style={styles.escalatedBadge}>
                      <Text style={styles.escalatedBadgeText}>ESCALATED</Text>
                    </View>
                  )}
                </View>
                <Text style={styles.noticeIssue} numberOfLines={1}>
                  {notice.noticeIssue || 'No issue specified'}
                </Text>
                <View style={styles.noticeFooter}>
                  {notice.dueDate && (
                    <Text style={styles.dueDate}>
                      Due: {DateUtils.formatDate(notice.dueDate)}
                    </Text>
                  )}
                  {notice.daysRemaining !== null && notice.daysRemaining !== undefined && (
                    <Text style={[
                      styles.daysRemaining,
                      notice.daysRemaining <= 3 && styles.urgent
                    ]}>
                      {notice.daysRemaining} days
                    </Text>
                  )}
                </View>
                {!notice.poaOnFile && (
                  <View style={styles.poaWarning}>
                    <Ionicons name="alert-circle" size={16} color="#FF9800" />
                    <Text style={styles.poaWarningText}>Missing POA</Text>
                  </View>
                )}
              </TouchableOpacity>
            ))
          )}
        </View>

        {/* Escalated Notices Section */}
        {escalatedNotices.length > 0 && (
          <View style={styles.section}>
            <View style={styles.sectionHeader}>
              <Ionicons name="warning" size={24} color="#F44336" />
              <Text style={styles.sectionTitle}>Escalated Notices</Text>
            </View>
            {escalatedNotices.map(notice => (
              <TouchableOpacity
                key={notice.id}
                style={styles.noticeItem}
                onPress={() => handleNoticePress(notice)}
              >
                <View style={styles.noticeHeader}>
                  <Text style={styles.noticeNumber}>{notice.autoId || notice.noticeNumber}</Text>
                  <View style={styles.escalatedBadge}>
                    <Text style={styles.escalatedBadgeText}>ESCALATED</Text>
                  </View>
                </View>
                <Text style={styles.noticeIssue} numberOfLines={1}>
                  {notice.noticeIssue || 'No issue specified'}
                </Text>
                <View style={styles.noticeFooter}>
                  {notice.daysRemaining !== null && notice.daysRemaining !== undefined && (
                    <Text style={[
                      styles.daysRemaining,
                      notice.daysRemaining <= 0 && styles.overdue,
                      notice.daysRemaining > 0 && notice.daysRemaining <= 3 && styles.urgent
                    ]}>
                      {notice.daysRemaining <= 0
                        ? `${Math.abs(notice.daysRemaining)} days overdue`
                        : `${notice.daysRemaining} days remaining`
                      }
                    </Text>
                  )}
                </View>
              </TouchableOpacity>
            ))}
          </View>
        )}

        {/* Missing POA Section */}
        {missingPOANotices.length > 0 && (
          <View style={styles.section}>
            <View style={styles.sectionHeader}>
              <Ionicons name="document-lock" size={24} color="#FF6B6B" />
              <Text style={styles.sectionTitle}>Missing POA</Text>
            </View>
            {missingPOANotices.map(notice => (
              <TouchableOpacity
                key={notice.id}
                style={styles.noticeItem}
                onPress={() => handleNoticePress(notice)}
              >
                <View style={styles.noticeHeader}>
                  <Text style={styles.noticeNumber}>{notice.autoId || notice.noticeNumber}</Text>
                  {notice.escalated && (
                    <View style={styles.escalatedBadge}>
                      <Text style={styles.escalatedBadgeText}>ESCALATED</Text>
                    </View>
                  )}
                </View>
                <Text style={styles.noticeIssue} numberOfLines={1}>
                  {notice.noticeIssue || 'No issue specified'}
                </Text>
                <View style={styles.noticeFooter}>
                  {notice.dueDate && (
                    <Text style={styles.dueDate}>
                      Due: {DateUtils.formatDate(notice.dueDate)}
                    </Text>
                  )}
                  <Text style={styles.status}>{notice.status}</Text>
                </View>
                <View style={styles.poaWarning}>
                  <Ionicons name="alert-circle" size={16} color="#FF9800" />
                  <Text style={styles.poaWarningText}>POA Required</Text>
                </View>
              </TouchableOpacity>
            ))}
          </View>
        )}

        {/* Quick Actions */}
        <View style={styles.quickActions}>
          <TouchableOpacity
            style={styles.actionButton}
            onPress={() => router.push('/notice/add')}
          >
            <Ionicons name="add-circle" size={24} color="#fff" />
            <Text style={styles.actionButtonText}>Add Notice</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.actionButton, { backgroundColor: '#4CAF50' }]}
            onPress={() => router.push('/client/add')}
          >
            <Ionicons name="person-add" size={24} color="#fff" />
            <Text style={styles.actionButtonText}>Add Client</Text>
          </TouchableOpacity>
        </View>
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
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
  updateText: {
    marginTop: 8,
    fontSize: 14,
    color: '#2196F3',
  },
  updateBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#2196F3',
    padding: 12,
    gap: 8,
  },
  updateBannerText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  successBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#4CAF50',
    padding: 12,
    gap: 8,
  },
  successBannerText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  adminButton: {
    padding: 8,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  headerSubtitle: {
    fontSize: 14,
    color: '#666',
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    padding: 12,
    gap: 12,
  },
  statsGridWeb: {
    maxWidth: 1200,
    alignSelf: 'center',
    width: '100%',
  },
  statCard: {
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  statNumber: {
    fontWeight: 'bold',
    color: '#fff',
    marginTop: 8,
  },
  statLabel: {
    color: '#fff',
    marginTop: 4,
    textAlign: 'center',
  },
  contentWrapper: {
    flex: 1,
  },
  contentWrapperWeb: {
    maxWidth: 1200,
    alignSelf: 'center',
    width: '100%',
  },
  section: {
    backgroundColor: '#fff',
    marginHorizontal: 12,
    marginBottom: 12,
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
    gap: 8,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  noticeItem: {
    padding: 12,
    backgroundColor: '#f9f9f9',
    borderRadius: 8,
    marginBottom: 8,
    borderLeftWidth: 4,
    borderLeftColor: '#2196F3',
  },
  noticeHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  noticeNumber: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  escalatedBadge: {
    backgroundColor: '#F44336',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  escalatedBadgeText: {
    color: '#fff',
    fontSize: 10,
    fontWeight: 'bold',
  },
  noticeIssue: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
  },
  noticeFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dueDate: {
    fontSize: 12,
    color: '#666',
  },
  daysRemaining: {
    fontSize: 12,
    fontWeight: '600',
    color: '#4CAF50',
  },
  status: {
    fontSize: 12,
    color: '#666',
    fontWeight: '500',
  },
  urgent: {
    color: '#FF9800',
  },
  overdue: {
    color: '#F44336',
  },
  poaWarning: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    gap: 6,
  },
  poaWarningText: {
    fontSize: 12,
    color: '#FF9800',
    fontWeight: '600',
  },
  emptyState: {
    alignItems: 'center',
    padding: 32,
  },
  emptyStateText: {
    fontSize: 14,
    color: '#666',
    marginTop: 8,
    textAlign: 'center',
  },
  quickActions: {
    flexDirection: 'row',
    gap: 12,
    marginHorizontal: 12,
    marginBottom: 12,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#2196F3',
    padding: 16,
    borderRadius: 12,
    gap: 8,
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});