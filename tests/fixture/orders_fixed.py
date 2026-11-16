"""The corrected module — the fixture's tests must go green against this.

Used by `run-tests.sh fixed` to prove the tests are sound: they fail on
`orders.py` because it has the defects, and pass here because it does not.
"""

POST_WAREHOUSE_STATES = ("packing", "shipped", "delivered", "returned")


def cancel_order(order):
    if order["status"] in POST_WAREHOUSE_STATES:
        raise ValueError(f"cannot cancel a {order['status']} order")
    order["status"] = "cancelled"
    return order


def refund_amount(order):
    """The refundable amount, in whole cents, rounded up."""
    import math

    return math.ceil(order["total"])
