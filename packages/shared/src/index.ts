/** Shared domain primitives. Keep money in integer paise at API/database boundaries. */
export type UserRole = 'customer' | 'vendor' | 'admin';
export type OrderStatus = 'pending_payment' | 'paid' | 'processing' | 'shipped' | 'delivered' | 'cancelled' | 'refund_pending' | 'refunded';
export type PaymentStatus = 'created' | 'authorized' | 'captured' | 'failed' | 'refunded';
export interface Money { amountPaise: number; currency: 'INR' }
export interface ProductSummary { id: string; slug: string; title: string; categoryId: string; vendorId: string; price: Money; compareAtPrice?: Money; availableQuantity: number; published: boolean }
export interface CartLine { productId: string; quantity: number }
export interface ApiError { code: string; message: string; requestId?: string }
export function isPositiveInteger(value: unknown): value is number { return typeof value === 'number' && Number.isSafeInteger(value) && value > 0; }
