import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
const allowedOrigin=Deno.env.get('APP_ORIGIN')??'http://127.0.0.1:5173';
const desktopOrigin='clinicos://app';
export function headers(req:Request){const origin=req.headers.get('origin');return {'Content-Type':'application/json','Access-Control-Allow-Origin':origin===allowedOrigin||origin===desktopOrigin?origin:allowedOrigin,'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'};}
export function json(req:Request,body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:headers(req)});}
export async function authenticated(req:Request,permission:string){
 const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!,secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
 const auth=req.headers.get('Authorization');if(!auth?.startsWith('Bearer '))throw new Error('Authentication required');
 const userClient=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
 const {data:{user},error}=await userClient.auth.getUser(auth.slice(7));if(error||!user)throw new Error('Authentication required');
 if(permission==='password.change'){
 const {error:statusError}=await userClient.rpc('account_status');if(statusError)throw new Error('Sign in again before changing your password.');
 const claims=JSON.parse(atob(auth.slice(7).split('.')[1].replaceAll('-','+').replaceAll('_','/')));
 if(user.factors?.some(f=>f.status==='verified')&&claims.aal!=='aal2')throw new Error('Verify your authenticator before changing your password.');
 }else{
 const {data:allowed,error:permissionError}=await userClient.rpc('authorize',{permission});if(permissionError||!allowed)throw new Error('Permission denied or MFA required');
 }
 const admin=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
 return {user,userClient,admin};
}
