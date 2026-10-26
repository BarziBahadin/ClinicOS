export class UnsafeImageError extends Error {}
export const processingNote = "Preview: auto-oriented, resized within 1600 × 1600 pixels, PNG; metadata removed. Original bytes preserved.";
export async function imagePreview(bytes: Uint8Array): Promise<Uint8Array<ArrayBuffer>> {
  const url=Deno.env.get("MEDIA_PROCESSOR_URL"),token=Deno.env.get("MEDIA_PROCESSOR_TOKEN");
  if(!url||!token)throw new Error("Image previews are unavailable until the private processor is configured. Retry this upload later.");
  const response=await fetch(new URL("/preview",url),{method:"POST",headers:{Authorization:`Bearer ${token}`,"Content-Type":"application/octet-stream"},body:bytes as BodyInit,signal:AbortSignal.timeout(20000)});
  if(response.status===422)throw new UnsafeImageError("The image could not be safely decoded. Choose a valid static JPEG, PNG or WebP image.");
  if(!response.ok)throw new Error("The private image processor is unavailable or busy. Retry this upload.");
  if(response.headers.get("Content-Type")!=="image/png")throw new Error("Image processor returned an invalid preview.");
  const preview=new Uint8Array(await response.arrayBuffer());
  if(preview.length===0||preview.length>10485760)throw new Error("Image preview exceeds the supported size.");
  return preview;
}
