import '../models/client.dart';
import '../models/notice.dart';
import '../models/call.dart';

final dummyClients = [
  Client(
    id: "ACME1234",
    name: "Acme Corp",
    contact: "John Doe",
    email: "john@acme.com",
  ),
  Client(
    id: "BLUE1234",
    name: "Blue Rock LLC",
    contact: "Sarah Smith",
    email: "sarah@bluerock.com",
  ),
];

final dummyCalls = [
  Call(
    id: 1,
    noticeId: 1,
    callDate: DateTime.now().subtract(const Duration(days: 1)),
    irsLine: "PPS",
    agentName: "Agent Smith",
    agentId: "12345",
    startTime: DateTime.now().subtract(const Duration(minutes: 60)),
    endTime: DateTime.now().subtract(const Duration(minutes: 15)),
    holdMinutes: 10, // ✅ fixed
    notes: "Discussed penalty abatement.",
    billed: true,
  ),
];

final dummyNotices = [
  Notice(
    id: 1,
    clientId: "ACME1234",
    noticeNumber: "CP2000",
    period: "2022",
    dateReceived: DateTime.now().subtract(const Duration(days: 10)),
    dueDate: DateTime.now().add(const Duration(days: 20)),
    status: "Open",
    issue: "Underreported income",
    calls: dummyCalls, // ✅ required
  ),
  Notice(
    id: 2,
    clientId: "BLUE1234",
    noticeNumber: "CP14",
    period: "2021",
    dateReceived: DateTime.now().subtract(const Duration(days: 20)),
    dueDate: DateTime.now().add(const Duration(days: 10)),
    status: "Escalated",
    issue: "Balance due",
    calls: [], // ✅ required
  ),
];
