import { safeNext } from "@/lib/security/safe-next.mjs";
import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

export async function GET(request: NextRequest) {
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL;const anonKey=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;const code=request.nextUrl.searchParams.get("code");const next=safeNext(request.nextUrl.searchParams.get("next"),request.url);
 if(!url||!anonKey||!code){const destination=new URL("/auth/sign-in",request.url);destination.searchParams.set("message","verification_failed");return NextResponse.redirect(destination);}
 const response=NextResponse.redirect(new URL(next,request.url));
 const supabase=createServerClient(url,anonKey,{cookies:{getAll:()=>request.cookies.getAll(),setAll(cookiesToSet:Array<{name:string;value:string;options?:any}>){cookiesToSet.forEach(({name,value,options})=>{request.cookies.set(name,value);response.cookies.set(name,value,options);});}}});
 const {error}=await supabase.auth.exchangeCodeForSession(code);
 if(error){const destination=new URL("/auth/sign-in",request.url);destination.searchParams.set("message","verification_failed");return NextResponse.redirect(destination);}
 return response;
}
