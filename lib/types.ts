// lib/types.ts
// Updated types with auto-escalation fields

export interface Client {
  id: string;
  clientId: string;
  name: string;
  email?: string;
  phone?: string;
  address?: string;
  city?: string;
  state?: string;
  zip?: string;
  notes?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

export interface Notice {
  id: string;
  clientId: string;
  autoId?: string;
  noticeNumber: string;
  noticeIssue?: string;
  formNumber?: string;
  taxPeriod?: string;
  dateReceived?: Date;
  daysToRespond?: number;
  dueDate?: Date;
  status: 'Open' | 'In Progress' | 'Waiting on Client' | 'Awaiting IRS Response' | 'Escalated' | 'Closed';

  // Auto-escalation fields
  escalated?: boolean;
  daysRemaining?: number | null;
  responseDeadline?: Date | null;
  lastAutoUpdate?: Date;

  // POA fields
  poaOnFile?: boolean;
  needsPoa?: boolean;

  // Additional fields
  notes?: string;
  description?: string;
  dateCompleted?: Date;
  representativeId?: string;
  filingStatus?: string;
  paymentPlan?: string;
  amountOwed?: number;
  amountPaid?: number;
  nextFollowUpDate?: Date;
  priority?: string;
  attachmentPaths?: string[];
  customFields?: Record<string, any>;

  createdAt?: Date;
  updatedAt?: Date;
}

export interface Call {
  id: string;
  noticeId: string;
  clientId?: string;
  date: Date;
  responseMethod?: string;
  irsLine?: string;
  agentId?: string;
  description?: string;
  issues?: string;
  notes?: string;
  outcome?: string;
  followUpDate?: Date;
  durationMinutes?: number;
  hourlyRate?: number;
  totalCost?: number;
  billable?: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

export interface POARecord {
  id: string;              // This is the client ID (not Firestore doc ID)
  form: string;
  periodStart: string;
  periodEnd: string;
  electronicCopy?: boolean;
  cafVerified?: boolean;
  paperCopy?: boolean;
  dateReceived?: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

// Firestore query types
export interface QueryOptions {
  where?: Array<{
    field: string;
    operator: '==' | '!=' | '<' | '<=' | '>' | '>=' | 'in' | 'not-in' | 'array-contains';
    value: any;
  }>;
  orderBy?: Array<{
    field: string;
    direction: 'asc' | 'desc';
  }>;
  limit?: number;
}

// Escalation service types
export interface DerivedNoticeFields {
  status: string;
  daysRemaining: number | null;
  escalated: boolean;
  responseDeadline: Date | null;
}

// Dashboard types
export interface DashboardStats {
  totalClients: number;
  activeNotices: number;
  escalatedNotices: number;
  dueThisWeek: number;
  missingPOA: number;
  closedThisMonth: number;
}

// POA checking types
export interface POACheckResult {
  hasValidPOA: boolean;
  matchingPOA?: POARecord;
  reason?: string;
}