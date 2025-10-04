// lib/escalationService.ts
// Client-side automatic escalation update service
// Updates notice statuses when app loads or on demand

import { noticeService, callService } from './api';
import { NoticeLogic } from './noticeLogic';
import { Notice } from './types';

export class EscalationService {
  /**
   * Update a single notice's derived fields
   * Returns true if any fields were updated
   */
  static async updateNoticeStatus(noticeId: string): Promise<boolean> {
    try {
      // Get notice and its calls
      const notice = await noticeService.getById(noticeId);
      if (!notice) return false;

      // Skip if already closed
      if (notice.status === 'Closed' || notice.status === 'Resolved') {
        console.log(`⏭️  Skipping closed notice ${noticeId}`);
        return false;
      }

      const calls = await callService.getByNoticeId(noticeId);

      // Calculate derived fields
      const derived = NoticeLogic.calculateDerivedFields(notice, calls);

      // If status became closed, ensure escalated is false
      if (derived.status === 'Closed' || derived.status === 'Resolved') {
        derived.escalated = false;
      }

      // Check if anything changed
      const hasChanges =
        notice.status !== derived.status ||
        notice.escalated !== derived.escalated ||
        notice.daysRemaining !== derived.daysRemaining;

      if (!hasChanges) return false;

      // Update in Firestore
      await noticeService.update(noticeId, {
        status: derived.status as any,
        escalated: derived.escalated,
        daysRemaining: derived.daysRemaining,
        responseDeadline: derived.responseDeadline || undefined
      });

      console.log(`✅ Updated notice ${noticeId}: ${derived.status} (escalated: ${derived.escalated})`);
      return true;
    } catch (error) {
      console.error(`Error updating notice ${noticeId}:`, error);
      return false;
    }
  }

  /**
   * Update all open/active notices
   * Returns count of updated notices
   */
  static async updateAllNotices(): Promise<number> {
    try {
      console.log('🔄 Starting auto-escalation update for all notices...');

      // Get all notices
      const allNotices = await noticeService.getAll();

      // Filter to only open/active notices (not closed)
      const activeNotices = allNotices.filter(n =>
        n.status !== 'Closed' && n.status !== 'Resolved'
      );

      console.log(`📋 Found ${activeNotices.length} active notices to check`);

      let updateCount = 0;

      // Update each notice
      for (const notice of activeNotices) {
        const updated = await this.updateNoticeStatus(notice.id);
        if (updated) updateCount++;
      }

      console.log(`✅ Auto-escalation update complete: ${updateCount} notices updated`);
      return updateCount;
    } catch (error) {
      console.error('Error updating all notices:', error);
      throw error;
    }
  }

  /**
   * Update notices for a specific client
   * Useful when adding/updating calls for a client
   */
  static async updateClientNotices(clientId: string): Promise<number> {
    try {
      const clientNotices = await noticeService.getByClientId(clientId);
      const activeNotices = clientNotices.filter(n =>
        n.status !== 'Closed' && n.status !== 'Resolved'
      );

      let updateCount = 0;
      for (const notice of activeNotices) {
        const updated = await this.updateNoticeStatus(notice.id);
        if (updated) updateCount++;
      }

      return updateCount;
    } catch (error) {
      console.error(`Error updating client ${clientId} notices:`, error);
      throw error;
    }
  }

  /**
   * Get notices that need escalation (for dashboard/alerts)
   */
  static async getEscalatedNotices(): Promise<Notice[]> {
    try {
      const allNotices = await noticeService.getAll();
      const activeNotices = allNotices.filter(n =>
        n.status !== 'Closed' && n.status !== 'Resolved'
      );

      const escalated: Notice[] = [];

      for (const notice of activeNotices) {
        const calls = await callService.getByNoticeId(notice.id);
        if (NoticeLogic.isEscalated(notice, calls)) {
          escalated.push(notice);
        }
      }

      return escalated;
    } catch (error) {
      console.error('Error getting escalated notices:', error);
      return [];
    }
  }

  /**
   * Get notices due soon (within X days)
   */
  static async getNoticesDueSoon(days: number = 7): Promise<Notice[]> {
    try {
      const allNotices = await noticeService.getAll();
      const activeNotices = allNotices.filter(n =>
        n.status !== 'Closed' && n.status !== 'Resolved'
      );

      const dueSoon: Notice[] = [];

      for (const notice of activeNotices) {
        const calls = await callService.getByNoticeId(notice.id);
        const daysRemaining = NoticeLogic.calculateDaysRemaining(notice, calls);

        if (daysRemaining !== null && daysRemaining >= 0 && daysRemaining <= days) {
          dueSoon.push(notice);
        }
      }

      return dueSoon.sort((a, b) => {
        const aDays = a.daysRemaining || 999;
        const bDays = b.daysRemaining || 999;
        return aDays - bDays;
      });
    } catch (error) {
      console.error('Error getting notices due soon:', error);
      return [];
    }
  }
}