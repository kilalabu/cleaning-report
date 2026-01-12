/**
 * GAS API Backend for Cleaning Report System
 * PDF生成専用（データはSupabaseで管理）
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
 * Handle GET requests - Health check only
 */
function doGet(e) {
  const action = e.parameter.action || 'ping';
  const callback = e.parameter.callback;

  let result;

  switch (action) {
    case 'ping':
      result = { success: true, message: 'API is running', timestamp: new Date().toISOString() };
      break;

    default:
      result = { success: false, message: 'Unknown action: ' + action };
  }

  return createJsonResponse(result, callback);
}

/**
 * Handle POST requests - PDF generation
 */
function doPost(e) {
  const callback = e.parameter.callback;
  let result;
  let action = 'unknown';

  try {
    const payload = JSON.parse(e.postData.contents);
    action = payload.action || '';

    switch (action) {
      case 'generatePDFFromData':
        // Supabaseから渡されたデータでPDF生成
        result = apiGeneratePDFFromData(payload.data, payload.monthStr, payload.billingDate);
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
 * Initial Setup: Creates Invoice Template sheet if it doesn't exist
 * Run this function once manually.
 */
function initialSetup() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // Setup Invoice Template
  let templateSheet = ss.getSheetByName('InvoiceTemplate');
  if (!templateSheet) {
    templateSheet = ss.insertSheet('InvoiceTemplate');
  }
}

/**
 * API: Generate PDF from external data (Supabase経由)
 * @param {Array} reportData - レポートデータの配列 [{type, item, duration, amount}, ...]
 * @param {string} monthStr - 対象月 (yyyy-MM形式)
 * @param {string} billingDate - 請求日 (yyyy-MM-dd形式)
 */
function apiGeneratePDFFromData(reportData, monthStr, billingDate) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const templateSheet = ss.getSheetByName('InvoiceTemplate');

  if (!reportData || reportData.length === 0) {
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

    for (const row of reportData) {
      const type = row.type;      // 'work' or 'expense'
      const item = row.item;      // '通常清掃', '追加業務', '緊急対応', etc.
      const duration = Number(row.duration) || 0;
      const amount = Number(row.amount) || 0;

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

    // N4: 請求日
    let todayStr;
    if (billingDate) {
      const d = new Date(billingDate);
      todayStr = Utilities.formatDate(d, Session.getScriptTimeZone(), 'yyyy年M月d日');
    } else {
      todayStr = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy年M月d日');
    }
    tempSheet.getRange('N4').setValue(todayStr);

    // C9: 対象月
    const [y, m] = monthStr.split('-');
    const formattedMonth = `${y}年${Number(m)}月分`;
    tempSheet.getRange('C9').setValue(formattedMonth);

    // J20: 通常清掃回数
    tempSheet.getRange('J20').setValue(regularCount);

    // J21: 追加業務 総合時間 (分単位)
    tempSheet.getRange('J21').setValue(extraMinutes);

    // J22: 緊急対応 総合時間 (分単位)
    tempSheet.getRange('J22').setValue(emergencyMinutes);

    // J23: 立替経費 総合数
    tempSheet.getRange('J23').setValue(expenseCount);

    // O23: 立替経費 総合費用
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

    log(LOG_LEVEL.INFO, 'generatePDFFromData', 'PDF generated', {
      month: monthStr,
      regularCount: regularCount,
      extraMinutes: extraMinutes,
      emergencyMinutes: emergencyMinutes,
      expenseCount: expenseCount,
      expenseTotal: expenseTotal
    });

    return { success: true, data: dataUrl, filename: `請求書_${monthStr}.pdf` };

  } catch (e) {
    log(LOG_LEVEL.ERROR, 'generatePDFFromData', e.message, { stack: e.stack });
    return { success: false, message: e.toString() };
  } finally {
    // クリーンアップ
    ss.deleteSheet(tempSheet);
  }
}
