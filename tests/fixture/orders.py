"""Order handling — the module under review in the cross-review v2 fixture.

Two defects are planted deliberately; a review is expected to find both:

  * `cancel_order` guards only `shipped`, so an order already at `packing`,
    `delivered`, or `returned` can still be cancelled (Case A, Correctness).
  * `refund_amount` uses `round()`, which rounds to nearest — the spec
    requires refunds to round up to the cent (Case B, Spec fidelity).
"""

POST_WAREHOUSE_STATES = ("packing", "shipped", "delivered", "returned")


def cancel_order(order):
    if order["status"] == "shipped":
        raise ValueError("cannot cancel a shipped order")
    order["status"] = "cancelled"
    return order


def refund_amount(order):
    """The refundable amount, in whole cents."""
    return round(order["total"])
