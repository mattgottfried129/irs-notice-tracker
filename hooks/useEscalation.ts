// hooks/useEscalation.ts
// React hook for automatic escalation updates

import { useEffect, useState } from 'react';
import { EscalationService } from '../lib/escalationService';

/**
 * Hook to automatically update notice statuses on mount
 * Can be used in dashboard or any screen that needs fresh data
 */
export function useAutoEscalation(autoUpdate: boolean = true) {
  const [isUpdating, setIsUpdating] = useState(false);
  const [updateCount, setUpdateCount] = useState(0);
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!autoUpdate) return;

    const runUpdate = async () => {
      setIsUpdating(true);
      setError(null);

      try {
        const count = await EscalationService.updateAllNotices();
        setUpdateCount(count);
        setLastUpdate(new Date());
      } catch (err: any) {
        console.error('Auto-escalation error:', err);
        setError(err.message || 'Failed to update notices');
      } finally {
        setIsUpdating(false);
      }
    };

    runUpdate();
  }, [autoUpdate]);

  return {
    isUpdating,
    updateCount,
    lastUpdate,
    error
  };
}

/**
 * Hook to manually trigger escalation updates
 */
export function useEscalationTrigger() {
  const [isUpdating, setIsUpdating] = useState(false);

  const updateAll = async () => {
    setIsUpdating(true);
    try {
      const count = await EscalationService.updateAllNotices();
      return count;
    } finally {
      setIsUpdating(false);
    }
  };

  const updateNotice = async (noticeId: string) => {
    setIsUpdating(true);
    try {
      return await EscalationService.updateNoticeStatus(noticeId);
    } finally {
      setIsUpdating(false);
    }
  };

  const updateClient = async (clientId: string) => {
    setIsUpdating(true);
    try {
      return await EscalationService.updateClientNotices(clientId);
    } finally {
      setIsUpdating(false);
    }
  };

  return {
    isUpdating,
    updateAll,
    updateNotice,
    updateClient
  };
}