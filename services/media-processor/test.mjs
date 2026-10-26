import test from 'node:test';import assert from 'node:assert/strict';import sharp from 'sharp';import {makePreview} from './preview.mjs';
test('preview strips metadata, fits the preview bounds and preserves source bytes',async()=>{
 const original=await sharp({create:{width:2000,height:1000,channels:3,background:'#a45c39'}}).jpeg().withMetadata({exif:{IFD0:{Artist:'Synthetic private metadata'}}}).toBuffer();
 const before=Buffer.from(original);const sourceMetadata=await sharp(original).metadata();assert.ok(sourceMetadata.exif);
 const output=await makePreview(original);const metadata=await sharp(output.data).metadata();
 assert.equal(output.width,1600);assert.equal(output.height,800);assert.equal(metadata.format,'png');assert.equal(metadata.exif,undefined);assert.equal(metadata.xmp,undefined);assert.deepEqual(original,before);
});
test('malformed files and executable content cannot become previews',async()=>{
 await assert.rejects(makePreview(Buffer.from('not an image')));
 await assert.rejects(makePreview(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1"/></svg>')));
});
