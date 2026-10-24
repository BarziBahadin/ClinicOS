import { authenticated,headers,json } from '../_shared/auth.ts';
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{headers:headers(req)});
 if(req.method!=='POST')return json(req,{error:'Method not allowed'},405);
 try{
  const {userClient,admin}=await authenticated(req,'staff');const body=await req.json();
  if(body.action!=='invite'||typeof body.email!=='string'||!/^\S+@\S+\.\S+$/.test(body.email)||typeof body.display_name!=='string'||body.display_name.trim().length<2||!['doctor','receptionist','administrator','accountant'].includes(body.role))return json(req,{error:'Invalid invitation'},400);
  const {data:workspace,error}=await userClient.rpc('workspace');if(error)throw new Error(error.message);
  const {data:invitation,error:inviteError}=await admin.auth.admin.inviteUserByEmail(body.email,{redirectTo:(Deno.env.get('APP_ORIGIN')??'http://127.0.0.1:5173')+'/?onboarding=1'});if(inviteError)throw new Error(inviteError.message);
  const {error:provisionError}=await admin.rpc('provision_member',{org_id:workspace.organization.id,member_id:invitation.user.id,member_name:body.display_name.trim(),member_role:body.role});
  if(provisionError){await admin.auth.admin.deleteUser(invitation.user.id);throw new Error('Invitation could not be provisioned. Retry after checking account status.');}
  return json(req,{id:invitation.user.id});
 }catch(e){return json(req,{error:e instanceof Error?e.message:'Unable to invite staff'},403);}
});
