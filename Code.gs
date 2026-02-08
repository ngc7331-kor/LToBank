// ============================================
// code.gs - Google Apps Script 백엔드 코드
// ============================================

// 🔒 보안 설정: 이메일 가져오기
function getFamilyEmails() {
  const scriptProperties = PropertiesService.getScriptProperties();
  const parentEmail = scriptProperties.getProperty("PICK_PARENT_EMAIL");
  const cwEmail = scriptProperties.getProperty("PICK_CW_EMAIL");
  const dkEmail = scriptProperties.getProperty("PICK_DK_EMAIL");

  if (!parentEmail || !cwEmail || !dkEmail) {
    Logger.log(
      "⚠️ 경고: 이메일 설정이 완료되지 않았습니다. setupScriptProperties()를 실행해주세요.",
    );
  }

  return {
    parent: parentEmail,
    cw: cwEmail,
    dk: dkEmail,
  };
}

// ⚙️ 초기 설정 (배포 전 1회 실행 필수)
function setupScriptProperties() {
  const scriptProperties = PropertiesService.getScriptProperties();

  // 👇 아래에 실제 가족 이메일 주소를 입력하세요.
  const REAL_EMAILS = {
    PICK_PARENT_EMAIL: "아빠_실제_이메일@gmail.com",
    PICK_CW_EMAIL: "cw_실제_이메일@gmail.com",
    PICK_DK_EMAIL: "dk_실제_이메일@gmail.com",
  };

  scriptProperties.setProperties(REAL_EMAILS);
  Logger.log("✅ 이메일 설정이 완료되었습니다! 이제 앱이 정상 작동합니다.");
}

// 이메일을 이름(ID)으로 변환
function getNameFromEmail(email) {
  const emails = getFamilyEmails();
  if (email === emails.parent) return "admin";
  if (email === emails.cw) return "cw";
  if (email === emails.dk) return "dk";
  return email;
}

// 현재 사용자가 부모(admin)인지 확인
function isParent() {
  const userEmail = Session.getActiveUser().getEmail();
  const emails = getFamilyEmails();
  return userEmail === emails.parent;
}

// 접근 권한 확인
function checkPermission(userEmail) {
  const emails = getFamilyEmails();
  const allowed = [emails.parent, emails.cw, emails.dk];
  return allowed.includes(userEmail);
}

// 웹앱 접근 시 실행
function doGet() {
  return HtmlService.createHtmlOutputFromFile("index")
    .setTitle("L.To Bank")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

// 이메일 알림 발송
function sendEmailNotification(action, transaction, recorderName) {
  const emails = getFamilyEmails();
  const parentEmail = emails.parent;

  if (!parentEmail) return;

  const subject = `[L.To Bank] ${recorderName}님이 ${action} 요청`;
  const actionText =
    action === "등록"
      ? "새 거래를 등록했습니다"
      : action === "수정"
        ? "거래를 수정했습니다"
        : "거래를 삭제했습니다";

  const body = `
L.To Bank 알림

${recorderName}님이 ${actionText}.

[ 거래 정보 ]
- 날짜: ${transaction.date}
- 대상: ${transaction.name}
- 구분: ${transaction.type}
- 금액: ${transaction.amount.toLocaleString()}원

승인이 필요합니다.
웹앱에서 확인 후 승인 또는 거절해주세요.

감사합니다.
  `;

  try {
    MailApp.sendEmail(parentEmail, subject, body);
  } catch (error) {
    console.log("이메일 발송 실패:", error);
  }
}

// 거래 내역 가져오기 (승인된 것만)
function getTransactions() {
  const userEmail = Session.getActiveUser().getEmail();
  if (!checkPermission(userEmail)) {
    throw new Error("접근 권한이 없습니다.");
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName("기록자") || ss.getSheets()[0];
  const data = sheet.getDataRange().getValues();

  const transactions = [];
  for (let i = 1; i < data.length; i++) {
    if (data[i][0]) {
      const status = data[i][5] || ""; // F열: 상태
      const approvalStatus = data[i][6] || "승인됨"; // G열: 승인상태

      // 삭제되었거나 승인 대기중인 것은 제외
      if (status === "삭제" || approvalStatus === "대기중") {
        continue;
      }

      if (data[i].length >= 5 && data[i][2]) {
        transactions.push({
          id: i,
          date: formatDate(data[i][0]),
          recorder: data[i][1],
          name: data[i][2],
          type: data[i][3],
          amount: Number(data[i][4]) || 0,
        });
      }
    }
  }

  // 날짜 기준 오름차순 정렬 (과거 -> 최신)
  // (프론트엔드에서 최근 10개를 뒤에서 잘라 역순으로 보여주기 때문)
  transactions.sort((a, b) => {
    const dateA = new Date(a.date);
    const dateB = new Date(b.date);
    return dateA - dateB || a.id - b.id;
  });

  return transactions;
}

// 승인 대기중인 거래 가져오기 (부모만)
function getPendingTransactions() {
  if (!isParent()) {
    return [];
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName("기록자");
  const data = sheet.getDataRange().getValues();

  const pending = [];
  for (let i = 1; i < data.length; i++) {
    if (data[i][0]) {
      const approvalStatus = data[i][6] || ""; // G열: 승인상태

      if (approvalStatus === "대기중") {
        pending.push({
          id: i,
          date: formatDate(data[i][0]),
          recorder: data[i][1],
          name: data[i][2],
          type: data[i][3],
          amount: Number(data[i][4]) || 0,
          action: data[i][5] || "입력", // F열: 상태 (입력/수정/삭제)
        });
      }
    }
  }

  return pending;
}

// 거래 승인 (부모만)
function approveTransaction(rowId) {
  if (!isParent()) {
    throw new Error("승인 권한이 없습니다.");
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const recordSheet = ss.getSheetByName("기록자");

  // 거래 정보 가져오기
  const row = recordSheet.getRange(rowId + 1, 1, 1, 7).getValues()[0];
  const transaction = {
    date: formatDate(row[0]),
    name: row[2],
    type: row[3],
    amount: Number(row[4]),
  };
  const action = row[5]; // 입력/수정/삭제

  // 승인 상태 업데이트
  recordSheet.getRange(rowId + 1, 7).setValue("승인됨"); // G열
  recordSheet.getRange(rowId + 1, 8).setValue("admin"); // H열: 승인자
  recordSheet.getRange(rowId + 1, 9).setValue(new Date()); // I열: 승인일시

  // 개인 시트에 실제 반영
  // 개인 시트에 실제 반영
  // 주의: 실제 구글 스프레드시트의 시트 이름도 'cw', 'dk'로 변경해야 작동합니다.

  const personalSheet = ss.getSheetByName(transaction.name);

  if (action === "입력") {
    // 입금 처리
    if (personalSheet) {
      const lastRow = personalSheet.getLastRow();
      let finalAmount = 0;

      if (lastRow > 1) {
        finalAmount =
          Number(personalSheet.getRange(lastRow, 5).getValue()) || 0;
      }

      if (transaction.type === "입금") {
        finalAmount += transaction.amount;
      } else {
        finalAmount -= transaction.amount;
      }

      personalSheet.appendRow([
        transaction.date,
        transaction.name,
        transaction.type,
        transaction.amount,
        finalAmount,
      ]);
    }
  } else if (action === "수정" || action === "삭제") {
    // 수정/삭제는 이미 처리되었으므로 승인만 표시
  }

  return { success: true };
}

// 거래 거절 (부모만)
function rejectTransaction(rowId) {
  if (!isParent()) {
    throw new Error("거절 권한이 없습니다.");
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const recordSheet = ss.getSheetByName("기록자");

  // 승인 상태 업데이트
  recordSheet.getRange(rowId + 1, 7).setValue("거절됨"); // G열
  recordSheet.getRange(rowId + 1, 8).setValue("admin"); // H열: 승인자
  recordSheet.getRange(rowId + 1, 9).setValue(new Date()); // I열: 승인일시

  return { success: true };
}

// 개인 시트에서 직접 데이터 가져오기
function getPersonalSheetData(name) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(name);

  if (!sheet) {
    return { deposit: 0, transactions: [] };
  }

  const data = sheet.getDataRange().getValues();
  const transactions = [];

  for (let i = 1; i < data.length; i++) {
    if (data[i][0]) {
      transactions.push({
        date: formatDate(data[i][0]),
        name: data[i][1],
        type: data[i][2],
        amount: Number(data[i][3]) || 0,
      });
    }
  }

  let deposit = 0;
  transactions.forEach((t) => {
    if (t.type === "입금") {
      deposit += t.amount;
    } else if (t.type === "출금") {
      deposit -= t.amount;
    }
  });

  return { deposit: deposit, transactions: transactions };
}

// 새 거래 추가
function addTransaction(transaction) {
  const userEmail = Session.getActiveUser().getEmail();
  if (!checkPermission(userEmail)) {
    throw new Error("접근 권한이 없습니다.");
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const recorderName = getNameFromEmail(userEmail);
  const needsApproval = !isParent();

  // 기록자 시트에 추가
  const recordSheet = ss.getSheetByName("기록자");
  if (recordSheet) {
    recordSheet.appendRow([
      transaction.date, // A열: 날짜
      recorderName, // B열: 기록자
      transaction.name, // C열: 이름 (cw/dk)
      transaction.type, // D열: 구분
      transaction.amount, // E열: 금액
      "입력", // F열: 상태
      needsApproval ? "대기중" : "승인됨", // G열: 승인상태
      needsApproval ? "" : "admin", // H열: 승인자
      needsApproval ? "" : new Date(), // I열: 승인일시
    ]);
  }

  // 부모가 아닌 경우 이메일 알림
  if (needsApproval) {
    sendEmailNotification("등록", transaction, recorderName);
    return { success: true, needsApproval: true };
  }

  // 부모인 경우 즉시 개인 시트에 반영
  const personalSheet = ss.getSheetByName(transaction.name);
  if (personalSheet) {
    const lastRow = personalSheet.getLastRow();
    let finalAmount = 0;

    if (lastRow > 1) {
      finalAmount = Number(personalSheet.getRange(lastRow, 5).getValue()) || 0;
    }

    if (transaction.type === "입금") {
      finalAmount += transaction.amount;
    } else {
      finalAmount -= transaction.amount;
    }

    personalSheet.appendRow([
      transaction.date,
      transaction.name,
      transaction.type,
      transaction.amount,
      finalAmount,
    ]);
  }

  return { success: true, needsApproval: false };
}

// 거래 수정
function updateTransaction(rowId, transaction) {
  const userEmail = Session.getActiveUser().getEmail();
  if (!checkPermission(userEmail)) {
    throw new Error("접근 권한이 없습니다.");
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const recordSheet = ss.getSheetByName("기록자");
  const recorderName = getNameFromEmail(userEmail);
  const needsApproval = !isParent();

  const oldData = recordSheet.getRange(rowId + 1, 1, 1, 5).getValues()[0];
  const oldName = oldData[2];
  const oldDate = formatDate(oldData[0]);
  const oldType = oldData[3];
  const oldAmount = Number(oldData[4]);

  // 부모가 아닌 경우: 승인 대기 상태로 기록만
  if (needsApproval) {
    recordSheet.appendRow([
      transaction.date,
      recorderName,
      transaction.name,
      transaction.type,
      transaction.amount,
      "수정",
      "대기중",
      "",
      "",
    ]);

    sendEmailNotification("수정", transaction, recorderName);
    return { success: true, needsApproval: true };
  }

  // 부모인 경우: 즉시 개인 시트에 반영
  const personalSheet = ss.getSheetByName(oldName);
  if (personalSheet) {
    const data = personalSheet.getDataRange().getValues();
    for (let i = 1; i < data.length; i++) {
      if (
        formatDate(data[i][0]) === oldDate &&
        data[i][2] === oldType &&
        Number(data[i][3]) === oldAmount
      ) {
        personalSheet
          .getRange(i + 1, 1, 1, 4)
          .setValues([
            [
              transaction.date,
              transaction.name,
              transaction.type,
              transaction.amount,
            ],
          ]);
        recalculateFinalAmounts(personalSheet);
        break;
      }
    }
  }

  recordSheet.appendRow([
    transaction.date,
    recorderName,
    transaction.name,
    transaction.type,
    transaction.amount,
    "수정",
    "승인됨",
    "admin",
    new Date(),
  ]);

  return { success: true, needsApproval: false };
}

// 거래 삭제
function deleteTransaction(rowId) {
  const userEmail = Session.getActiveUser().getEmail();
  if (!checkPermission(userEmail)) {
    throw new Error("접근 권한이 없습니다.");
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const recordSheet = ss.getSheetByName("기록자");
  const recorderName = getNameFromEmail(userEmail);
  const needsApproval = !isParent();

  const row = recordSheet.getRange(rowId + 1, 1, 1, 5).getValues()[0];
  const name = row[2];
  const date = formatDate(row[0]);
  const type = row[3];
  const amount = Number(row[4]);

  const transaction = { date, name, type, amount };

  // 부모가 아닌 경우: 승인 대기 상태로 기록만
  if (needsApproval) {
    recordSheet.appendRow([
      row[0],
      recorderName,
      row[2],
      row[3],
      row[4],
      "삭제",
      "대기중",
      "",
      "",
    ]);

    sendEmailNotification("삭제", transaction, recorderName);
    return { success: true, needsApproval: true };
  }

  // 부모인 경우: 즉시 개인 시트에서 삭제
  const personalSheet = ss.getSheetByName(name);
  if (personalSheet) {
    const data = personalSheet.getDataRange().getValues();
    for (let i = 1; i < data.length; i++) {
      if (
        formatDate(data[i][0]) === date &&
        data[i][2] === type &&
        Number(data[i][3]) === amount
      ) {
        personalSheet.deleteRow(i + 1);
        recalculateFinalAmounts(personalSheet);
        break;
      }
    }
  }

  recordSheet.appendRow([
    row[0],
    recorderName,
    row[2],
    row[3],
    row[4],
    "삭제",
    "승인됨",
    "admin",
    new Date(),
  ]);

  return { success: true, needsApproval: false };
}

// 개인 시트의 최종 금액 재계산
function recalculateFinalAmounts(sheet) {
  const data = sheet.getDataRange().getValues();
  let runningTotal = 0;

  for (let i = 1; i < data.length; i++) {
    if (data[i][0]) {
      const type = data[i][2];
      const amount = Number(data[i][3]);

      if (type === "입금") {
        runningTotal += amount;
      } else if (type === "출금") {
        runningTotal -= amount;
      }

      sheet.getRange(i + 1, 5).setValue(runningTotal);
    }
  }
}

// 날짜 포맷
function formatDate(date) {
  if (!date) return "";
  if (typeof date === "string") return date;

  const d = new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

// 현재 사용자 이메일 반환
function getUserEmail() {
  return Session.getActiveUser().getEmail();
}

// 현재 사용자가 부모인지 확인
function checkIsParent() {
  return isParent();
}
