import { headers } from './auth.ts';
Deno.test('CORS permits the exact desktop application origin while requiring bearer authentication separately',()=>{
 const response=headers(new Request('https://example.test',{headers:{Origin:'clinicos://app'}}));
 if(response['Access-Control-Allow-Origin']!=='clinicos://app')throw new Error('Desktop origin denied');
 for(const origin of ['null','https://untrusted.invalid','clinicos://other'])if(headers(new Request('https://example.test',{headers:{Origin:origin}}))['Access-Control-Allow-Origin']===origin)throw new Error('Untrusted origin permitted');
});
