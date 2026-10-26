import { imagePreview, processingNote, UnsafeImageError } from '../_shared/preview.ts';
import { authenticated,headers,json } from '../_shared/auth.ts';
import { imageSize } from 'npm:image-size@2.0.2';
class InfectedFileError extends Error {}
async function scan(bytes:Uint8Array){
 const hostname=Deno.env.get('CLAMAV_HOST');if(!hostname)throw new Error('Malware scanning is not configured. Uploads remain unavailable until the scanner is connected.');
 const conn=await Deno.connect({hostname,port:Number(Deno.env.get('CLAMAV_PORT')??3310)});
 const timeout=setTimeout(()=>{try{conn.close();}catch{}},20000);
 try{
 const writeAll=async(b:Uint8Array)=>{let offset=0;while(offset<b.length)offset+=await conn.write(b.subarray(offset));};
 await writeAll(new TextEncoder().encode('zINSTREAM\0'));
 for(let i=0;i<bytes.length;i+=65536){const chunk=bytes.subarray(i,i+65536);const size=new Uint8Array(4);new DataView(size.buffer).setUint32(0,chunk.length);await writeAll(size);await writeAll(chunk);}
 await writeAll(new Uint8Array(4));const buffer=new Uint8Array(2048);let received=0;
 while(received<buffer.length){const n=await conn.read(buffer.subarray(received));if(n===null)break;received+=n;if(buffer.subarray(0,received).includes(0))break;}
 const result=new TextDecoder().decode(buffer.subarray(0,received)).replaceAll('\0','').trim();
 if(result.includes('FOUND'))throw new InfectedFileError('File rejected by malware scanner');
 if(result!=='stream: OK')throw new Error('Malware scanner unavailable; retry the upload');
 }finally{clearTimeout(timeout);try{conn.close();}catch{}}
}
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{headers:headers(req)});
 if(req.method!=='POST')return json(req,{error:'Method not allowed'},405);
 try{
 const {userClient,admin}=await authenticated(req,'media');
 if(req.headers.get('content-type')?.includes('application/json')){
  const body=await req.json();if(!['read','preview','regenerate_preview'].includes(body.action))throw new Error('Invalid media action');
  const {data:key,error}=await userClient.rpc(body.action==='preview'?'media_access_variant':'media_access',body.action==='preview'?{media_id:body.media_id,original:false}:{media_id:body.media_id});if(error)throw new Error(error.message);
  if(body.action==='regenerate_preview'){const downloaded=await admin.storage.from('clinical').download(key);if(downloaded.error)throw new Error('Original image unavailable');const original=new Uint8Array(await downloaded.data.arrayBuffer());await scan(original);const preview=await imagePreview(original);await scan(preview);const previewHash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',preview))).map(x=>x.toString(16).padStart(2,'0')).join('');const previewKey=key+'.preview-'+previewHash+'.png';const uploaded=await admin.storage.from('clinical').upload(previewKey,preview,{contentType:'image/png',upsert:false});if(uploaded.error&&!uploaded.error.message.toLowerCase().includes('already exists'))throw new Error('Preview could not be stored');const attached=await admin.rpc('media_preview_attach',{media_id:body.media_id,preview_path:previewKey,preview_hash:previewHash,note:processingNote});if(attached.error)throw new Error(attached.error.message);return json(req,{id:body.media_id});}
  const {data,error:signError}=await admin.storage.from('clinical').createSignedUrl(key,60);if(signError)throw new Error(signError.message);const publicUrl=Deno.env.get('PUBLIC_SUPABASE_URL');const signedUrl=publicUrl?data.signedUrl.replace(new URL(data.signedUrl).origin,publicUrl):data.signedUrl;return json(req,{url:signedUrl,...(body.action==='preview'&&key.includes('.preview-')?{mime_type:'image/png'}:{})});
 }
 const length=Number(req.headers.get('content-length')??0);if(length>11000000)return json(req,{error:'Maximum file size is 10 MB'},413);
 if(!req.body)throw new Error('Choose a file');
 const reader=req.body.getReader();const chunks:Uint8Array[]=[];let received=0;
 while(true){const chunk=await reader.read();if(chunk.done)break;received+=chunk.value.byteLength;if(received>11000000){await reader.cancel();return json(req,{error:'Maximum file size is 10 MB'},413);}chunks.push(chunk.value);}
 const bounded=new Uint8Array(received);let offset=0;for(const chunk of chunks){bounded.set(chunk,offset);offset+=chunk.byteLength;}
 const form=await new Response(bounded,{headers:{'Content-Type':req.headers.get('content-type')??''}}).formData();const file=form.get('file');if(!(file instanceof File)||file.size===0||file.size>10485760)throw new Error('Choose a file up to 10 MB');
 const bytes=new Uint8Array(await file.arrayBuffer());let mime='';
 if(bytes[0]===0xff&&bytes[1]===0xd8&&bytes[2]===0xff)mime='image/jpeg';
 else if([137,80,78,71,13,10,26,10].every((n,i)=>bytes[i]===n))mime='image/png';
 else if(new TextDecoder().decode(bytes.subarray(0,4))==='RIFF'&&new TextDecoder().decode(bytes.subarray(8,12))==='WEBP')mime='image/webp';
 else if(new TextDecoder().decode(bytes.subarray(0,5))==='%PDF-')mime='application/pdf';
 if(!mime||mime!==file.type)throw new Error('File content and declared type do not match');
 if(mime.startsWith('image/')){const size=imageSize(bytes);if(!size.width||!size.height||size.width*size.height>40000000)throw new Error('Image dimensions exceed the supported limit');}
 const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(x=>x.toString(16).padStart(2,'0')).join('');
 const {data:prepared,error}=await userClient.rpc('media_prepare',{media_id:form.get('upload_id'),patient_id:form.get('patient_id'),consent_id:form.get('consent_id'),title:form.get('title'),body_site:form.get('body_site'),mime_type:mime,content_hash:hash});if(error)throw new Error(error.message);
 if(prepared.status==='ready')return json(req,{id:prepared.id});
 if(prepared.status==='rejected')throw new Error('This upload was rejected; choose a new file');
 try{await scan(bytes);}catch(e){if(e instanceof InfectedFileError){const {error:rejectError}=await admin.rpc('media_finalize',{media_id:prepared.id,approved:false});if(rejectError)throw new Error('Rejected file could not be recorded; contact the administrator');}throw e;}
 let preview:Uint8Array<ArrayBuffer>|undefined;let previewHash:string|null=null;let previewKey:string|null=null;
 if(mime.startsWith('image/')){try{preview=await imagePreview(bytes);await scan(preview);}catch(e){if(e instanceof UnsafeImageError){const rejected=await admin.rpc('media_finalize',{media_id:prepared.id,approved:false});if(rejected.error)throw new Error('Invalid image status could not be recorded');}throw e;}previewHash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',preview))).map(x=>x.toString(16).padStart(2,'0')).join('');previewKey=prepared.key+'.preview-'+previewHash+'.png';}
 const {error:uploadError}=await admin.storage.from('clinical').upload(prepared.key,bytes,{contentType:mime,upsert:false});if(uploadError&&!uploadError.message.toLowerCase().includes('already exists'))throw new Error(uploadError.message);
 if(preview&&previewKey){const uploaded=await admin.storage.from('clinical').upload(previewKey,preview,{contentType:'image/png',upsert:false});if(uploaded.error&&!uploaded.error.message.toLowerCase().includes('already exists'))throw new Error('Preview could not be stored. Retry the upload.');}
 const {error:finalizeError}=await admin.rpc('media_complete',{media_id:prepared.id,preview_path:previewKey,preview_hash:previewHash,note:preview?processingNote:'Original scanned PDF'});if(finalizeError)throw new Error(finalizeError.message);
 return json(req,{id:prepared.id});
 }catch(e){return json(req,{error:e instanceof Error?e.message:'File operation failed'},400);}
});
