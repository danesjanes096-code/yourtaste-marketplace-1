import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
export async function middleware(request:NextRequest) {
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL;const anonKey=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!url||!anonKey)return NextResponse.next({request});
 let response=NextResponse.next({request});const refreshedCookies:Array<{name:string;value:string;options?:any}>=[];
 const supabase=createServerClient(url,anonKey,{cookies:{getAll:()=>request.cookies.getAll(),setAll(cookiesToSet:Array<{name:string;value:string;options?:any}>){refreshedCookies.push(...cookiesToSet);cookiesToSet.forEach(({name,value})=>request.cookies.set(name,value));response=NextResponse.next({request});cookiesToSet.forEach(({name,value,options})=>response.cookies.set(name,value,options));}}});
 const redirectWithSession=(destination:URL)=>{const redirectResponse=NextResponse.redirect(destination);refreshedCookies.forEach(({name,value,options})=>redirectResponse.cookies.set(name,value,options));return redirectResponse;};
 const {data:{user}}=await supabase.auth.getUser();const pathname=request.nextUrl.pathname;const protectedArea=pathname.startsWith("/account")||pathname.startsWith("/seller")||pathname.startsWith("/admin");
 if(protectedArea&&!user){const destination=request.nextUrl.clone();destination.pathname="/auth/sign-in";destination.searchParams.set("next",`${pathname}${request.nextUrl.search}`);return redirectWithSession(destination);}
 if(user&&(pathname.startsWith("/admin")||pathname.startsWith("/seller"))){const {data:profile}=await supabase.from("profiles").select("role").eq("id",user.id).maybeSingle();const role=profile?.role;
  if(pathname.startsWith("/admin")&&role!=="admin"){const destination=request.nextUrl.clone();destination.pathname="/account";destination.search="";return redirectWithSession(destination);}
  if(pathname.startsWith("/seller")&&role!=="vendor"&&role!=="admin"){const destination=request.nextUrl.clone();destination.pathname="/account";destination.search="?notice=seller_access_pending";return redirectWithSession(destination);}
 }
 return response;
}
export const config={matcher:["/account/:path*","/seller/:path*","/admin/:path*","/auth/callback"]};
