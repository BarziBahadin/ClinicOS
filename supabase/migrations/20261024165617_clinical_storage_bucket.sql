-- Clinical objects must never be public. Access is mediated by trusted functions.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('clinical','clinical',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf']) on conflict(id) do nothing;
