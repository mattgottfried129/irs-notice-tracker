// lib/poaChecker.ts
// POA validation logic

import { POARecord, Notice, POACheckResult } from './types';
import { poaService } from './api';

export class POAChecker {
  /**
   * Convert quarter format (Q1/2010) to YYYYMM format (201001)
   */
  static quarterToYYYYMM(quarter: string): { start: string; end: string } | null {
    const match = quarter.match(/Q(\d)\/(\d{4})/i);
    if (!match) return null;

    const q = parseInt(match[1]);
    const year = match[2];

    const quarterMap: { [key: number]: { start: string; end: string } } = {
      1: { start: `${year}01`, end: `${year}03` },
      2: { start: `${year}04`, end: `${year}06` },
      3: { start: `${year}07`, end: `${year}09` },
      4: { start: `${year}10`, end: `${year}12` }
    };

    return quarterMap[q] || null;
  }

  /**
   * Normalize period to YYYYMM format
   * Handles: "2023" -> "202301", "Q1/2023" -> "202301", "202301" -> "202301"
   */
  static normalizePeriod(period: string): string {
    // Already in YYYYMM format
    if (/^\d{6}$/.test(period)) {
      return period;
    }

    // Year only (2023) -> first month of year
    if (/^\d{4}$/.test(period)) {
      return `${period}01`;
    }

    // Quarter format (Q1/2023) -> first month of quarter
    const quarterResult = this.quarterToYYYYMM(period);
    if (quarterResult) {
      return quarterResult.start;
    }

    // Can't normalize
    return period;
  }

  /**
   * Check if a period is covered by POA date range
   */
  static coversPeriod(
    periodStart: string,
    periodEnd: string,
    targetPeriod: string
  ): boolean {
    // Normalize all periods
    let start = this.normalizePeriod(periodStart);
    let end = this.normalizePeriod(periodEnd);
    const target = this.normalizePeriod(targetPeriod);

    // If period is a quarter range, get the full range
    const startQuarter = this.quarterToYYYYMM(periodStart);
    const endQuarter = this.quarterToYYYYMM(periodEnd);

    if (startQuarter) start = startQuarter.start;
    if (endQuarter) end = endQuarter.end;

    console.log('Normalized periods:', {
      original: { periodStart, periodEnd, targetPeriod },
      normalized: { start, end, target }
    });

    // Parse as integers
    const startNum = parseInt(start.replace(/\D/g, ''));
    const endNum = parseInt(end.replace(/\D/g, ''));
    const targetNum = parseInt(target.replace(/\D/g, ''));

    if (isNaN(startNum) || isNaN(endNum) || isNaN(targetNum)) {
      console.log('Invalid period format after normalization');
      return false;
    }

    const result = targetNum >= startNum && targetNum <= endNum;
    console.log('Period check:', { startNum, endNum, targetNum, result });
    return result;
  }

  /**
   * Find valid POA for a notice
   */
  static async findValidPOA(notice: Notice): Promise<POACheckResult> {
    console.log('Checking POA for notice:', notice.id, {
      formNumber: notice.formNumber,
      taxPeriod: notice.taxPeriod,
      clientId: notice.clientId
    });

    // Can't check without required fields
    if (!notice.formNumber || !notice.taxPeriod) {
      console.log('Missing form or period');
      return {
        hasValidPOA: false,
        reason: 'Notice missing form number or tax period'
      };
    }

    try {
      // Get all POA records for this client
      const clientPOAs = await poaService.getByClientId(notice.clientId);
      console.log(`Found ${clientPOAs.length} POA records for client ${notice.clientId}`);

      if (clientPOAs.length > 0) {
        console.log('POA clientIds:', clientPOAs.map(p => p.clientId));
      }

      if (clientPOAs.length === 0) {
        // Try searching all POAs to see if there's a mismatch
        const allPOAs = await poaService.getAll();
        const matchingPOAs = allPOAs.filter(p =>
          p.clientId === notice.clientId ||
          p.clientId.includes(notice.clientId) ||
          notice.clientId.includes(p.clientId)
        );
        console.log('Search all POAs - found:', matchingPOAs.length);
        if (matchingPOAs.length > 0) {
          console.log('Matching POA clientIds:', matchingPOAs.map(p => ({ id: p.clientId, form: p.form })));
        }

        return {
          hasValidPOA: false,
          reason: 'No POA records found for client'
        };
      }

      // Find matching POA
      for (const poa of clientPOAs) {
        console.log('Checking POA:', {
          poaForm: poa.form,
          noticeForm: notice.formNumber,
          poaPeriodStart: poa.periodStart,
          poaPeriodEnd: poa.periodEnd,
          noticePeriod: notice.taxPeriod
        });

        // Check if form matches (normalize comparison)
        const poaForm = poa.form.trim().toLowerCase();
        const noticeForm = notice.formNumber.trim().toLowerCase();

        if (poaForm !== noticeForm) {
          console.log('Form mismatch:', poaForm, '!==', noticeForm);
          continue;
        }

        console.log('Form matched! Checking period...');

        // Check if period is covered
        if (this.coversPeriod(poa.periodStart, poa.periodEnd, notice.taxPeriod)) {
          console.log('✅ Valid POA found!');
          return {
            hasValidPOA: true,
            matchingPOA: poa
          };
        } else {
          console.log('Period not covered');
        }
      }

      console.log('❌ No matching POA found');
      return {
        hasValidPOA: false,
        reason: `No POA found for form ${notice.formNumber} covering period ${notice.taxPeriod}`
      };

    } catch (error) {
      console.error('Error checking POA:', error);
      return {
        hasValidPOA: false,
        reason: 'Error checking POA records'
      };
    }
  }

  /**
   * Check multiple notices for POA coverage
   */
  static async checkNotices(notices: Notice[]): Promise<Map<string, POACheckResult>> {
    const results = new Map<string, POACheckResult>();

    for (const notice of notices) {
      const result = await this.findValidPOA(notice);
      results.set(notice.id, result);
    }

    return results;
  }

  /**
   * Format period for display (YYYYMM -> MMM YYYY)
   */
  static formatPeriod(period: string): string {
    if (period.length !== 6) return period;

    const year = period.substring(0, 4);
    const month = period.substring(4, 6);

    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    const monthIndex = parseInt(month) - 1;
    if (monthIndex < 0 || monthIndex > 11) return period;

    return `${monthNames[monthIndex]} ${year}`;
  }

  /**
   * Format period range for display
   */
  static formatPeriodRange(start: string, end: string): string {
    return `${this.formatPeriod(start)} - ${this.formatPeriod(end)}`;
  }

  /**
   * Validate period format (YYYYMM)
   */
  static isValidPeriodFormat(period: string): boolean {
    if (!/^\d{6}$/.test(period)) return false;

    const year = parseInt(period.substring(0, 4));
    const month = parseInt(period.substring(4, 6));

    return year >= 1900 && year <= 2100 && month >= 1 && month <= 12;
  }
}