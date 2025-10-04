// functions/src/index.ts
// Firebase Cloud Functions for IRS Notice Tracker
// Auto-escalation scheduler runs daily at midnight

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

/**
 * Notice Logic - Ported from client
 */
class NoticeLogic {
  static calculateResponseDeadline(notice: any, calls: any[]): Date | null {
    const followUps = calls
      .filter(c => c.noticeId === notice.id && c.outcome)
      .map(c => c.followUpDate?.toDate())
      .filter(date => date)
      .sort((a, b) => a.getTime() - b.getTime());

    if (followUps.length > 0) {
      return followUps[0];
    }

    if (notice.dateReceived && notice.daysToRespond) {
      const deadline = notice.dateReceived.toDate();
      deadline.setDate(deadline.getDate() + notice.daysToRespond);
      return deadline;
    }

    return null;
  }

  static calculateDaysRemaining(notice: any, calls: any[]): number | null {
    const deadline = this.calculateResponseDeadline(notice, calls);
    if (!deadline) return null;

    const now = new Date();
    now.setHours(0, 0, 0, 0);
    deadline.setHours(0, 0, 0, 0);

    const diffTime = deadline.getTime() - now.getTime();
    return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  }

  static isEscalated(notice: any, calls: any[]): boolean {
    if (!notice.clientId) return false;

    // Skip if already closed/resolved
    if (notice.status === 'Closed' || notice.status === 'Resolved') return false;

    const daysRemaining = this.calculateDaysRemaining(notice, calls);
    if (daysRemaining !== null && daysRemaining <= 3) {
      return true;
    }

    const issue = (notice.noticeIssue || '').toLowerCase();
    const criticalKeywords = ['final', 'levy', 'lien', 'intent to levy', 'final notice'];

    return criticalKeywords.some(keyword => issue.includes(keyword));
  }

  static calculateStatus(notice: any, calls: any[]): string {
    // Closed - HIGHEST PRIORITY
    if (calls.some(c => (c.outcome || '').toLowerCase() === 'resolved')) {
      return 'Closed';
    }

    // Escalated - only if not closed
    if (this.isEscalated(notice, calls)) {
      return 'Escalated';
    }

    if (calls.some(c => (c.outcome || '').toLowerCase() === 'waiting on client')) {
      return 'Waiting on Client';
    }

    if (calls.some(c =>
      (c.outcome || '').toLowerCase() === 'awaiting irs response' ||
      (c.outcome || '').toLowerCase() === 'waiting on irs'
    )) {
      return 'Awaiting IRS Response';
    }

    if (calls.length > 0) {
      return 'In Progress';
    }

    return 'Open';
  }
}

/**
 * Scheduled function - Runs daily at midnight (EST)
 * Updates all active notice statuses and escalation flags
 */
export const dailyEscalationUpdate = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('🔄 Starting daily escalation update...');

    try {
      // Get all active notices (not closed)
      const noticesSnapshot = await db.collection('notices')
        .where('status', '!=', 'Closed')
        .get();

      console.log(`📋 Found ${noticesSnapshot.size} active notices`);

      let updateCount = 0;
      const batch = db.batch();
      let batchCount = 0;

      for (const noticeDoc of noticesSnapshot.docs) {
        const notice = { id: noticeDoc.id, ...noticeDoc.data() };

        // Get calls for this notice
        const callsSnapshot = await db.collection('calls')
          .where('noticeId', '==', notice.id)
          .get();

        const calls = callsSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        // Calculate derived fields
        const responseDeadline = NoticeLogic.calculateResponseDeadline(notice, calls);
        const daysRemaining = NoticeLogic.calculateDaysRemaining(notice, calls);
        const escalated = NoticeLogic.isEscalated(notice, calls);
        const status = NoticeLogic.calculateStatus(notice, calls);

        // Check if anything changed
        const hasChanges =
          notice.status !== status ||
          notice.escalated !== escalated ||
          notice.daysRemaining !== daysRemaining;

        if (hasChanges) {
          batch.update(noticeDoc.ref, {
            status,
            escalated,
            daysRemaining,
            responseDeadline: responseDeadline || null,
            lastAutoUpdate: admin.firestore.FieldValue.serverTimestamp()
          });

          updateCount++;
          batchCount++;

          // Firestore batch limit is 500, commit if reached
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      // Commit remaining updates
      if (batchCount > 0) {
        await batch.commit();
      }

      console.log(`✅ Daily escalation update complete: ${updateCount} notices updated`);

      return { success: true, updatedCount: updateCount };
    } catch (error) {
      console.error('❌ Error in daily escalation update:', error);
      throw error;
    }
  });

/**
 * HTTP function - Manual trigger for escalation update
 * Can be called from admin panel or for testing
 */
export const triggerEscalationUpdate = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  console.log('🔄 Manual escalation update triggered by:', context.auth.uid);

  try {
    // Get all active notices
    const noticesSnapshot = await db.collection('notices')
      .where('status', '!=', 'Closed')
      .get();

    let updateCount = 0;
    const batch = db.batch();

    for (const noticeDoc of noticesSnapshot.docs) {
      const notice = { id: noticeDoc.id, ...noticeDoc.data() };

      const callsSnapshot = await db.collection('calls')
        .where('noticeId', '==', notice.id)
        .get();

      const calls = callsSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

      const responseDeadline = NoticeLogic.calculateResponseDeadline(notice, calls);
      const daysRemaining = NoticeLogic.calculateDaysRemaining(notice, calls);
      const escalated = NoticeLogic.isEscalated(notice, calls);
      const status = NoticeLogic.calculateStatus(notice, calls);

      const hasChanges =
        notice.status !== status ||
        notice.escalated !== escalated ||
        notice.daysRemaining !== daysRemaining;

      if (hasChanges) {
        batch.update(noticeDoc.ref, {
          status,
          escalated,
          daysRemaining,
          responseDeadline: responseDeadline || null,
          lastAutoUpdate: admin.firestore.FieldValue.serverTimestamp()
        });
        updateCount++;
      }
    }

    await batch.commit();

    console.log(`✅ Manual update complete: ${updateCount} notices updated`);

    return { success: true, updatedCount: updateCount };
  } catch (error) {
    console.error('❌ Error in manual escalation update:', error);
    throw new functions.https.HttpsError('internal', 'Update failed');
  }
});