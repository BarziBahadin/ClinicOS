import http from 'node:http';
import {timingSafeEqual} from 'node:crypto';
import {makePreview} from './preview.mjs';
const secret=process.env.MEDIA_PROCESSOR_TOKEN;
if(!secret||secret.length<32)throw new Error('A protected media processor token is required');
let busy=false;
http.createServer(async(req,res)=>{
  res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');
  if(req.method==='GET'&&req.url==='/health'){res.writeHead(200,{'Content-Type':'application/json'});res.end('{"healthy":true}');return;}
  const supplied=Buffer.from(String(req.headers.authorization??''));const expected=Buffer.from('Bearer '+secret);
  if(supplied.length!==expected.length||!timingSafeEqual(supplied,expected)){res.writeHead(401);res.end();return;}
  if(req.method!=='POST'||req.url!=='/preview'){res.writeHead(405);res.end();return;}
  if(busy){res.writeHead(503);res.end('Processor busy; retry the upload');return;}
  busy=true;
  try{
    const chunks=[];let size=0;
    for await(const chunk of req){size+=chunk.length;if(size>10_485_760)throw new Error('File too large');chunks.push(chunk);}
    const preview=await makePreview(Buffer.concat(chunks));
    res.writeHead(200,{'Content-Type':'image/png','X-Preview-Width':String(preview.width),'X-Preview-Height':String(preview.height)});res.end(preview.data);
  }catch{res.writeHead(422);res.end('Image could not be safely decoded; choose a valid static JPEG, PNG or WebP image.');}
  finally{busy=false;}
}).listen(8080,'0.0.0.0');
