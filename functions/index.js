const functions = require("firebase-functions");
const admin = require("firebase-admin");
const ExcelJS = require("exceljs");
const { google } = require("googleapis");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");


admin.initializeApp();
const db = admin.firestore();

// 🔑 Auth for Google Drive (uses Firebase service account)
const auth = new google.auth.GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/drive.file"],
});
const drive = google.drive({ version: "v3", auth });

const {onSchedule} = require("firebase-functions/v2/scheduler");

exports.exportNoticesToGoogleDrive = onSchedule("0 * * * *", async (event) => {
  console.log("⏳ Starting export to Google Drive...");


    // 1. Fetch Firestore data
    const noticesSnap = await db.collection("notices").get();
    const callsSnap = await db.collection("calls").get();

    // 2. Build Excel workbook
    const workbook = new ExcelJS.Workbook();

    // --- Notices Sheet ---
    const noticeSheet = workbook.addWorksheet("Notices");
    noticeSheet.columns = [
      { header: "Notice ID", key: "id", width: 25 },
      { header: "Client ID", key: "clientId", width: 20 },
      { header: "Status", key: "status", width: 15 },
      { header: "Date Received", key: "dateReceived", width: 20 },
      { header: "Days Remaining", key: "daysRemaining", width: 18 },
      { header: "Escalated", key: "escalated", width: 12 },
    ];
    noticesSnap.forEach((doc) => {
      const n = doc.data();
      noticeSheet.addRow({
        id: doc.id,
        clientId: n.clientId,
        status: n.status,
        dateReceived: n.dateReceived
          ? new Date(n.dateReceived).toISOString().split("T")[0]
          : "",
        daysRemaining: n.daysRemaining ?? "",
        escalated: n.escalated ? "Yes" : "No",
      });
    });

    // Style Notices header
    noticeSheet.getRow(1).eachCell((cell) => {
      cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: "FF1F4E78" },
      };
      cell.alignment = { vertical: "middle", horizontal: "center" };
    });

    // --- Calls Sheet ---
    const callSheet = workbook.addWorksheet("Calls");
    callSheet.columns = [
      { header: "Call ID", key: "id", width: 25 },
      { header: "Notice ID", key: "noticeId", width: 25 },
      { header: "Client ID", key: "clientId", width: 20 },
      { header: "Date", key: "date", width: 20 },
      { header: "Response Method", key: "responseMethod", width: 25 },
      { header: "Outcome", key: "outcome", width: 20 },
      { header: "Billing", key: "billing", width: 15 },
    ];
    callsSnap.forEach((doc) => {
      const c = doc.data();
      callSheet.addRow({
        id: doc.id,
        noticeId: c.noticeId,
        clientId: c.clientId,
        date: c.date
          ? new Date(c.date).toISOString().split("T")[0]
          : "",
        responseMethod: c.responseMethod,
        outcome: c.outcome ?? "",
        billing: c.billing ?? "Unbilled",
      });
    });

    // Style Calls header
    callSheet.getRow(1).eachCell((cell) => {
      cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: "FF1F4E78" },
      };
      cell.alignment = { vertical: "middle", horizontal: "center" };
    });

    // --- Summary Sheet ---
    const summarySheet = workbook.addWorksheet("Summary");
    summarySheet.columns = [
      { header: "Client ID", key: "clientId", width: 20 },
      { header: "Call ID", key: "callId", width: 25 },
      { header: "Minutes", key: "minutes", width: 12 },
      { header: "Billable Amount", key: "amount", width: 20 },
    ];

    const clientCalls = {};
    callsSnap.forEach((doc) => {
      const c = doc.data();
      if (c.billable === false) return;

      const clientId = c.clientId || "Unknown";
      if (!clientCalls[clientId]) clientCalls[clientId] = [];
      clientCalls[clientId].push({ id: doc.id, ...c });
    });

    Object.entries(clientCalls).forEach(([clientId, calls]) => {
      let totalMinutes = 0;
      let totalAmount = 0;

      // Client header
      summarySheet.addRow({ clientId: `Client: ${clientId}` }).font = { bold: true };

      calls.forEach((c) => {
        const rate = c.hourlyRate ?? 250;
        let amt = ((c.durationMinutes ?? 0) / 60) * rate;
        if (c.responseMethod && c.responseMethod.toLowerCase().includes("research")) {
          amt = Math.ceil(amt / 5) * 5;
        } else {
          if (amt < 250) amt = 250;
        }

        totalMinutes += c.durationMinutes ?? 0;
        totalAmount += amt;

        summarySheet.addRow({
          clientId: "",
          callId: c.id,
          minutes: c.durationMinutes ?? 0,
          amount: amt,
        });
      });

      // Subtotal row
      const subtotalRow = summarySheet.addRow({
        clientId: `Subtotal ${clientId}`,
        callId: "",
        minutes: totalMinutes,
        amount: totalAmount,
      });
      subtotalRow.font = { bold: true };
      subtotalRow.eachCell((cell) => {
        cell.fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: "FFE2EFDA" }, // light green
        };
      });

      summarySheet.addRow({});
    });

    // Style Summary header
    summarySheet.getRow(1).eachCell((cell) => {
      cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: "FF2F75B5" },
      };
      cell.alignment = { vertical: "middle", horizontal: "center" };
    });

    // Currency formatting
    summarySheet.getColumn("amount").numFmt = '"$"#,##0.00;[Red]\-"$"#,##0.00';

    // 3. Buffer
    const buffer = await workbook.xlsx.writeBuffer();

    // 4. Upload / overwrite in Drive
    const folderId = "1KYxo2_5bhd-tDnlvcOGVDm2Ti-ruz1bf"; // 🔑 Replace with your Drive folder ID
    const search = await drive.files.list({
      q: `name='notices.xlsx' and '${folderId}' in parents and trashed=false`,
      fields: "files(id, name)",
    });

    if (search.data.files.length > 0) {
      const fileId = search.data.files[0].id;
      await drive.files.update({
        fileId,
        media: {
          mimeType:
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          body: Buffer.from(buffer),
        },
      });
      console.log(`♻️ Updated existing notices.xlsx (${fileId})`);
    } else {
      await drive.files.create({
        resource: {
          name: "notices.xlsx",
          parents: [folderId],
        },
        media: {
          mimeType:
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          body: Buffer.from(buffer),
        },
      });
      console.log("📄 Created new notices.xlsx");
    }

    return null;
  });

exports.updateNoticeStatus = onDocumentWritten("notices/{noticeId}", async (event) => {
  const notice = event.data.after.exists ? event.data.after.data() : null;
  if (!notice) return null;

  let status = "Open";

  if (notice.outcome === "Resolved") {
    status = "Closed";
  } else if (
    ["CP504", "LT11", "Letter 3172"].includes(notice.type) ||
    (notice.dueDate &&
      (() => {
        const due = new Date(notice.dueDate);
        const today = new Date();
        const daysLeft = Math.ceil((due - today) / (1000 * 60 * 60 * 24));
        return daysLeft >= 0 && daysLeft <= 3;
      })())
  ) {
    status = "Escalated";
  } else if (notice.outcome === "Waiting on Client") {
    status = "Waiting on Client";
  } else if (notice.outcome === "Waiting on IRS") {
    status = "Awaiting IRS Response";
  }

  if (notice.status !== status) {
    await event.data.after.ref.update({ status });
  }

  return null;
});

exports.scheduledNoticeStatusCheck = onSchedule(
  {
    schedule: "every day 02:00",
    timeZone: "America/New_York",
  },
  async (event) => {
    const snapshot = await db.collection("notices").get();
    const batch = db.batch();
    const today = new Date();

    snapshot.forEach((doc) => {
      const notice = doc.data();
      let status = "Open";

      if (notice.outcome === "Resolved") {
        status = "Closed";
      } else if (
        ["CP504", "LT11", "Letter 3172"].includes(notice.type) ||
        (notice.dueDate &&
          (() => {
            const due = new Date(notice.dueDate);
            const daysLeft = Math.ceil((due - today) / (1000 * 60 * 60 * 24));
            return daysLeft >= 0 && daysLeft <= 3;
          })())
      ) {
        status = "Escalated";
      } else if (notice.outcome === "Waiting on Client") {
        status = "Waiting on Client";
      } else if (notice.outcome === "Waiting on IRS") {
        status = "Awaiting IRS Response";
      }

      if (notice.status !== status) {
        batch.update(doc.ref, { status });
      }
    });

    await batch.commit();
    console.log("✅ Scheduled Notice Status Check complete");
    return null;
  }
);
