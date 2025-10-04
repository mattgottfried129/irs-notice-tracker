import { 
  collection, 
  doc, 
  getDoc, 
  getDocs, 
  addDoc, 
  updateDoc, 
  deleteDoc, 
  query, 
  where, 
  orderBy, 
  limit,
  Query,
  QueryConstraint,
  DocumentData,
  WhereFilterOp,
  OrderByDirection,
  Timestamp
} from 'firebase/firestore';
import { db } from './firebase';
import type { 
  IRSNotice, 
  Client, 
  POARecord,
  Call,
  QueryOptions,
  WhereClause
} from './types';

/**
 * Base Firestore service class
 */
export class FirestoreService<T extends { id?: string }> {
  protected collectionName: string;

  constructor(collectionName: string) {
    this.collectionName = collectionName;
  }

  /**
   * Get collection reference
   */
  protected getCollection() {
    return collection(db, this.collectionName);
  }

  /**
   * Get all documents - FIXED to preserve all document fields including 'id'
   */
  async getAll(): Promise<T[]> {
    try {
      const querySnapshot = await getDocs(this.getCollection());
      const results = querySnapshot.docs.map(docSnapshot => {
        const data = docSnapshot.data();
        const firestoreDocId = docSnapshot.id;

        // Return data exactly as it exists in Firestore, with Firestore doc ID stored separately
        return {
          _firestoreDocId: firestoreDocId,
          ...data,
        } as T;
      });

      console.log(`📚 Loaded ${results.length} documents from ${this.collectionName}`);
      if (results.length > 0 && this.collectionName === 'poaRecords') {
        console.log(`📄 Sample POA document:`, JSON.stringify(results[0], null, 2));
      }

      return results;
    } catch (error) {
      console.error(`Error getting all ${this.collectionName}:`, error);
      throw error;
    }
  }

  /**
   * Get document by Firestore document ID
   */
  async getById(firestoreDocId: string): Promise<T | null> {
    try {
      const docRef = doc(this.getCollection(), firestoreDocId);
      const docSnap = await getDoc(docRef);

      if (docSnap.exists()) {
        const data = docSnap.data();
        return {
          _firestoreDocId: docSnap.id,
          ...data,
        } as T;
      }

      return null;
    } catch (error) {
      console.error(`Error getting ${this.collectionName} by ID:`, error);
      throw error;
    }
  }

  /**
   * Query documents with flexible options
   */
  async query(options: QueryOptions = {}): Promise<T[]> {
    try {
      const constraints: QueryConstraint[] = [];

      // Add where clauses
      if (options.where) {
        options.where.forEach(clause => {
          constraints.push(
            where(clause.field, clause.operator, clause.value)
          );
        });
      }

      // Add orderBy clauses
      if (options.orderBy) {
        options.orderBy.forEach(order => {
          constraints.push(orderBy(order.field, order.direction));
        });
      }

      // Add limit
      if (options.limit) {
        constraints.push(limit(options.limit));
      }

      const q = query(this.getCollection(), ...constraints);
      const querySnapshot = await getDocs(q);

      return querySnapshot.docs.map(docSnapshot => {
        const data = docSnapshot.data();
        return {
          _firestoreDocId: docSnapshot.id,
          ...data,
        } as T;
      });
    } catch (error) {
      console.error(`Error querying ${this.collectionName}:`, error);
      throw error;
    }
  }

  /**
   * Create new document
   */
  async create(data: Omit<T, 'id'>): Promise<string> {
    try {
      const docRef = await addDoc(this.getCollection(), {
        ...data,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
      return docRef.id;
    } catch (error) {
      console.error(`Error creating ${this.collectionName}:`, error);
      throw error;
    }
  }

  /**
   * Update document by Firestore document ID
   */
  async update(firestoreDocId: string, data: Partial<T>): Promise<void> {
    try {
      const docRef = doc(this.getCollection(), firestoreDocId);
      await updateDoc(docRef, {
        ...data,
        updatedAt: Timestamp.now(),
      });
    } catch (error) {
      console.error(`Error updating ${this.collectionName}:`, error);
      throw error;
    }
  }

  /**
   * Delete document by Firestore document ID
   */
  async delete(firestoreDocId: string): Promise<void> {
    try {
      const docRef = doc(this.getCollection(), firestoreDocId);
      await deleteDoc(docRef);
    } catch (error) {
      console.error(`Error deleting ${this.collectionName}:`, error);
      throw error;
    }
  }
}

/**
 * IRS Notice Service
 */
export class NoticeService extends FirestoreService<IRSNotice> {
  constructor() {
    super('notices');
  }

  /**
   * Get notices by client ID
   */
  async getByClientId(clientId: string): Promise<IRSNotice[]> {
    return this.query({
      where: [{ field: 'clientId', operator: '==', value: clientId }],
      orderBy: [{ field: 'dateReceived', direction: 'desc' }]
    });
  }

  /**
   * Get notice by Firestore document ID
   */
  async getByNoticeId(noticeId: string): Promise<IRSNotice | null> {
    return this.getById(noticeId);
  }

  /**
   * Get notices by status
   */
  async getByStatus(status: string): Promise<IRSNotice[]> {
    return this.query({
      where: [{ field: 'status', operator: '==', value: status }],
      orderBy: [{ field: 'dateReceived', direction: 'desc' }]
    });
  }

  /**
   * Get escalated notices
   */
  async getEscalated(): Promise<IRSNotice[]> {
    return this.query({
      where: [{ field: 'escalated', operator: '==', value: true }],
      orderBy: [{ field: 'dateReceived', direction: 'desc' }]
    });
  }

  /**
   * Update notice by Firestore document ID
   */
  async updateNotice(noticeId: string, data: Partial<IRSNotice>): Promise<void> {
    return this.update(noticeId, data);
  }

  /**
   * Delete notice by Firestore document ID
   */
  async deleteNotice(noticeId: string): Promise<void> {
    return this.delete(noticeId);
  }
}

/**
 * Client Service
 */
export class ClientService extends FirestoreService<Client> {
  constructor() {
    super('clients');
  }

  /**
   * Search clients by name
   */
  async searchByName(searchTerm: string): Promise<Client[]> {
    const allClients = await this.getAll();
    return allClients.filter(client =>
      client.name?.toLowerCase().includes(searchTerm.toLowerCase())
    );
  }

  /**
   * Get client by client ID (not Firestore doc ID)
   */
  async getByClientId(clientId: string): Promise<Client | null> {
    const allClients = await this.getAll();
    return allClients.find(client => client.id === clientId) || null;
  }
}

/**
 * Call Service - For tracking phone calls related to notices
 */
export class CallService extends FirestoreService<Call> {
  constructor() {
    super('calls');
  }

  /**
   * Get calls by notice ID
   */
  async getByNoticeId(noticeId: string): Promise<Call[]> {
    try {
      return this.query({
        where: [{ field: 'noticeId', operator: '==', value: noticeId }],
        orderBy: [{ field: 'callDate', direction: 'desc' }]
      });
    } catch (error) {
      // If query fails (e.g., no index), fall back to filtering all calls
      console.warn(`Query failed for calls with noticeId ${noticeId}, falling back to filter:`, error);
      const allCalls = await this.getAll();
      return allCalls.filter(call => call.noticeId === noticeId);
    }
  }

  /**
   * Get calls by client ID
   */
  async getByClientId(clientId: string): Promise<Call[]> {
    try {
      return this.query({
        where: [{ field: 'clientId', operator: '==', value: clientId }],
        orderBy: [{ field: 'callDate', direction: 'desc' }]
      });
    } catch (error) {
      console.warn(`Query failed for calls with clientId ${clientId}, falling back to filter:`, error);
      const allCalls = await this.getAll();
      return allCalls.filter(call => call.clientId === clientId);
    }
  }

  /**
   * Create a new call record
   */
  async createCall(callData: Omit<Call, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    return this.create(callData);
  }

  /**
   * Update a call record
   */
  async updateCall(callId: string, callData: Partial<Call>): Promise<void> {
    return this.update(callId, callData);
  }

  /**
   * Delete a call record
   */
  async deleteCall(callId: string): Promise<void> {
    return this.delete(callId);
  }
}

/**
 * POA Service - FIXED to use 'clientId' field (not 'id')
 */
export class POAService extends FirestoreService<POARecord> {
  constructor() {
    super('poaRecords');
  }

  /**
   * Get POA records by client ID - FIXED to use 'clientId' field
   */
  async getByClientId(clientId: string): Promise<POARecord[]> {
    console.log(`\n🔍 ========== POA SEARCH START ==========`);
    console.log(`🔍 Searching for POAs with client ID: "${clientId}"`);

    // Get ALL POAs and filter in JavaScript
    const allPOAs = await this.getAll();
    console.log(`📚 Total POAs loaded: ${allPOAs.length}`);

    if (allPOAs.length > 0) {
      console.log(`\n🔑 Fields in first POA:`, Object.keys(allPOAs[0]));
      console.log(`📄 First POA clientId field value:`, (allPOAs[0] as any).clientId);
    }

    // Filter POAs where the 'clientId' field matches
    const matchingPOAs = allPOAs.filter(poa => {
      const poaClientId = (poa as any).clientId;  // POAs use 'clientId', not 'id'
      const matches = poaClientId === clientId;

      if (matches) {
        console.log(`✅ MATCH: poa.clientId="${poaClientId}" === clientId="${clientId}"`);
      }

      return matches;
    });

    console.log(`📋 Found ${matchingPOAs.length} POA(s) for client "${clientId}"`);
    console.log(`🔍 ========== POA SEARCH END ==========\n`);

    return matchingPOAs;
  }

  /**
   * Find valid POA for a specific notice
   */
  async findValidPOA(
    clientId: string,
    form: string,
    period: string
  ): Promise<POARecord | null> {
    console.log(`\n🔍 Looking for POA: clientId="${clientId}", form="${form}", period="${period}"`);

    const clientPOAs = await this.getByClientId(clientId);
    console.log(`📋 Found ${clientPOAs.length} POAs for client ${clientId}`);

    const periodNum = parseInt(period);
    if (isNaN(periodNum)) {
      console.log(`❌ Invalid period format: ${period}`);
      return null;
    }

    for (const poa of clientPOAs) {
      console.log(`  Checking POA: form="${poa.form}", start="${poa.periodStart}", end="${poa.periodEnd}"`);

      if (poa.form !== form) {
        console.log(`    ❌ Form mismatch: "${poa.form}" !== "${form}"`);
        continue;
      }

      const startNum = parseInt(poa.periodStart);
      const endNum = parseInt(poa.periodEnd);

      if (isNaN(startNum) || isNaN(endNum)) {
        console.log(`    ❌ Invalid period numbers: start="${poa.periodStart}", end="${poa.periodEnd}"`);
        continue;
      }

      // Check if period is within range
      if (periodNum >= startNum && periodNum <= endNum) {
        console.log(`    ✅ MATCH FOUND! Period ${periodNum} is between ${startNum}-${endNum}`);
        return poa;
      } else {
        console.log(`    ❌ Period out of range: ${periodNum} not between ${startNum}-${endNum}`);
      }
    }

    console.log(`❌ No valid POA found for clientId="${clientId}", form="${form}", period="${period}"\n`);
    return null;
  }
}

// Export service instances - CRITICAL: These must be exported!
export const noticeService = new NoticeService();
export const clientService = new ClientService();
export const callService = new CallService();
export const poaService = new POAService();
