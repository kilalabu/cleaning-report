// Supabase Edge Function: generate-pdf
// Supabaseからデータ取得 → GASでPDF生成
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// GAS Endpoint（新しいデプロイURL）
const GAS_ENDPOINT = Deno.env.get("GAS_ENDPOINT") ||
  "https://script.google.com/macros/s/AKfycbz19qnYN0GoGO5OjhbxrWvbsKA4HXXNeevDOr4rStdE9HJM_PCwCSj7iQ-NM990h-rCDw/exec";

// CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 認証チェック
    const authHeader = req.headers.get("Authorization");
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader ?? "" },
        },
      },
    );

    const { data: { user }, error: authError } = await supabaseClient.auth
      .getUser();

    if (authError || !user) {
      console.error("Auth error:", authError);
      return new Response(
        JSON.stringify({ success: false, message: "Unauthorized" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // リクエストボディをパース
    const { month, billingDate } = await req.json();

    if (!month) {
      return new Response(
        JSON.stringify({ success: false, message: "month is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    console.log(
      `Generating PDF for month: ${month}, billingDate: ${billingDate}, user: ${user.email}`,
    );

    // Supabaseからレポートデータを取得
    const { data: reports, error: dbError } = await supabaseClient
      .from("reports")
      .select("type, item, duration, amount")
      .eq("month", month);

    if (dbError) {
      console.error("Database error:", dbError);
      return new Response(
        JSON.stringify({
          success: false,
          message: `データ取得エラー: ${dbError.message}`,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!reports || reports.length === 0) {
      return new Response(
        JSON.stringify({ success: false, message: "対象月のデータがありません" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    console.log(`Found ${reports.length} reports for month ${month}`);

    // GAS API を POST で呼び出し（データを渡す）
    const gasResponse = await fetch(GAS_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        action: "generatePDFFromData",
        data: reports,
        monthStr: month,
        billingDate: billingDate,
      }),
    });

    if (!gasResponse.ok) {
      console.error(`GAS error: ${gasResponse.status}`);
      return new Response(
        JSON.stringify({
          success: false,
          message: `GAS API error: ${gasResponse.status}`,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const gasResult = await gasResponse.json();
    console.log("GAS result success:", gasResult.success);

    // GASからのレスポンスをそのまま返す
    return new Response(JSON.stringify(gasResult), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        message: error instanceof Error ? error.message : "Unknown error",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
