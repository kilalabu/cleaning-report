// Supabase Edge Function: generate-pdf
// 認証付きPDF生成プロキシ（GASをバックエンドとして使用）
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// GAS Endpoint (環境変数から取得、フォールバックは直接指定)
const GAS_ENDPOINT = Deno.env.get("GAS_ENDPOINT") ||
  "https://script.google.com/macros/s/AKfycbyQ9AazjlpRyc4zAiHuXLudYN5Fa5Vwnwe96n2NvRat3lrqcVY4sKcoJ5yqtr4OEF0mUA/exec";

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
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization") ?? "" },
        },
      },
    );

    const { data: { user }, error: authError } = await supabaseClient.auth
      .getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, message: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // リクエストボディをパース
    const { month, billingDate } = await req.json();

    if (!month) {
      return new Response(
        JSON.stringify({ success: false, message: "month is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    console.log(`Generating PDF for month: ${month}, user: ${user.email}`);

    // GAS API を呼び出し
    const gasUrl = new URL(GAS_ENDPOINT);
    gasUrl.searchParams.set("action", "generatePDF");
    gasUrl.searchParams.set("month", month);
    if (billingDate) {
      gasUrl.searchParams.set("billingDate", billingDate);
    }

    const gasResponse = await fetch(gasUrl.toString(), {
      method: "GET",
    });

    if (!gasResponse.ok) {
      console.error(`GAS error: ${gasResponse.status}`);
      return new Response(
        JSON.stringify({
          success: false,
          message: `GAS API error: ${gasResponse.status}`,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const gasResult = await gasResponse.json();

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
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
