// lib/noticeLogic.ts
// Auto-escalation and status calculation logic
// Ported from Flutter notice_logic.dart

import { Notice, Call } from './types';

export class NoticeLogic {
  /**
   * Calculate Response Deadline
   * Uses earliest follow-up date from calls, or notice date + days to respond
   */
  static calculateResponseDeadline(notice: Notice, calls: Call[]): Date | null {
    // Get earliest follow-up date from calls with outcomes
    const followUps = calls
      .filter(c => c.noticeId === notice.id && c.outcome)
      .map(c => c.followUpDate)
      .filter((date): date is Date => date !== null && date !== undefined)
      .sort((a, b) => a.getTime() - b.getTime());

    if (followUps.length > 0) {
      return followUps[0];
    }

    // Fallback: notice date + days to respond
    if (notice.dateReceived && notice.daysToRespond) {
      const deadline = new Date(notice.dateReceived);
      deadline.setDate(deadline.getDate() + notice.daysToRespond);
      return deadline;
    }

    return null;
  }

  /**
   * Calculate Days Remaining Until Deadline
   */
  static calculateDaysRemaining(notice: Notice, calls: Call[]): number | null {
    const deadline = this.calculateResponseDeadline(notice, calls);
    if (!deadline) return null;

    const now = new Date();
    now.setHours(0, 0, 0, 0); // Reset time portion
    deadline.setHours(0, 0, 0, 0);

    const diffTime = deadline.getTime() - now.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    return diffDays;
  }

  /**
   * Escalation Logic
   * Returns true if notice should be escalated based on:
   * 1. Days remaining <= 3
   * 2. Issue contains "final", "levy", or "lien"
   */
  static isEscalated(notice: Notice, calls: Call[]): boolean {
    // Skip if no client assigned
    if (!notice.clientId) return false;

    // Check days remaining
    const daysRemaining = this.calculateDaysRemaining(notice, calls);
    if (daysRemaining !== null && daysRemaining <= 3) {
      return true;
    }

    // Check notice issue for critical keywords
    const issue = (notice.noticeIssue || '').toLowerCase();
    const criticalKeywords = ['final', 'levy', 'lien', 'intent to levy', 'final notice'];

    if (criticalKeywords.some(keyword => issue.includes(keyword))) {
      return true;
    }

    return false;
  }

  /**
   * Status Calculation
   * Determines notice status based on calls and escalation
   */
  static calculateStatus(notice: Notice, calls: Call[]): string {
    // Closed - if any call has "Resolved" outcome
    if (calls.some(c => (c.outcome || '').toLowerCase() === 'resolved')) {
      return 'Closed';
    }

    // Escalated - if escalation conditions met
    if (this.isEscalated(notice, calls)) {
      return 'Escalated';
    }

    // Waiting on Client
    if (calls.some(c => (c.outcome || '').toLowerCase() === 'waiting on client')) {
      return 'Waiting on Client';
    }

    // In Progress - if has calls or awaiting IRS response
    if (calls.some(c =>
      (c.outcome || '').toLowerCase() === 'awaiting irs response' ||
      (c.outcome || '').toLowerCase() === 'waiting on irs'
    )) {
      return 'Awaiting IRS Response';
    }

    if (calls.length > 0) {
      return 'In Progress';
    }

    // Default
    return 'Open';
  }

  /**
   * Calculate all derived fields for a notice
   * Returns object with status, daysRemaining, escalated, responseDeadline
   */
  static calculateDerivedFields(notice: Notice, calls: Call[]) {
    const responseDeadline = this.calculateResponseDeadline(notice, calls);
    const daysRemaining = this.calculateDaysRemaining(notice, calls);
    const escalated = this.isEscalated(notice, calls);
    const status = this.calculateStatus(notice, calls);

    return {
      status,
      daysRemaining,
      escalated,
      responseDeadline
    };
  }
}