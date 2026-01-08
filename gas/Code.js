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
        result = apiGeneratePDF(pdfMonth);
        break;

      case 'saveReport':
        const dataParam = e.parameter.data || '{}';
        const reportData = JSON.parse(dataParam);
        result = apiSaveReport(reportData);
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
    settingsSheet.appendRow(['REPORTER_NAME', '田中 太郎']);
    settingsSheet.appendRow(['CLIENT_NAME', '桑原 宏和']);
    settingsSheet.setFrozenRows(1);
  }

  // 3. Setup Invoice Template
  let templateSheet = ss.getSheetByName('InvoiceTemplate');
  if (!templateSheet) {
    templateSheet = ss.insertSheet('InvoiceTemplate');
    templateSheet.getRange('A1').setValue('請求書');
    templateSheet.getRange('A1').setFontSize(24).setFontWeight('bold');
    templateSheet.getRange('A3').setValue('宛名: {{CLIENT_NAME}} 様');
    templateSheet.getRange('A4').setValue('案件: {{MONTH}}分 清掃業務委託費');

    templateSheet.getRange('E1').setValue('請求日: {{DATE}}');
    templateSheet.getRange('E2').setValue('請求者: {{REPORTER_NAME}}');

    templateSheet.getRange('A6:E6').setValues([['日付', '内容', '単価', '数量/時間', '金額']]);
    templateSheet.getRange('A6:E6').setBackground('#eee').setFontWeight('bold');

    templateSheet.getRange('D20').setValue('合計請求金額');
    templateSheet.getRange('E20').setValue('{{TOTAL_AMOUNT}}');
    templateSheet.getRange('E20').setFontWeight('bold');

    templateSheet.getRange('A22').setValue('備考: 追加時給は15分単位で計上しています。');
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
function apiGeneratePDF(monthStr) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const reportSheet = ss.getSheetByName('ReportData');
  const templateSheet = ss.getSheetByName('InvoiceTemplate');
  const settingsSheet = ss.getSheetByName('Settings');

  if (!monthStr) {
    const d = new Date();
    d.setMonth(d.getMonth() - 1);
    monthStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy-MM');
  }

  const settings = {};
  settingsSheet.getDataRange().getValues().forEach(row => {
    if (row[0]) settings[row[0]] = row[1];
  });

  const data = reportSheet.getDataRange().getValues();
  data.shift();
  const filteredData = data.filter(row => row[9] === monthStr);

  if (filteredData.length === 0) {
    return { success: false, message: '対象月のデータがありません' };
  }

  const tempSheet = templateSheet.copyTo(ss);
  tempSheet.setName('TempInvoice_' + new Date().getTime());

  try {
    const totalAmount = filteredData.reduce((sum, row) => sum + Number(row[6]), 0);

    tempSheet.replaceText('{{CLIENT_NAME}}', settings['CLIENT_NAME'] || '');
    tempSheet.replaceText('{{REPORTER_NAME}}', settings['REPORTER_NAME'] || '');
    tempSheet.replaceText('{{MONTH}}', monthStr.replace('-', '年') + '月');
    tempSheet.replaceText('{{DATE}}', Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy/MM/dd'));
    tempSheet.replaceText('{{TOTAL_AMOUNT}}', '¥' + totalAmount.toLocaleString());

    const startRow = 7;
    if (filteredData.length > 0) {
      tempSheet.insertRows(startRow, filteredData.length);
      const rowsToInsert = filteredData.map(row => {
        let durationStr = '';
        if (row[2] !== 'work' || row[3] === '通常清掃') {
          durationStr = row[2] === 'expense' ? '1' : '1回';
        } else {
          const min = Number(row[5]);
          durationStr = Math.floor(min / 60) + '時間' + (min % 60) + '分';
        }

        let dateStr = '';
        try {
          if (row[1] instanceof Date) {
            dateStr = Utilities.formatDate(row[1], Session.getScriptTimeZone(), 'yyyy-MM-dd');
          } else {
            dateStr = String(row[1]);
          }
        } catch (e) {
          dateStr = String(row[1]);
        }

        return [
          dateStr,
          row[3] + (row[7] ? ` (${row[7]})` : ''),
          '¥' + Number(row[4]).toLocaleString(),
          durationStr,
          '¥' + Number(row[6]).toLocaleString()
        ];
      });

      tempSheet.getRange(startRow, 1, filteredData.length, 5).setValues(rowsToInsert);
    }

    SpreadsheetApp.flush();

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
    ss.deleteSheet(tempSheet);
  }
}
