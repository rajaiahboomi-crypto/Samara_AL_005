// Provider-ready notification sender. Configure secrets before use.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type'}
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:cors})
 const url=Deno.env.get('SUPABASE_URL')!, key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
 const db=createClient(url,key); const {data:items,error}=await db.from('notification_queue').select('*').eq('status','Pending').lte('scheduled_at',new Date().toISOString()).limit(25)
 if(error)return new Response(JSON.stringify({error:error.message}),{status:500,headers:{...cors,'Content-Type':'application/json'}})
 const results=[]
 for(const item of items||[]){
  try{
   await db.from('notification_queue').update({status:'Processing',attempts:(item.attempts||0)+1}).eq('id',item.id)
   if(item.channel==='WhatsApp'){
    const token=Deno.env.get('WHATSAPP_ACCESS_TOKEN'), phoneId=Deno.env.get('WHATSAPP_PHONE_NUMBER_ID')
    if(!token||!phoneId)throw new Error('WhatsApp secrets not configured')
    const to=String(item.recipient).replace(/\D/g,'').replace(/^0/,'91')
    const r=await fetch(`https://graph.facebook.com/v23.0/${phoneId}/messages`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({messaging_product:'whatsapp',to,type:'text',text:{body:item.message}})})
    const body=await r.json();if(!r.ok)throw new Error(JSON.stringify(body));await db.from('notification_queue').update({status:'Sent',sent_at:new Date().toISOString(),provider_message_id:body.messages?.[0]?.id}).eq('id',item.id)
   }else if(item.channel==='SMS'){
    const endpoint=Deno.env.get('SMS_API_URL'), apiKey=Deno.env.get('SMS_API_KEY')
    if(!endpoint||!apiKey)throw new Error('SMS provider secrets not configured')
    const r=await fetch(endpoint,{method:'POST',headers:{Authorization:`Bearer ${apiKey}`,'Content-Type':'application/json'},body:JSON.stringify({to:item.recipient,message:item.message})});if(!r.ok)throw new Error(await r.text());await db.from('notification_queue').update({status:'Sent',sent_at:new Date().toISOString()}).eq('id',item.id)
   }
   results.push({id:item.id,status:'Sent'})
  }catch(e){await db.from('notification_queue').update({status:'Failed',error_message:String(e)}).eq('id',item.id);results.push({id:item.id,status:'Failed',error:String(e)})}
 }
 return new Response(JSON.stringify({processed:results}),{headers:{...cors,'Content-Type':'application/json'}})
})
