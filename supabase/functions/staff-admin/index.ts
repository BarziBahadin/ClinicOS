import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { authenticated, headers, json } from '../_shared/auth.ts';
import { normalizeUsername, usernameIdentity } from '../_shared/username.ts';
function password(value: unknown): string {
  if (typeof value !== 'string' || value.length < 16 || value.length > 128) throw new Error('Use a password of 16–128 characters.');
  return value;
}
async function fingerprint(value: unknown) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return Array.from(new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(JSON.stringify(value))))).map(n => n.toString(16).padStart(2, '0')).join('');
}
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: headers(req) });
  if (req.method !== 'POST') return json(req, { error: 'Method not allowed' }, 405);
  try {
    if (!req.body) throw new Error('Invalid account request');
    const reader = req.body.getReader(); const chunks: Uint8Array[] = []; let length = 0;
    while (true) { const part = await reader.read(); if (part.done) break; length += part.value.byteLength; if (length > 8192) { await reader.cancel(); throw new Error('Account request is too large'); } chunks.push(part.value); }
    const bytes = new Uint8Array(length); let offset = 0; for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    const body = JSON.parse(new TextDecoder().decode(bytes));
    if (!['create', 'reset_password', 'change_password'].includes(body.action)) throw new Error('Invalid account request');
    const { user, userClient, admin } = await authenticated(req, body.action === 'change_password' ? 'password.change' : 'staff');
    const { data: workspace, error: workspaceError } = await userClient.rpc('workspace');
    if (workspaceError) throw new Error(workspaceError.message);
    const org = workspace.organization.id;
    const nextPassword = password(body.password);
    if (body.action === 'create') {
      const username = normalizeUsername(body.username);
      const name = typeof body.display_name === 'string' ? body.display_name.trim() : '';
      if (name.length < 2 || name.length > 160 || !['doctor', 'receptionist', 'administrator', 'accountant'].includes(body.role) || !/^[a-f0-9-]{36}$/.test(body.request_id)) throw new Error('Invalid account details');
      if (workspace.membership.role !== 'owner' && ['administrator','accountant'].includes(body.role)) throw new Error('Only the owner can create privileged business accounts.');
      const content = await fingerprint([username, name, body.role, nextPassword]);
      const lookup = await admin.rpc('staff_creation_lookup', { login_name: username, operation_id: body.request_id, actor_id: user.id, content_fingerprint: content });
      if (lookup.error) throw new Error('Account creation could not be checked.');
      let memberId = lookup.data;
      if (!memberId) {
        const created = await admin.auth.admin.createUser({ email: usernameIdentity(username), password: nextPassword, email_confirm: true, app_metadata: { creation_request_id: body.request_id, creation_actor_id: user.id, creation_fingerprint: content } });
        if (created.error) throw new Error('This username is unavailable or the account could not be created.');
        memberId = created.data.user.id;
      }
      const provisioned = await admin.rpc('staff_provision', { org_id: org, member_id: memberId, member_name: name, member_role: body.role, member_username: username });
      if (provisioned.error) throw new Error('Account setup is incomplete. Retry the same request.');
      return json(req, { id: memberId, username });
    }
    if (body.action === 'reset_password') {
      const target = await userClient.rpc('staff_target', { member_id: body.user_id });
      if (target.error || !target.data?.username) throw new Error('This account cannot be reset by your role.');
      const locked = await admin.rpc('staff_password_state', { org_id: org, member_id: body.user_id, action: 'reset' });
      if (locked.error) throw new Error('Password reset could not be started.');
      const updated = await admin.auth.admin.updateUserById(body.user_id, { password: nextPassword });
      if (updated.error) throw new Error('Password reset is incomplete. Retry with a new temporary password.');
      return json(req, { id: body.user_id });
    }
    if (typeof body.current_password !== 'string' || body.current_password === nextPassword) throw new Error('Enter your current password and a different new password.');
    const verifier = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { auth: { persistSession: false, autoRefreshToken: false } });
    const checked = await verifier.auth.signInWithPassword({ email: user.email!, password: body.current_password });
    if (checked.error) throw new Error('Current password is incorrect.');
    await verifier.auth.signOut({ scope: 'local' });
    const updated = await admin.auth.admin.updateUserById(user.id, { password: nextPassword });
    if (updated.error) throw new Error('Password could not be changed.');
    const completed = await admin.rpc('staff_password_state', { org_id: org, member_id: user.id, action: 'complete' });
    if (completed.error) throw new Error('Password was changed. Sign in again and contact the administrator.');
    return json(req, { id: user.id });
  } catch (e) { return json(req, { error: e instanceof Error ? e.message : 'Account operation failed' }, 400); }
});
