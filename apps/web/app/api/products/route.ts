import {NextRequest,NextResponse} from "next/server";import {createClient} from "@supabase/supabase-js";
export const dynamic="force-dynamic";export const revalidate=0;
const MAX_PAGE_SIZE=48;const DEFAULT_PAGE_SIZE=12;
function positiveInteger(value:string|null,fallback:number,max:number){if(!value||!/^\d+$/.test(value))return fallback;const parsed=Number(value);if(!Number.isSafeInteger(parsed)||parsed<1)return fallback;return Math.min(parsed,max);}
function cleanText(value:string|null,maxLength:number){if(!value)return null;const cleaned=value.trim().replace(/[\u0000-\u001f\u007f]/g,"").slice(0,maxLength);return cleaned||null;}
export async function GET(request:NextRequest){
 const supabaseUrl=process.env.NEXT_PUBLIC_SUPABASE_URL;const anonKey=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
 if(!supabaseUrl||!anonKey)return NextResponse.json({error:"catalogue_unavailable",message:"The live catalogue is not configured yet."},{status:503,headers:{"Cache-Control":"no-store"}});
 const params=request.nextUrl.searchParams;const page=positiveInteger(params.get("page"),1,1000000);const pageSize=positiveInteger(params.get("pageSize"),DEFAULT_PAGE_SIZE,MAX_PAGE_SIZE);const search=cleanText(params.get("q"),80);const category=cleanText(params.get("category"),80);const sort=params.get("sort");const from=(page-1)*pageSize;
 if(!Number.isSafeInteger(from)||from>10000000)return NextResponse.json({error:"invalid_page",message:"Requested page is too large."},{status:400});
 const supabase=createClient(supabaseUrl,anonKey,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{headers:{"X-Client-Info":"yourtaste-catalog-api"}}});
 let query=supabase.from("products").select("id,title,slug,description,sku,price_paise,compare_at_price_paise,currency,stock_quantity,images,created_at,category:categories!inner(id,name,slug),vendor:vendors!inner(id,store_name,slug)",{count:"exact"});
 if(search)query=query.textSearch("title",search,{type:"websearch",config:"simple"});
 if(category)query=query.eq("category.slug",category);
 switch(sort){case "price_asc":query=query.order("price_paise",{ascending:true});break;case "price_desc":query=query.order("price_paise",{ascending:false});break;default:query=query.order("created_at",{ascending:false});}
 const {data,error,count}=await query.range(from,from+pageSize-1);
 if(error){console.error("YourTaste catalogue query failed",{code:error.code,message:error.message});return NextResponse.json({error:"catalogue_query_failed",message:"Could not load products right now."},{status:502,headers:{"Cache-Control":"no-store"}});}
 const products=(data??[]).map(row=>({id:row.id,title:row.title,slug:row.slug,description:row.description,sku:row.sku,pricePaise:row.price_paise,compareAtPricePaise:row.compare_at_price_paise,currency:row.currency,stockQuantity:row.stock_quantity,images:Array.isArray(row.images)?row.images:[],createdAt:row.created_at,category:row.category,vendor:row.vendor}));
 return NextResponse.json({data:products,pagination:{page,pageSize,total:count??0,totalPages:Math.ceil((count??0)/pageSize)}},{status:200,headers:{"Cache-Control":"public, s-maxage=30, stale-while-revalidate=120","X-Content-Type-Options":"nosniff"}});
}
