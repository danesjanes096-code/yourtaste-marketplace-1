import {NextRequest,NextResponse} from "next/server";
import {createSupabaseServerClient} from "@/lib/supabase/server";
export const dynamic="force-dynamic";export const revalidate=0;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const IDEMPOTENCY_KEY=/^[A-Za-z0-9._:-]{16,128}$/;
const PUBLIC_ERRORS:Record<string,{status:number;message:string}>={
 authentication_required:{status:401,message:"Please sign in to place an order."},address_required:{status:400,message:"Choose a delivery address."},address_not_found:{status:400,message:"That delivery address could not be found."},invalid_cart:{status:400,message:"Your cart is empty or contains too many items."},invalid_cart_line:{status:400,message:"One or more cart items are invalid."},invalid_quantity:{status:400,message:"Choose a valid quantity for every item."},cart_quantity_limit:{status:400,message:"Your cart exceeds the quantity limit."},duplicate_product_lines:{status:400,message:"Your cart contains duplicate product lines. Refresh your cart and try again."},invalid_idempotency_key:{status:400,message:"A valid checkout request key is required."},idempotency_key_reused_with_different_request:{status:409,message:"This checkout request key was already used for a different cart."},product_unavailable:{status:409,message:"A product is no longer available. Refresh your cart."},insufficient_stock:{status:409,message:"There is not enough stock for one or more products."},product_price_limit:{status:409,message:"A product price needs review before it can be ordered."}
};
export async function POST(request:NextRequest){
 const origin=request.headers.get("origin");const configuredSiteUrl=process.env.NEXT_PUBLIC_SITE_URL;let expectedOrigin=request.nextUrl.origin;
 if(configuredSiteUrl){try{expectedOrigin=new URL(configuredSiteUrl).origin;}catch{return NextResponse.json({error:"checkout_not_configured",message:"Checkout origin is not configured correctly."},{status:503});}}
 if(!origin||origin!==expectedOrigin)return NextResponse.json({error:"invalid_origin",message:"Request origin could not be verified."},{status:403});
 const raw=await request.text();if(raw.length>16384)return NextResponse.json({error:"request_too_large",message:"Checkout request is too large."},{status:413});
 let body:unknown;try{body=JSON.parse(raw);}catch{return NextResponse.json({error:"invalid_json",message:"Send a valid JSON checkout request."},{status:400});}
 if(!body||typeof body!=="object")return NextResponse.json({error:"invalid_request",message:"Checkout request is invalid."},{status:400});
 const input=body as {addressId?:unknown;items?:unknown;idempotencyKey?:unknown};
 if(typeof input.addressId!=="string"||!UUID.test(input.addressId))return NextResponse.json({error:"address_required",message:"Choose a valid delivery address."},{status:400});
 if(typeof input.idempotencyKey!=="string"||!IDEMPOTENCY_KEY.test(input.idempotencyKey))return NextResponse.json({error:"invalid_idempotency_key",message:PUBLIC_ERRORS.invalid_idempotency_key.message},{status:400});
 if(!Array.isArray(input.items)||input.items.length<1||input.items.length>30)return NextResponse.json({error:"invalid_cart",message:PUBLIC_ERRORS.invalid_cart.message},{status:400});
 const items:Array<{product_id:string;quantity:number}>=[];
 for(const item of input.items){if(!item||typeof item!=="object")return NextResponse.json({error:"invalid_cart_line",message:PUBLIC_ERRORS.invalid_cart_line.message},{status:400});const line=item as {productId?:unknown;quantity?:unknown};if(typeof line.productId!=="string"||!UUID.test(line.productId)||!Number.isSafeInteger(line.quantity)||(line.quantity as number)<1||(line.quantity as number)>20)return NextResponse.json({error:"invalid_cart_line",message:PUBLIC_ERRORS.invalid_cart_line.message},{status:400});items.push({product_id:line.productId,quantity:line.quantity as number});}
 const supabase=await createSupabaseServerClient();if(!supabase)return NextResponse.json({error:"checkout_not_configured",message:"Checkout is not configured yet."},{status:503});
 const {data:{user},error:authError}=await supabase.auth.getUser();if(authError||!user)return NextResponse.json({error:"authentication_required",message:PUBLIC_ERRORS.authentication_required.message},{status:401});
 const {data,error}=await supabase.rpc("create_checkout_order",{p_address_id:input.addressId,p_items:items,p_idempotency_key:input.idempotencyKey});
 if(error){const known=PUBLIC_ERRORS[error.message];if(known)return NextResponse.json({error:error.message,message:known.message},{status:known.status});console.error("YourTaste checkout order creation failed",{code:error.code,message:error.message});return NextResponse.json({error:"order_creation_failed",message:"We could not create your order. Please try again."},{status:502});}
 const reused=Boolean(data&&typeof data==="object"&&"reused" in data&&data.reused===true);
 return NextResponse.json({data},{status:reused?200:201,headers:{"Cache-Control":"no-store","X-Content-Type-Options":"nosniff"}});
}
