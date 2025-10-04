// lib/debugEscalated.ts
// Debug helper to see what's actually in Firestore

import { noticeService } from './api';

export async function debugEscalatedNotices() {
  console.log('\n🔍 DEBUG: Checking escalated notices in database...\n');

  try {
    const allNotices = await noticeService.getAll();

    // Find all that claim to be escalated
    const escalatedNotices = allNotices.filter(n => n.escalated === true);

    console.log(`📋 Total notices: ${allNotices.length}`);
    console.log(`⚠️  Notices marked as escalated: ${escalatedNotices.length}\n`);

    if (escalatedNotices.length === 0) {
      console.log('✅ No escalated notices found - all clean!');
      return;
    }

    console.log('📝 Details of escalated notices:\n');

    escalatedNotices.forEach((notice, index) => {
      console.log(`${index + 1}. ${notice.autoId || notice.id}`);
      console.log(`   Status: ${notice.status}`);
      console.log(`   Escalated: ${notice.escalated}`);
      console.log(`   Days Remaining: ${notice.daysRemaining}`);
      console.log(`   Client ID: ${notice.clientId}`);
      console.log(`   Issue: ${notice.noticeIssue || 'N/A'}`);

      // Check if this SHOULD be escalated
      const isClosed = notice.status === 'Closed' || notice.status === 'Resolved';
      if (isClosed) {
        console.log(`   ❌ ERROR: This is CLOSED but marked as escalated!`);
      } else if (notice.daysRemaining !== null && notice.daysRemaining <= 3) {
        console.log(`   ✅ Correctly escalated (${notice.daysRemaining} days remaining)`);
      } else {
        console.log(`   ⚠️  Escalated for other reason (check issue keywords)`);
      }
      console.log('');
    });

    // Check for closed notices that are escalated
    const closedButEscalated = escalatedNotices.filter(n =>
      n.status === 'Closed' || n.status === 'Resolved'
    );

    if (closedButEscalated.length > 0) {
      console.log(`\n❌ PROBLEM FOUND: ${closedButEscalated.length} closed notices are still marked as escalated:`);
      closedButEscalated.forEach(n => {
        console.log(`   - ${n.autoId || n.id} (Status: ${n.status})`);
      });
      console.log('\n💡 Run cleanup again or manually update these in Firestore\n');
    } else {
      console.log('\n✅ All escalated notices are active (not closed)\n');
    }

    return {
      total: allNotices.length,
      escalated: escalatedNotices.length,
      closedButEscalated: closedButEscalated.length,
      issues: closedButEscalated
    };

  } catch (error) {
    console.error('❌ Error debugging escalated notices:', error);
    throw error;
  }
}