import sharp from 'sharp';
sharp.cache(false);
sharp.concurrency(1);
export async function makePreview(bytes) {
  const input=sharp(bytes,{limitInputPixels:40_000_000,failOn:'error',animated:false});
  const metadata=await input.metadata();
  if(!['jpeg','png','webp'].includes(metadata.format)||!metadata.width||!metadata.height||(metadata.pages??1)>1)throw new Error('Unsupported static clinical image');
  // Sharp strips metadata by default. Preserve the separate original unchanged.
  const {data,info}=await input.rotate().resize({width:1600,height:1600,fit:'inside',withoutEnlargement:true}).png({compressionLevel:6}).timeout({seconds:15}).toBuffer({resolveWithObject:true});
  return {data,width:info.width,height:info.height};
}
