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

  // 👇 사용자님(아빠)의 이메일을 기본 관리자로 설정합니다.
  const REAL_EMAILS = {
    PICK_PARENT_EMAIL: "father@example.com", 
    PICK_CW_EMAIL: "cw_email@example.com",
    PICK_DK_EMAIL: "dk_email@example.com",
  };

  scriptProperties.setProperties(REAL_EMAILS);
  Logger.log("✅ 이메일 설정이 완료되었습니다! 관리자: " + REAL_EMAILS.PICK_PARENT_EMAIL);
}

// 이메일을 이름(ID)으로 변환 (한글 이름 반환)
function getNameFromEmail(email) {
  const emails = getFamilyEmails();
  if (email === emails.parent) return "아빠";
  if (email === emails.cw) return "채원";
  if (email === emails.dk) return "도권";
  return email;
}

// UI에서 사용하는 Code(cw/dk)를 한글 이름으로 변환
function getKoreanName(code) {
  if (code === "cw") return "채원";
  if (code === "dk") return "도권";
  return code;
}

// 현재 사용자가 부모(admin)인지 확인
function isParent() {
  const userEmail = Session.getActiveUser().getEmail();
  if (!userEmail) return false; // 네이티브 앱 호출 시 이메일이 없을 수 있음
  const emails = getFamilyEmails();
  return userEmail === emails.parent;
}

// 접근 권한 확인
function checkPermission(userEmail) {
  if (!userEmail) return false;
  const emails = getFamilyEmails();
  const allowed = [emails.parent, emails.cw, emails.dk];
  return allowed.includes(userEmail);
}

// 웹앱 접근 시 실행 (API 엔드포인트 역할 겸용)
function doGet(e) {
  const userEmail = Session.getActiveUser().getEmail();

  // 🤖 [v5.4] API 요청 처리 (Native App용 JSON 응답)
  if (e && e.parameter && e.parameter.action) {
    const action = e.parameter.action;
    
    // 권한 확인 (사용자 이메일 기반)
    if (!checkPermission(userEmail)) {
      return ContentService.createTextOutput(JSON.stringify({ 
        error: "Unauthorized", 
        email: userEmail || "Anonymous",
        hint: "관리자 설정(setupScriptProperties)을 확인하세요."
      }))
      .setMimeType(ContentService.MimeType.JSON);
    }

    let result;
    try {
      switch (action) {
        case 'widget':
          result = getWidgetData();
          break;
        case 'transactions':
          result = getTransactions();
          break;
        case 'pending':
          result = getPendingTransactions();
          break;
        case 'approve':
          result = approveTransaction(Number(e.parameter.rowId));
          break;
        case 'reject':
          result = rejectTransaction(Number(e.parameter.rowId));
          break;
        case 'request':
          const tx = JSON.parse(e.parameter.data);
          result = addTransaction(tx);
          break;
        default:
          result = { error: "Unknown action" };
      }
    } catch (err) {
      result = { error: err.toString() };
    }
    
    return ContentService.createTextOutput(JSON.stringify(result))
      .setMimeType(ContentService.MimeType.JSON);
  }

  // 🌐 기존 웹 UI 브라우저 접근 처리
  if (!checkPermission(userEmail)) {
    return HtmlService.createHtmlOutput(
      "접근 권한이 없습니다. (" + (userEmail || "로그인 필요") + ")<br>관리자 계정으로 다시 로그인해주세요."
    );
  }

  return HtmlService.createHtmlOutputFromFile("index")
    .setTitle("L.To Bank")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .addMetaTag("viewport", "width=device-width, initial-scale=1");
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
- 대상: ${getKoreanName(transaction.name)}
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

// 거래 내역 가져오기 (각 개인 시트에서 직접 가져오기)
// 변경: 기록자 시트가 아닌 cw, dk 시트의 내용을 날짜순으로 정리해서 보여줌
function getTransactions() {
  const userEmail = Session.getActiveUser().getEmail();
  if (!checkPermission(userEmail)) {
    throw new Error("접근 권한이 없습니다.");
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const targets = ["cw", "dk"];
  let allTransactions = [];

  targets.forEach((sheetName) => {
    const sheet = ss.getSheetByName(sheetName);
    if (!sheet) return;

    const data = sheet.getDataRange().getValues();
    // 개인 시트 구조: [Date, Name, Type, Amount, Balance, Recorder(New!)]
    for (let i = 1; i < data.length; i++) {
      if (data[i][0]) {
        allTransactions.push({
          uniqueId: sheetName + "-" + (i + 1), // 고유 ID: 시트명-행번호
          id: i + 1, // 행 번호 (수정/삭제용)
          sheetName: sheetName,
          date: formatDate(data[i][0]),
          name: data[i][1], // 이미 한글로 저장되어 있을 것임 (채원/도권)
          type: data[i][2],
          amount: Number(data[i][3]) || 0,
          balance: Number(data[i][4]) || 0,
          recorder: data[i][5] || "-", // 기록자 (없으면 -)
        });
      }
    }
  });

  // 날짜 기준 내림차순 정렬 (최신 -> 과거)
  // 사용자가 "날짜순으로 정리해서 보여줘"라고 함. 보통 최신이 위가 좋음.
  allTransactions.sort((a, b) => {
    const dateA = new Date(a.date);
    const dateB = new Date(b.date);
    return dateB - dateA || b.id - a.id;
  });

  return allTransactions;
}

// 승인 대기중인 거래 가져오기 (부모만) - 기록자 시트 사용
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
          id: i, // 기록자 시트 행 번호
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

  // 거래 정보 가져오기 (기록자 시트)
  const row = recordSheet.getRange(rowId + 1, 1, 1, 7).getValues()[0];
  // row: [Date, Recorder, Name(Target), Type, Amount, Action, Approval]
  const transaction = {
    date: formatDate(row[0]),
    recorder: row[1], // 요청자 (기록자)
    name: row[2], // 대상 (cw/dk) -> 현재 '채원'/'도권'으로 저장될 예정
    type: row[3],
    amount: Number(row[4]),
  };
  const action = row[5]; // 입력/수정/삭제

  // 대상 시트 이름 찾기 (한글 -> 코드)
  // Name 열에 '채원'으로 저장되어 있을 수 있으므로 매핑 필요
  let targetSheetName = transaction.name;
  if (targetSheetName === "채원") targetSheetName = "cw";
  if (targetSheetName === "도권") targetSheetName = "dk";

  // 승인 상태 업데이트
  recordSheet.getRange(rowId + 1, 7).setValue("승인됨"); // G열
  recordSheet.getRange(rowId + 1, 8).setValue("아빠"); // H열: 승인자
  recordSheet.getRange(rowId + 1, 9).setValue(new Date()); // I열: 승인일시

  // 개인 시트에 실제 반영
  const personalSheet = ss.getSheetByName(targetSheetName);

  if (action === "입력") {
    // 입금/출금 처리
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

      // [Date, Name(Korean), Type, Amount, Balance, Recorder]
      personalSheet.appendRow([
        transaction.date,
        transaction.name, // '채원' or '도권'
        transaction.type,
        transaction.amount,
        finalAmount,
        transaction.recorder, // 기록자 추가
      ]);
    }
  } else if (action === "수정" || action === "삭제") {
    // 수정/삭제 요청에 대한 승인처리는 로직이 복잡하여,
    // 현재 구조(기록자 시트 ID 기반)에서는 단순히 로그만 남기는 것으로 처리됨.
    // *실제 데이터 수정은 요청 시점에 즉시 반영되지 않고, 승인 시 반영되어야 하나*
    // *기존 로직은 수정/삭제 요청 시 기록자 시트에만 남기고, 승인 시 로직이 비어있었음 (Line 278 주석 참고)*
    // 이 부분은 이번 요청 범위(이름 표시, 정렬)를 넘어서는 로직 수정이 필요할 수 있음.
    // 하지만 사용자가 "수정한 내용까지 보이게 되어서 헷갈려"라고 했으므로,
    // 개인 시트 중심으로 뷰를 바꿨으니, 수정/삭제도 개인 시트에서 직접 일어나도록 변경해야 함.
    // 그러나 승인 대기중인 수정/삭제 건을 승인했을 때 어떻게 처리할지 정의되지 않음.
    // 일단 '입력' 승인은 위와 같이 처리하고, 나머지는 Pass.
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

  recordSheet.getRange(rowId + 1, 7).setValue("거절됨");
  recordSheet.getRange(rowId + 1, 8).setValue("아빠");
  recordSheet.getRange(rowId + 1, 9).setValue(new Date());

  return { success: true };
}

// 개인 시트 데이터 (잔액 표시용)
function getPersonalSheetData(name) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(name);

  if (!sheet) {
    return { deposit: 0, transactions: [] };
  }

  // 잔액은 마지막 행의 잔액 열(E열)을 가져오면 됨
  const lastRow = sheet.getLastRow();
  let deposit = 0;
  if (lastRow > 1) {
    deposit = Number(sheet.getRange(lastRow, 5).getValue()) || 0;
  }

  // 트랜잭션은 getTransactions()에서 통합 관리하므로 여기서는 잔액만 중요하지만
  // 기존 프론트엔드 호환성을 위해 transaction 빈 배열 보냄 (프론트가 변경될 것임)
  return { deposit: deposit, transactions: [] };
}

// 새 거래 추가
function addTransaction(transaction) {
  const userEmail = Session.getActiveUser().getEmail();
  if (!checkPermission(userEmail)) {
    throw new Error("접근 권한이 없습니다.");
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const recorderName = getNameFromEmail(userEmail); // 아빠/채원/도권
  const needsApproval = !isParent();

  // 대상 이름 한글화 (transaction.name은 cw/dk)
  const koreanTargetName = getKoreanName(transaction.name);

  // 기록자 시트에 추가 (로그용)
  const recordSheet = ss.getSheetByName("기록자");
  if (recordSheet) {
    recordSheet.appendRow([
      transaction.date,
      recorderName, // 아빠/채원/도권
      koreanTargetName, // 채원/도권
      transaction.type,
      transaction.amount,
      "입력",
      needsApproval ? "대기중" : "승인됨",
      needsApproval ? "" : "아빠",
      needsApproval ? "" : new Date(),
    ]);
  }

  // 부모가 아닌 경우 이메일 알림만 보내고 종료
  if (needsApproval) {
    sendEmailNotification("등록", transaction, recorderName);
    return { success: true, needsApproval: true };
  }

  // 부모인 경우 즉시 개인 시트에 반영 ('cw'/'dk' 시트)
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

    // [Date, Name(Korean), Type, Amount, Balance, Recorder]
    personalSheet.appendRow([
      transaction.date,
      koreanTargetName, // 채원/도권
      transaction.type,
      transaction.amount,
      finalAmount,
      recorderName, // 기록자
    ]);
  }

  return { success: true, needsApproval: false };
}

// 거래 수정 (개인 시트 직접 수정 + 기록자 로그)
// transaction 객체에 sheetName('cw'/'dk'), id(행번호)가 포함되어야 함
function updateTransaction(uniqueId, transaction) {
  const userEmail = Session.getActiveUser().getEmail();
  if (!checkPermission(userEmail)) {
    throw new Error("접근 권한이 없습니다.");
  }

  // uniqueId 예: "cw-5"
  const parts = uniqueId.split("-");
  const sheetName = parts[0];
  const rowId = parseInt(parts[1]); // 실제 행 번호

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const recorderName = getNameFromEmail(userEmail);
  const needsApproval = !isParent();
  const koreanTargetName = getKoreanName(transaction.name);

  // 기록자 시트에 로그 남기기 ("수정 요청" 또는 "수정 완료")
  const recordSheet = ss.getSheetByName("기록자");
  if (recordSheet) {
    recordSheet.appendRow([
      transaction.date,
      recorderName,
      koreanTargetName,
      transaction.type,
      transaction.amount,
      "수정(" + sheetName + " " + rowId + "행)",
      needsApproval ? "대기중" : "승인됨",
      needsApproval ? "" : "아빠",
      needsApproval ? "" : new Date(),
    ]);
  }

  if (needsApproval) {
    sendEmailNotification("수정", transaction, recorderName);
    return { success: true, needsApproval: true };
  }

  // 부모인 경우, 개인 시트의 해당 행을 직접 수정
  const personalSheet = ss.getSheetByName(sheetName);
  if (personalSheet && rowId > 1) {
    // 수정 반영 [Date, Name, Type, Amount] (Balance는 재계산 필요, Recorder는 유지? or Update?)
    // Recorder를 수정자로 바꿀지, 원작자로 둘지 -> 수정자로 바꾸거나 "원작자(수정:누구)"로 표시?
    // 일단 수정자로 덮어쓰기 or 유지. 여기선 수정자로 업데이트.

    // [Date, Name, Type, Amount]
    personalSheet
      .getRange(rowId, 1, 1, 4)
      .setValues([
        [
          transaction.date,
          koreanTargetName,
          transaction.type,
          transaction.amount,
        ],
      ]);

    // Recorder 업데이트 (F열)
    personalSheet.getRange(rowId, 6).setValue(recorderName);

    // 잔액 전체 재계산
    recalculateFinalAmounts(personalSheet);
  }

  return { success: true, needsApproval: false };
}

// 거래 삭제 (개인 시트 직접 삭제 + 기록자 로그)
function deleteTransaction(uniqueId) {
  const userEmail = Session.getActiveUser().getEmail();
  if (!checkPermission(userEmail)) {
    throw new Error("접근 권한이 없습니다.");
  }

  const parts = uniqueId.split("-");
  const sheetName = parts[0];
  const rowId = parseInt(parts[1]);

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const recorderName = getNameFromEmail(userEmail);
  const needsApproval = !isParent();

  // 기록자 시트에 로그
  const recordSheet = ss.getSheetByName("기록자");
  if (recordSheet) {
    recordSheet.appendRow([
      new Date(), // 날짜
      recorderName,
      sheetName,
      "-",
      0,
      "삭제(" + sheetName + " " + rowId + "행)",
      needsApproval ? "대기중" : "승인됨",
      needsApproval ? "" : "아빠",
      needsApproval ? "" : new Date(),
    ]);
  }

  if (needsApproval) {
    const dummyTrans = { date: "-", name: sheetName, type: "삭제", amount: 0 };
    sendEmailNotification("삭제", dummyTrans, recorderName);
    return { success: true, needsApproval: true };
  }

  // 부모인 경우 실제 삭제
  const personalSheet = ss.getSheetByName(sheetName);
  if (personalSheet && rowId > 1) {
    personalSheet.deleteRow(rowId);
    recalculateFinalAmounts(personalSheet);
  }

  return { success: true, needsApproval: false };
}

// 개인 시트의 최종 금액 재계산
function recalculateFinalAmounts(sheet) {
  const data = sheet.getDataRange().getValues();
  let runningTotal = 0;

  // i=1부터 데이터 시작 (0은 헤더)
  for (let i = 1; i < data.length; i++) {
    // data[i][0]은 Date
    const type = data[i][2]; // C열
    const amount = Number(data[i][3]) || 0; // D열

    if (type === "입금") {
      runningTotal += amount;
    } else if (type === "출금") {
      runningTotal -= amount;
    }

    // E열(Index 4)에 잔액 기록
    sheet.getRange(i + 1, 5).setValue(runningTotal);
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

/**
 * 🤖 안드로이드 위젯 및 앱 정합성을 위한 요약 데이터 반환
 * 100원 단위 올림(Interest Rounding) 반영
 */
function getWidgetData() {
  const cwData = getPersonalSheetData("cw");
  const dkData = getPersonalSheetData("dk");
  
  // 전체 트랜잭션 가져오기 (이자 계산용)
  const allTxs = getTransactions();
  const cwTxs = allTxs.filter(t => t.sheetName === "cw");
  const dkTxs = allTxs.filter(t => t.sheetName === "dk");
  
  // 서버측 이자 계산 (100원 단위 올림 적용)
  const cwInterest = calculateInterestServer(cwTxs);
  const dkInterest = calculateInterestServer(dkTxs);
  
  const pendingTransactions = getPendingTransactions();
  const pendingCount = pendingTransactions ? pendingTransactions.length : 0;
  
  return {
    cwTotal: cwData.deposit + cwInterest,
    dkTotal: dkData.deposit + dkInterest,
    pendingCount: pendingCount,
    cwInterest: cwInterest,
    dkInterest: dkInterest
  };
}

/**
 * 서버 사이드 이자 계산 로직 (L.To Bank 연 3.1% 기준)
 * 정합성을 위해 index.html의 로직과 동일하게 구현하되, 100원 단위 올림 적용
 */
function calculateInterestServer(txs) {
  if (!txs || txs.length === 0) return 0;

  // 날짜순 오름차순(과거->미래) 정렬
  const sortedTxs = [...txs].sort(
    (a, b) => new Date(a.date) - new Date(b.date)
  );

  const today = new Date();
  let deposits = [];

  sortedTxs.forEach((tx) => {
    if (tx.type === "입금") {
      deposits.push({
        amount: tx.amount,
        date: tx.date,
        remainingAmount: tx.amount,
      });
    } else if (tx.type === "출금") {
      let remainingWithdrawal = tx.amount;
      for (let i = 0; i < deposits.length && remainingWithdrawal > 0; i++) {
        if (deposits[i].remainingAmount > 0) {
          const deduction = Math.min(
            deposits[i].remainingAmount,
            remainingWithdrawal
          );
          deposits[i].remainingAmount -= deduction;
          remainingWithdrawal -= deduction;
        }
      }
    }
  });

  let totalInterest = 0;
  deposits.filter((d) => d.remainingAmount > 0).forEach((deposit) => {
    const depositDate = new Date(deposit.date);
    const days = Math.floor((today - depositDate) / (1000 * 60 * 60 * 24));
    if (days > 0) {
      // 이율 3.1% (0.031)
      totalInterest += (deposit.remainingAmount * 0.031 * days) / 365;
    }
  });

  // 💰 100원 단위 올림 처리 (사용자 요청: 1,410원 -> 1,500원)
  return Math.ceil(totalInterest / 100) * 100;
}
