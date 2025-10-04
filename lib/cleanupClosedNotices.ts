// lib/cleanupClosedNotices.ts
// One-time cleanup script to fix closed notices that were incorrectly escalated

import { noticeService } from './api';

/**
 * Fix all closed notices that are incorrectly marked as escalated
 * This is a one-time cleanup for existing data
 */
export async function cleanupClosedNotices(): Promise<{
  total: number;
  fixed: number;
  errors: string[];
}> {
  console.log('🔧 Starting cleanup of closed notices...');

  const results = {
    total: 0,
    fixed: 0,
    errors: [] as string[]
  };

  try {
    // Get all notices
    const allNotices = await noticeService.getAll();

    // Find closed notices that are escalated
    const closedButEscalated = allNotices.filter(notice =>
      (notice.status === 'Closed' || notice.status === 'Resolved') &&
      notice.escalated === true
    );

    results.total = closedButEscalated.length;
    console.log(`📋 Found ${results.total} closed notices incorrectly marked as escalated`);

    if (results.total === 0) {
      console.log('✅ No cleanup needed - all data is correct!');
      return results;
    }

    // Fix each one
    for (const notice of closedButEscalated) {
      try {
        await noticeService.update(notice.id, {
          escalated: false,
          // Optionally clear daysRemaining for closed notices
          daysRemaining: null as any
        });

        results.fixed++;
        console.log(`✅ Fixed notice ${notice.autoId || notice.id}`);
      } catch (error) {
        const errorMsg = `Failed to fix ${notice.autoId || notice.id}: ${error}`;
        console.error(`❌ ${errorMsg}`);
        results.errors.push(errorMsg);
      }
    }

    console.log(`\n🎉 Cleanup complete!`);
    console.log(`   Total found: ${results.total}`);
    console.log(`   Fixed: ${results.fixed}`);
    console.log(`   Errors: ${results.errors.length}`);

  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    results.errors.push(`General error: ${error}`);
  }

  return results;
}

/**
 * Alternative: Fix a specific notice by ID
 */
export async function fixSingleNotice(noticeId: string): Promise<boolean> {
  try {
    const notice = await noticeService.getById(noticeId);

    if (!notice) {
      console.error('❌ Notice not found');
      return false;
    }

    if (notice.status === 'Closed' || notice.status === 'Resolved') {
      await noticeService.update(noticeId, {
        escalated: false,
        daysRemaining: null as any
      });
      console.log(`✅ Fixed notice ${notice.autoId || noticeId}`);
      return true;
    } else {
      console.log(`ℹ️  Notice ${notice.autoId || noticeId} is not closed, no fix needed`);
      return false;
    }
  } catch (error) {
    console.error('❌ Error fixing notice:', error);
    return false;
  }
}