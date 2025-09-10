// deno.json: { "imports": { "@supabase/supabase-js": "https://esm.sh/@supabase/supabase-js@2" } }
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "@supabase/supabase-js";

type Item = { id: string; table: 'products'|'sales'; op: 'upsert'|'delete'; row: Record<string, unknown> };

serve(async (req) => {
  try {
    const { items, company_id, location_id } = await req.json();
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!; // Use JWT from client to keep RLS in force
    const supabase = createClient(url, anon, { global: { headers: { Authorization: req.headers.get('Authorization')! } } });

    for (const it of items as Item[]) {
      const row = it.row as Record<string, unknown>;
      if (row['company_id'] !== company_id) continue;
      if (row['location_id'] && row['location_id'] !== location_id) continue;

      if (it.op === 'upsert') {
        const { error } = await supabase.from(it.table).upsert(row, { onConflict: 'id' });
        if (error) throw error;
      } else if (it.op === 'delete') {
        const { error } = await supabase.from(it.table).update({ deleted: true }).eq('id', row['id']);
        if (error) throw error;
      }
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400 });
  }
});