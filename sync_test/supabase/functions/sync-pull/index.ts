// deno.json: { "imports": { "@supabase/supabase-js": "https://esm.sh/@supabase/supabase-js@2" } }
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "@supabase/supabase-js";

type PullReq = {
  table: 'products' | 'sales';
  company_id: string;
  location_id: string;
  since: string; // ISO string
  use_gt?: boolean; // if true use strict greater-than
  from?: number; // offset
  limit?: number; // page size
  days?: number; // only for sales (txn_date window)
};

serve(async (req) => {
  try {
    const body = (await req.json()) as PullReq;
    const url = Deno.env.get('SUPABASE_URL')!;
    const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(url, serviceRole);

    const from = body.from ?? 0;
    const limit = body.limit ?? 1000;
    const useGt = body.use_gt ?? false;
    const since = body.since;

    let q = supabase.from(body.table).select('*')
      .eq('company_id', body.company_id);

    if (body.table === 'products') {
      q = q.or(`location_id.is.null,location_id.eq.${body.location_id}`);
    } else {
      // sales
      q = q.eq('location_id', body.location_id);
      const days = body.days ?? 30;
      const txnSince = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
      q = q.gte('txn_date', txnSince);
    }

    q = useGt ? q.gt('updated_at', since) : q.gte('updated_at', since);
    q = q.order('updated_at', { ascending: true }).range(from, from + limit - 1);

    const { data, error } = await q;
    if (error) throw error;
    return new Response(JSON.stringify(data ?? []), { status: 200, headers: { 'Content-Type': 'application/json' } });
  } catch (e) {
    console.error('sync-pull error', e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400 });
  }
});

