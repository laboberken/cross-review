# orders — specification

## Cancellation

An order may be cancelled at any point **before it leaves the warehouse**.
The post-warehouse states are `packing`, `shipped`, `delivered`, and
`returned`; in any of them, cancellation must be refused.

## Refunds

A refund is paid in whole cents. The refundable amount **must round up to the
nearest cent** — never down, never to nearest — because rounding down can leave
the customer short by up to half a cent per refund.
