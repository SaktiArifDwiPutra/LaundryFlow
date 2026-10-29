{
    "name": "LaundryFlow API",
    "version": "1.0.0",
    "summary": "Backend pengelolaan pesanan laundry",
    "category": "Services",
    "author": "LaundryFlow Team",
    "depends": [
        "base",
        "contacts",
        "account",
        "stock",
    ],
    "data": [
        "security/ir.access.csv",
        "data/sequence.xml",
        "views/laundry_order_views.xml",
    ],
    "installable": True,
    "application": True,
    "license": "LGPL-3",
}
