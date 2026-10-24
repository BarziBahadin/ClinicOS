import { useEffect,useState } from 'react';
import { client } from '../lib/supabase';
import type { Row } from '../domain/types';
import { ErrorMessage,type T } from './ui';
export function useRecordPage(type:'invoices'|'payments'|'expenses'|'audit',refreshKey:unknown){
 const [query,setQuery]=useState(''),[cursors,setCursors]=useState<(string|null)[]>([null]),[items,setItems]=useState<Row[]>([]),[more,setMore]=useState(false),[error,setError]=useState(''),[loading,setLoading]=useState(true);
 const cursor=cursors.at(-1);
 useEffect(()=>{let cancelled=false;setLoading(true);const timer=setTimeout(()=>{void client().rpc('record_page',{record_type:type,search_term:query,cursor_id:cursor,page_size:50}).then(({data,error})=>{if(cancelled)return;if(error){setError(error.message);}else{setItems(data.items);setMore(data.has_more);setError('');}setLoading(false);});},150);return()=>{cancelled=true;clearTimeout(timer);};},[type,query,cursor,refreshKey]);
 return {items,more,error,loading,query,setQuery:(value:string)=>{setQuery(value);setCursors([null]);},previous:()=>setCursors(c=>c.slice(0,-1)),next:()=>{const last=items.at(-1);if(last)setCursors(c=>[...c,last.id]);},hasPrevious:cursors.length>1};
}
export function RecordPager({page,t}:{page:ReturnType<typeof useRecordPage>;t:T}){
 return <div className="record-pager"><label className="search-input"><span>{t('Search')}</span><input type="search" value={page.query} onChange={e=>page.setQuery(e.target.value)} aria-label={t('Search')}/></label><div className="inline-actions"><button className="button small secondary" disabled={!page.hasPrevious||page.loading} onClick={page.previous}>{t('Previous')}</button><button className="button small secondary" disabled={!page.more||page.loading} onClick={page.next}>{t('Next')}</button><span role="status" className="muted">{page.loading?'…':page.items.length}</span></div>{page.error&&<ErrorMessage error={page.error}/>}</div>;
}
