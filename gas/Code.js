/**
 * GAS API Backend for Cleaning Report System
 * This serves as a JSON API for Flutter Web frontend.
 */

// Log levels for consistent logging
const LOG_LEVEL = {
  ERROR: 'ERROR',
  WARN: 'WARN',
  INFO: 'INFO'
};

/**
 * Structured logging helper
 */
function log(level, action, message, data) {
  const timestamp = new Date().toISOString();
  const logEntry = `[${timestamp}] [${level}] [${action}] ${message}`;
  if (data) {
    Logger.log(logEntry + ' | Data: ' + JSON.stringify(data));
  } else {
    Logger.log(logEntry);
  }
}

/**
 * Generate error ID for tracking
 */
function generateErrorId() {
  return 'ERR-' + new Date().getTime().toString(36).toUpperCase();
}

/**
 * Handle GET requests - API Router
 */
function doGet(e) {
  const action = e.parameter.action || 'ping';
  const callback = e.parameter.callback;

  let result;

  try {
    switch (action) {
      case 'ping':
        result = { success: true, message: 'API is running', timestamp: new Date().toISOString() };
        break;

      case 'getData':
        const month = e.parameter.month || null;
        result = apiGetData(month);
        break;

      case 'verifyPin':
        const pin = e.parameter.pin || '';
        result = verifyPin(pin);
        break;

      case 'generatePDF':
        const pdfMonth = e.parameter.month || null;
        const billingDate = e.parameter.billingDate || null;
        result = apiGeneratePDF(pdfMonth, billingDate);
        break;

      case 'saveReport':
        const dataParam = e.parameter.data || '{}';
        const reportData = JSON.parse(dataParam);
        result = apiSaveReport(reportData);
        break;

      case 'updateReport':
        const updateParam = e.parameter.data || '{}';
        const updateData = JSON.parse(updateParam);
        result = apiUpdateData(updateData);
        break;

      case 'deleteData':
        const deleteId = e.parameter.id || '';
        result = apiDeleteData(deleteId);
        break;

      default:
        result = { success: false, message: 'Unknown action: ' + action };
    }
  } catch (error) {
    const errorId = generateErrorId();
    log(LOG_LEVEL.ERROR, action, error.message, { errorId: errorId, stack: error.stack });
    result = {
      success: false,
      message: 'エラーが発生しました。サポートに連絡する際はエラーIDをお伝えください。',
      errorId: errorId,
      errorDetail: error.message
    };
  }

  return createJsonResponse(result, callback);
}

/**
 * Handle POST requests - For data mutations
 */
function doPost(e) {
  const callback = e.parameter.callback;
  let result;
  let action = 'unknown';

  try {
    const payload = JSON.parse(e.postData.contents);
    action = payload.action || '';

    switch (action) {
      case 'saveReport':
        result = apiSaveReport(payload.data);
        break;

      case 'deleteData':
        result = apiDeleteData(payload.id);
        break;

      default:
        result = { success: false, message: 'Unknown action: ' + action };
    }
  } catch (error) {
    const errorId = generateErrorId();
    log(LOG_LEVEL.ERROR, action, error.message, { errorId: errorId, stack: error.stack });
    result = {
      success: false,
      message: 'エラーが発生しました。サポートに連絡する際はエラーIDをお伝えください。',
      errorId: errorId,
      errorDetail: error.message
    };
  }

  return createJsonResponse(result, callback);
}

/**
 * Create JSON response (with optional JSONP callback)
 */
function createJsonResponse(data, callback) {
  const jsonStr = JSON.stringify(data);

  if (callback) {
    // JSONP response
    return ContentService.createTextOutput(callback + '(' + jsonStr + ')')
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }

  // Regular JSON response
  return ContentService.createTextOutput(jsonStr)
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Initial Setup: Creates necessary sheets if they don't exist
 * Run this function once manually.
 */
function initialSetup() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // 1. Setup ReportData sheet
  let reportSheet = ss.getSheetByName('ReportData');
  if (!reportSheet) {
    reportSheet = ss.insertSheet('ReportData');
    reportSheet.appendRow(['ID', 'Date', 'Type', 'Item', 'UnitPrice', 'Duration', 'Amount', 'Note', 'CreatedAt', 'Month']);
    reportSheet.setFrozenRows(1);
  }

  // 2. Setup Settings sheet
  let settingsSheet = ss.getSheetByName('Settings');
  if (!settingsSheet) {
    settingsSheet = ss.insertSheet('Settings');
    settingsSheet.appendRow(['Key', 'Value']);
    settingsSheet.appendRow(['PIN_CODE', '1234']);
    settingsSheet.setFrozenRows(1);
  }

  // 3. Setup Invoice Template
  let templateSheet = ss.getSheetByName('InvoiceTemplate');
  if (!templateSheet) {
    templateSheet = ss.insertSheet('InvoiceTemplate');
  }
}

/**
 * API: Get history data
 */
function apiGetData(monthStr) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('ReportData');

  if (sheet.getLastRow() <= 1) return { success: true, data: [] };

  const data = sheet.getDataRange().getValues();
  data.shift(); // Remove header

  if (!monthStr) {
    const d = new Date();
    monthStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM');
  }

  // Helper function to normalize month value to yyyy-MM format
  function normalizeMonth(val) {
    if (val instanceof Date) {
      return Utilities.formatDate(val, Session.getScriptTimeZone(), 'yyyy-MM');
    }
    if (typeof val === 'string') {
      if (val.includes('T') || val.includes('-')) {
        const d = new Date(val);
        if (!isNaN(d.getTime())) {
          return Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM');
        }
      }
      return val;
    }
    return String(val);
  }

  const filtered = data
    .filter(row => normalizeMonth(row[9]) === monthStr)
    .map(row => {
      let dateStr = '';
      try {
        if (row[1] instanceof Date) {
          dateStr = Utilities.formatDate(row[1], Session.getScriptTimeZone(), 'yyyy-MM-dd');
        } else if (row[1]) {
          const d = new Date(row[1]);
          if (!isNaN(d.getTime())) {
            dateStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM-dd');
          } else {
            dateStr = String(row[1]);
          }
        }
      } catch (e) {
        dateStr = String(row[1]);
      }

      return {
        id: row[0],
        date: dateStr,
        type: row[2],
        item: row[3],
        unitPrice: row[4],
        duration: row[5],
        amount: row[6],
        note: row[7],
        createdAt: row[8],
        month: row[9]
      };
    }).reverse();

  return { success: true, data: filtered };
}

/**
 * API: Save Report
 */
function apiSaveReport(reportData) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('ReportData');

  const id = Utilities.getUuid();
  const createdAt = new Date();
  const dateObj = new Date(reportData.date);
  const monthStr = Utilities.formatDate(dateObj, Session.getScriptTimeZone(), 'yyyy-MM');

  const row = [
    id,
    reportData.date,
    reportData.type,
    reportData.item,
    reportData.unitPrice,
    reportData.duration,
    reportData.amount,
    reportData.note,
    createdAt,
    monthStr
  ];

  sheet.appendRow(row);
  log(LOG_LEVEL.INFO, 'saveReport', 'Report saved', { id: id, type: reportData.type, item: reportData.item });

  return { success: true, message: 'Saved successfully', id: id };
}

/**
 * API: Delete data
 */
function apiDeleteData(id) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('ReportData');
  const data = sheet.getDataRange().getValues();

  for (let i = 1; i < data.length; i++) {
    if (data[i][0] === id) {
      sheet.deleteRow(i + 1);
      return { success: true };
    }
  }
  return { success: false, message: 'ID not found' };
}

/**
 * API: Update data
 */
function apiUpdateData(data) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('ReportData');
  const values = sheet.getDataRange().getValues();

  const id = data.id;
  if (!id) return { success: false, message: 'ID is required' };

  for (let i = 1; i < values.length; i++) {
    if (values[i][0] === id) {
      // Update fields
      // Columns: ID(0), Date(1), Type(2), Item(3), UnitPrice(4), Duration(5), Amount(6), Note(7), CreatedAt(8), Month(9)

      const dateObj = new Date(data.date);
      const monthStr = Utilities.formatDate(dateObj, Session.getScriptTimeZone(), 'yyyy-MM');

      // Update cells (row is i+1)
      const rowNum = i + 1;

      // We update everything except ID and CreatedAt(8)
      sheet.getRange(rowNum, 2).setValue(data.date);     // Date
      sheet.getRange(rowNum, 3).setValue(data.type);     // Type
      sheet.getRange(rowNum, 4).setValue(data.item);     // Item
      sheet.getRange(rowNum, 5).setValue(data.unitPrice);// UnitPrice
      sheet.getRange(rowNum, 6).setValue(data.duration); // Duration
      sheet.getRange(rowNum, 7).setValue(data.amount);   // Amount
      sheet.getRange(rowNum, 8).setValue(data.note);     // Note
      sheet.getRange(rowNum, 10).setValue(monthStr);     // Month

      log(LOG_LEVEL.INFO, 'updateReport', 'Report updated', { id: id });
      return { success: true, message: 'Updated successfully' };
    }
  }

  return { success: false, message: 'ID not found' };
}

/**
 * API: Verify PIN
 */
function verifyPin(inputPin) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('Settings');
  const data = sheet.getDataRange().getValues();

  let correctPin = '0000';
  for (let i = 1; i < data.length; i++) {
    if (data[i][0] === 'PIN_CODE') {
      correctPin = String(data[i][1]);
      break;
    }
  }

  if (String(inputPin) === correctPin) {
    return { success: true };
  } else {
    return { success: false, message: 'Invalid PIN' };
  }
}

/**
 * API: Generate PDF
 */
function apiGeneratePDF(monthStr, billingDate) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const reportSheet = ss.getSheetByName('ReportData');
  const templateSheet = ss.getSheetByName('InvoiceTemplate');

  // Settingsシートは必要に応じて使用（新しいセル指定には明確に含まれていませんが、他のプレースホルダで必要になる可能性があるため維持）
  // ただし、今回はユーザーの具体的なセル指定に従います。

  if (!monthStr) {
    const d = new Date();
    d.setMonth(d.getMonth() - 1);
    monthStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM');
  }

  const data = reportSheet.getDataRange().getValues();
  data.shift(); // ヘッダー削除

  // 月の値を yyyy-MM 形式に正規化するヘルパー関数
  function normalizeMonth(val) {
    if (!val) return '';

    // Dateオブジェクトの場合はスクリプトのタイムゾーンでフォーマット
    if (val instanceof Date) {
      return Utilities.formatDate(val, Session.getScriptTimeZone(), 'yyyy-MM');
    }

    const strVal = String(val).trim();

    // 既に yyyy-MM パターンに一致する場合は、タイムゾーンの問題を避けるためにそのまま返す
    if (/^\d{4}-\d{2}$/.test(strVal)) {
      return strVal;
    }

    // 必要に応じて他のフォーマットのパースを試みる
    if (strVal.includes('T') || strVal.includes('-') || strVal.includes('/')) {
      const d = new Date(strVal);
      if (!isNaN(d.getTime())) {
        return Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM');
      }
    }

    return strVal;
  }

  log(LOG_LEVEL.INFO, 'generatePDF', 'Filtering data', { targetMonth: monthStr, billingDate: billingDate, totalRows: data.length });

  const filteredData = data.filter(row => normalizeMonth(row[9]) === monthStr);

  if (filteredData.length === 0) {
    return { success: false, message: '対象月のデータがありません' };
  }

  // 一時シートの作成
  const tempSheet = templateSheet.copyTo(ss);
  tempSheet.setName('TempInvoice_' + new Date().getTime());

  try {
    // --- 集計ロジック ---
    let regularCount = 0;
    let extraMinutes = 0;
    let emergencyMinutes = 0;
    let expenseCount = 0;
    let expenseTotal = 0;

    for (const row of filteredData) {
      const type = row[2];      // タイプ: 'work', 'expense'
      const item = row[3];      // 項目名: '通常清掃', '追加業務', '緊急対応', etc.
      // row[5] は時間 (分)
      const duration = Number(row[5]) || 0;
      // row[6] は金額
      const amount = Number(row[6]) || 0;

      if (type === 'work') {
        if (item === '通常清掃') {
          regularCount++;
        } else if (item === '追加業務') {
          extraMinutes += duration;
        } else if (item === '緊急対応') {
          emergencyMinutes += duration;
        }
      } else if (type === 'expense') {
        expenseCount++;
        expenseTotal += amount;
      }
    }

    // --- 指定セルへの書き込み ---

    // N4: 請求日 (例: 2026年1月1日)
    let todayStr;
    if (billingDate) {
      // billingDateが渡された場合はそれを使用
      const d = new Date(billingDate);
      todayStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy年M月d日');
    } else {
      // 渡されない場合は今日
      todayStr = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy年M月d日');
    }

    tempSheet.getRange('N4').setValue(todayStr);

    // C9: 対象月 (例: 2025年12月分)
    // monthStr は 'yyyy-MM' なので 'yyyy年M月分' に変換
    const [y, m] = monthStr.split('-');
    const formattedMonth = `${y}年${Number(m)}月分`;
    tempSheet.getRange('C9').setValue(formattedMonth);

    // J20: 通常清掃回数 (例: 8)
    tempSheet.getRange('J20').setValue(regularCount);

    // J21: 追加業務 総合時間 (分単位)
    tempSheet.getRange('J21').setValue(extraMinutes);

    // J22: 緊急対応 総合時間 (分単位)
    tempSheet.getRange('J22').setValue(emergencyMinutes);

    // J23: 立替経費 総合数 (例: 2)
    tempSheet.getRange('J23').setValue(expenseCount);

    // O23: 立替経費 総合費用 (例: 1000)
    tempSheet.getRange('O23').setValue(expenseTotal);


    SpreadsheetApp.flush();

    // PDFエクスポート
    const url = ss.getUrl().replace(/edit$/, '') + 'export?exportFormat=pdf&format=pdf' +
      '&size=A4&portrait=true&fitw=true&gridlines=false&printtitle=false' +
      '&sheetnames=false&rownumbers=false' +
      '&gid=' + tempSheet.getSheetId();

    const token = ScriptApp.getOAuthToken();
    const response = UrlFetchApp.fetch(url, {
      headers: { 'Authorization': 'Bearer ' + token }
    });

    const blob = response.getBlob().setName(`請求書_${monthStr}.pdf`);
    const dataUrl = 'data:application/pdf;base64,' + Utilities.base64Encode(blob.getBytes());

    return { success: true, data: dataUrl, filename: `請求書_${monthStr}.pdf` };

  } catch (e) {
    return { success: false, message: e.toString() };
  } finally {
    // クリーンアップ
    ss.deleteSheet(tempSheet);
  }
}
