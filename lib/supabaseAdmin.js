import { createClient } from '@supabase/supabase-js';
const {SUPABASE_URL,SUPABASE_SERVICE_KEY}=process.env;
if(!SUPABASE_URL||!SUPABASE_SERVICE_KEY) throw new Error('Missing SUPABASE env');
export const supabaseAdmin=createClient(SUPABASE_URL,SUPABASE_SERVICE_KEY,{auth:{persistSession:false}});
