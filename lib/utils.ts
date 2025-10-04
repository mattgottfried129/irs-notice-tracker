// lib/utils.ts
// Utility functions for IRS Notice Tracker

/**
 * Date Formatting Utilities
 */
export class DateUtils {
  /**
   * Format date as MM/DD/YYYY
   */
  static formatDate(date: Date | string | number | null | undefined): string {
    if (!date) return 'N/A';

    let d: Date;

    // Handle number timestamp (milliseconds)
    if (typeof date === 'number') {
      d = new Date(date);
    }
    // Handle Firestore Timestamp
    else if (typeof date === 'object' && 'toDate' in date && typeof date.toDate === 'function') {
      d = date.toDate();
    }
    // Handle string
    else if (typeof date === 'string') {
      d = new Date(date);
    }
    // Handle Date object
    else if (date instanceof Date) {
      d = date;
    }
    else {
      return 'N/A';
    }

    if (isNaN(d.getTime())) return 'N/A';

    const month = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    const year = d.getFullYear();
    return `${month}/${day}/${year}`;
  }
  /**
   * Format date as YYYY-MM-DD (for inputs)
   */
  static formatDateISO(date: Date | string | null | undefined): string {
    if (!date) return '';
    const d = typeof date === 'string' ? new Date(date) : date;
    if (isNaN(d.getTime())) return '';
    
    return d.toISOString().split('T')[0];
  }

  /**
   * Calculate days between two dates
   */
  static daysBetween(date1: Date, date2: Date): number {
    const msPerDay = 1000 * 60 * 60 * 24;
    const utc1 = Date.UTC(date1.getFullYear(), date1.getMonth(), date1.getDate());
    const utc2 = Date.UTC(date2.getFullYear(), date2.getMonth(), date2.getDate());
    return Math.floor((utc2 - utc1) / msPerDay);
  }

  /**
   * Calculate days remaining until a date
   */
  /**
   * Calculate days remaining until a date
   */
  static daysRemaining(dueDate: Date | string | null | undefined): number | null {
    if (!dueDate) return null;

    let due: Date;

    // Handle Firestore Timestamp
    if (typeof dueDate === 'object' && 'toDate' in dueDate && typeof dueDate.toDate === 'function') {
      due = dueDate.toDate();
    } else if (typeof dueDate === 'string') {
      due = new Date(dueDate);
    } else if (dueDate instanceof Date) {
      due = dueDate;
    } else {
      return null;
    }

    if (isNaN(due.getTime())) return null;

    return this.daysBetween(new Date(), due);
  }

  /**
   * Add days to a date
   */
  static addDays(date: Date, days: number): Date {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
  }

  /**
   * Check if date is in the past
   */
  static isPast(date: Date | string | null | undefined): boolean {
    if (!date) return false;
    const d = typeof date === 'string' ? new Date(date) : date;
    return d < new Date();
  }

  /**
   * Format relative time (e.g., "3 days ago", "in 5 days")
   */
  static relativeTime(date: Date | string | null | undefined): string {
    if (!date) return 'N/A';
    const d = typeof date === 'string' ? new Date(date) : date;
    if (isNaN(d.getTime())) return 'N/A';

    const days = this.daysRemaining(d);
    if (days === null) return 'N/A';

    if (days === 0) return 'Today';
    if (days === 1) return 'Tomorrow';
    if (days === -1) return 'Yesterday';
    if (days > 0) return `In ${days} days`;
    return `${Math.abs(days)} days ago`;
  }
}

/**
 * Notice Status Utilities
 */
export class NoticeStatusUtils {
  static readonly STATUSES = {
    OPEN: 'Open',
    IN_PROGRESS: 'In Progress',
    WAITING_CLIENT: 'Waiting on Client',
    WAITING_IRS: 'Awaiting IRS Response',
    ESCALATED: 'Escalated',
    CLOSED: 'Closed'
  } as const;

  /**
   * Get color for notice status
   */
  static getStatusColor(status: string): string {
    switch (status.toLowerCase()) {
      case 'open':
        return '#2196F3'; // Blue
      case 'in progress':
        return '#FF9800'; // Orange
      case 'waiting on client':
      case 'awaiting irs response':
        return '#9C27B0'; // Purple
      case 'escalated':
        return '#F44336'; // Red
      case 'closed':
        return '#4CAF50'; // Green
      default:
        return '#757575'; // Grey
    }
  }

  /**
   * Get icon for notice status
   */
  static getStatusIcon(status: string): string {
    switch (status.toLowerCase()) {
      case 'open':
        return '📧';
      case 'in progress':
        return '⏳';
      case 'waiting on client':
        return '👤';
      case 'awaiting irs response':
        return '🏛️';
      case 'escalated':
        return '⚠️';
      case 'closed':
        return '✅';
      default:
        return '📄';
    }
  }

  /**
   * Check if notice is escalated based on days remaining
   */
  static isEscalated(daysRemaining: number | null, issue?: string): boolean {
    if (daysRemaining !== null && daysRemaining <= 3) {
      return true;
    }
    
    if (issue) {
      const escalatedKeywords = ['final', 'levy', 'lien'];
      const issueLower = issue.toLowerCase();
      return escalatedKeywords.some(keyword => issueLower.includes(keyword));
    }
    
    return false;
  }

  /**
   * Get priority level based on days remaining
   */
  static getPriority(daysRemaining: number | null): 'High' | 'Medium' | 'Low' {
    if (daysRemaining === null) return 'Low';
    if (daysRemaining <= 7) return 'High';
    if (daysRemaining <= 30) return 'Medium';
    return 'Low';
  }
}

/**
 * Billing and Amount Utilities
 */
export class BillingUtils {
  static readonly HOURLY_RATE = 250;
  static readonly MINIMUM_FEE = 250;

  /**
   * Format currency amount
   */
  static formatCurrency(amount: number | null | undefined): string {
    if (amount === null || amount === undefined) return '$0.00';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(amount);
  }

  /**
   * Round amount to nearest $5
   */
  static roundToNext5(amount: number): number {
    return Math.ceil(amount / 5) * 5;
  }

  /**
   * Calculate billable amount for a call
   */
  static calculateCallAmount(
    durationMinutes: number,
    hourlyRate: number = this.HOURLY_RATE,
    isResearch: boolean = false
  ): number {
    const timeBasedAmount = (durationMinutes / 60) * hourlyRate;

    // Research calls: bill actual time, rounded to nearest $5
    if (isResearch) {
      return this.roundToNext5(timeBasedAmount);
    }

    // Non-research calls: 1-hour minimum
    if (durationMinutes >= 60) {
      return this.roundToNext5(timeBasedAmount);
    }

    return this.MINIMUM_FEE;
  }

  /**
   * Calculate total for multiple calls (per-notice minimum logic)
   */
  static calculateNoticeTotal(calls: Array<{
    durationMinutes: number;
    responseMethod: string;
    billable: boolean;
  }>): number {
    let total = 0;

    // Separate research and non-research calls
    const researchCalls = calls.filter(c => 
      c.billable && c.responseMethod.toLowerCase().includes('research')
    );
    const nonResearchCalls = calls.filter(c => 
      c.billable && !c.responseMethod.toLowerCase().includes('research')
    );

    // Research calls: bill actual time
    for (const call of researchCalls) {
      total += this.calculateCallAmount(
        call.durationMinutes,
        this.HOURLY_RATE,
        true
      );
    }

    // Non-research calls: apply per-notice minimum
    const totalMinutes = nonResearchCalls.reduce(
      (sum, call) => sum + call.durationMinutes,
      0
    );

    if (totalMinutes > 0) {
      const totalHours = totalMinutes / 60;
      const totalAmount = totalHours * this.HOURLY_RATE;

      if (totalHours >= 1) {
        total += this.roundToNext5(totalAmount);
      } else {
        total += this.MINIMUM_FEE;
      }
    }

    return total;
  }

  /**
   * Get billing status color
   */
  static getBillingStatusColor(status: string): string {
    return status === 'Billed' ? '#4CAF50' : '#F44336';
  }
}

/**
 * POA (Power of Attorney) Utilities
 */
export class POAUtils {
  /**
   * Check if a period is covered by POA date range
   */
  static coversPeriod(
    periodStart: string,
    periodEnd: string,
    targetPeriod: string
  ): boolean {
    const start = parseInt(periodStart);
    const end = parseInt(periodEnd);
    const target = parseInt(targetPeriod);

    if (isNaN(start) || isNaN(end) || isNaN(target)) {
      return false;
    }

    return target >= start && target <= end;
  }

  /**
   * Find valid POA for a notice
   */
  static findValidPOA(
    clientId: string,
    form: string | null,
    period: string | null,
    poaRecords: Array<{
      clientId: string;
      form: string;
      periodStart: string;
      periodEnd: string;
    }>
  ): boolean {
    if (!form || !period) return false;

    return poaRecords.some(poa => 
      poa.clientId === clientId &&
      poa.form === form &&
      this.coversPeriod(poa.periodStart, poa.periodEnd, period)
    );
  }
}

/**
 * String Utilities
 */
export class StringUtils {
  /**
   * Truncate string with ellipsis
   */
  static truncate(str: string | null | undefined, maxLength: number): string {
    if (!str) return '';
    if (str.length <= maxLength) return str;
    return str.substring(0, maxLength - 3) + '...';
  }

  /**
   * Capitalize first letter
   */
  static capitalize(str: string | null | undefined): string {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
  }

  /**
   * Format client ID (e.g., "ABCD1234")
   */
  static formatClientId(id: string | null | undefined): string {
    if (!id) return '';
    return id.toUpperCase().trim();
  }

  /**
   * Generate auto ID for notice
   */
  static generateNoticeAutoId(clientId: string, noticeCount: number): string {
    const paddedCount = noticeCount.toString().padStart(4, '0');
    return `${clientId}-N${paddedCount}`;
  }
}

/**
 * Validation Utilities
 */
export class ValidationUtils {
  /**
   * Validate email format
   */
  static isValidEmail(email: string | null | undefined): boolean {
    if (!email) return false;
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  /**
   * Validate phone format (US)
   */
  static isValidPhone(phone: string | null | undefined): boolean {
    if (!phone) return false;
    const phoneRegex = /^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$/;
    return phoneRegex.test(phone);
  }

  /**
   * Format phone number
   */
  static formatPhone(phone: string | null | undefined): string {
    if (!phone) return '';
    const cleaned = phone.replace(/\D/g, '');
    if (cleaned.length !== 10) return phone;
    return `(${cleaned.slice(0, 3)}) ${cleaned.slice(3, 6)}-${cleaned.slice(6)}`;
  }

  /**
   * Validate required field
   */
  static isRequired(value: any): boolean {
    if (value === null || value === undefined) return false;
    if (typeof value === 'string') return value.trim().length > 0;
    return true;
  }
}

/**
 * Array/Collection Utilities
 */
export class CollectionUtils {
  /**
   * Group items by key
   */
  static groupBy<T>(
    items: T[],
    keyFn: (item: T) => string
  ): Record<string, T[]> {
    return items.reduce((groups, item) => {
      const key = keyFn(item);
      if (!groups[key]) {
        groups[key] = [];
      }
      groups[key].push(item);
      return groups;
    }, {} as Record<string, T[]>);
  }

  /**
   * Sort by date (descending)
   */
  static sortByDateDesc<T>(
    items: T[],
    dateFn: (item: T) => Date | string | null
  ): T[] {
    return [...items].sort((a, b) => {
      const dateA = dateFn(a);
      const dateB = dateFn(b);
      
      if (!dateA || !dateB) return 0;
      
      const dA = typeof dateA === 'string' ? new Date(dateA) : dateA;
      const dB = typeof dateB === 'string' ? new Date(dateB) : dateB;
      
      return dB.getTime() - dA.getTime();
    });
  }

  /**
   * Calculate sum of numeric values
   */
  static sum<T>(
    items: T[],
    valueFn: (item: T) => number
  ): number {
    return items.reduce((sum, item) => sum + valueFn(item), 0);
  }

  /**
   * Filter unique values
   */
  static unique<T>(items: T[]): T[] {
    return [...new Set(items)];
  }
}

/**
 * Export/Print Utilities
 */
export class ExportUtils {
  /**
   * Convert data to CSV string
   */
  static toCSV(
    headers: string[],
    rows: any[][]
  ): string {
    const escape = (val: any) => {
      if (val === null || val === undefined) return '';
      const str = String(val);
      if (str.includes(',') || str.includes('"') || str.includes('\n')) {
        return `"${str.replace(/"/g, '""')}"`;
      }
      return str;
    };

    const csvHeaders = headers.map(escape).join(',');
    const csvRows = rows.map(row => row.map(escape).join(',')).join('\n');
    
    return `${csvHeaders}\n${csvRows}`;
  }

  /**
   * Download string as file
   */
  static downloadFile(content: string, filename: string, mimeType: string = 'text/plain'): void {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  /**
   * Print element
   */
  static printElement(elementId: string): void {
    const element = document.getElementById(elementId);
    if (!element) {
      console.error(`Element with id "${elementId}" not found`);
      return;
    }

    const printWindow = window.open('', '_blank');
    if (!printWindow) {
      console.error('Failed to open print window');
      return;
    }

    printWindow.document.write(`
      <html>
        <head>
          <title>Print</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            @media print {
              body { margin: 0; }
            }
          </style>
        </head>
        <body>
          ${element.innerHTML}
        </body>
      </html>
    `);
    
    printWindow.document.close();
    printWindow.focus();
    setTimeout(() => {
      printWindow.print();
      printWindow.close();
    }, 250);
  }
}

/**
 * Constants
 */
export const Constants = {
  STATUSES: [
    'Open',
    'In Progress',
    'Waiting on Client',
    'Awaiting IRS Response',
    'Escalated',
    'Closed'
  ] as const,

  RESPONSE_METHODS: [
    'Phone Call',
    'Fax',
    'Mail',
    'e-services',
    'Research'
  ] as const,

  IRS_LINES: [
    'PPS',
    'Collections',
    'Examinations',
    'Taxpayer Advocate',
    'Other'
  ] as const,

  OUTCOMES: [
    'Resolved',
    'Waiting on Client',
    'Waiting on IRS',
    'Monitor Account',
    'Submit Documentation',
    'Follow-Up Call',
    'Other (Details in Notes)'
  ] as const
};

// Type exports for constants
export type NoticeStatus = typeof Constants.STATUSES[number];
export type ResponseMethod = typeof Constants.RESPONSE_METHODS[number];
export type IRSLine = typeof Constants.IRS_LINES[number];
export type CallOutcome = typeof Constants.OUTCOMES[number];