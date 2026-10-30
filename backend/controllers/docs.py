# -*- coding: utf-8 -*-
import json
from odoo import http
from odoo.http import request, Response


class ApiDocsController(http.Controller):
    """Controller untuk menyajikan spesifikasi OpenAPI dan dokumentasi interaktif Scalar."""

    def _get_openapi_spec(self, base_url=None):
        """Menghasilkan spesifikasi OpenAPI 3.0.3 sesuai implementasi aktual endpoint LaundryFlow."""
        default_vps_url = "http://117.53.47.93:8069"
        servers = []
        if base_url:
            clean_url = base_url.rstrip("/")
            if "localhost" not in clean_url and "127.0.0.1" not in clean_url:
                servers.append({
                    "url": clean_url,
                    "description": "LaundryFlow VPS Server",
                })
        if not any(s["url"] == default_vps_url for s in servers):
            servers.append({
                "url": default_vps_url,
                "description": "LaundryFlow VPS Server",
            })

        return {
            "openapi": "3.0.3",
            "info": {
                "title": "LaundryFlow API",
                "version": "1.0.0",
                "description": (
                    "Dokumentasi resmi REST API **LaundryFlow Backend** berbasis Odoo 20.\n\n"
                    "### Prinsip & Arsitektur Utama\n"
                    "1. **Hak Akses & Keamanan**:\n"
                    "   - **Pelanggan (Customer/Portal)**: Dilarang keras mengakses endpoint inventory (`/api/laundry/inventory`).\n"
                    "   - **Harga Beli (Cost / `standard_price`)**: Merupakan informasi internal perusahaan dan tidak boleh dikirimkan kepada pelanggan.\n"
                    "   - **Harga Jual (`list_price`)**: Ditampilkan pada katalog layanan laundry untuk pelanggan dan bahan retail bila relevan.\n"
                    "   - **Pegawai & Admin (`base.group_user`)**: Memiliki hak akses untuk memantau stok, lot/batch, dan status kedaluwarsa.\n\n"
                    "2. **Stok & Pengelolaan Batch/Kedaluwarsa**:\n"
                    "   - **Stok Berasal dari Odoo**: Dihitung secara real-time dari model inventory resmi Odoo (`stock.quant`) murni dari **lokasi gudang internal** (`usage = 'internal'`). Lokasi scrap atau customer tidak dihitung.\n"
                    "   - **Kedaluwarsa Dicatat per Batch/Lot**: Tanggal kedaluwarsa dan status kedaluwarsa (`safe`, `expiring_soon`, `expired`, `unknown`) dicatat pada masing-masing batch (`stock.lot`).\n"
                    "   - **Satu Produk Mempunyai Beberapa Batch**: Satu produk bahan laundry dapat memiliki beberapa batch dengan tanggal kedaluwarsa dan kuantitas berbeda-beda.\n"
                    "   - **Produk Tanpa Kedaluwarsa**: Batch tanpa tanggal kedaluwarsa tetap ditangani secara sah dengan status `unknown`.\n\n"
                    "3. **Perhitungan Total Order oleh Backend**:\n"
                    "   - **Backend Menghitung Ulang Seluruh Harga**: Backend tidak mempercayai total atau subtotal yang dikirimkan oleh klien Flutter untuk mencegah manipulasi harga.\n"
                    "   - **Snapshot Harga**: Harga satuan disimpan pada detail order saat transaksi dibuat sehingga perubahan harga di masa depan tidak mengubah transaksi lama.\n"
                    "   - **Rumus Perhitungan**:\n"
                    "     * **Kg**: `subtotal = berat * harga_per_kg`\n"
                    "     * **Pcs**: `subtotal = jumlah * harga_per_pcs`\n"
                    "     * **Set**: `subtotal = jumlah_set * harga_per_set`\n"
                    "     * **Karpet m²**: `luas = panjang * lebar (m²)`, `subtotal = luas * harga_per_m²`. Panjang dan lebar wajib positif (> 0); ukuran nol atau negatif ditolak dengan HTTP 400.\n\n"
                    "4. **Pilihan Kecepatan Pengerjaan (Reguler & Same Day Service)**:\n"
                    "   - Same Day Service adalah pilihan prioritas pengerjaan pesanan, bukan produk duplikat.\n"
                    "   - Opsi `service_speed` bernilai `regular` (biaya 0) atau `same_day` (biaya tambahan snapshot dari konfigurasi Odoo).\n\n"
                    "### Mekanisme Autentikasi\n"
                    "Endpoint yang dilindungi memerlukan autentikasi sesi Odoo yang valid:\n"
                    "- Header `Authorization: Bearer <session_id>`\n"
                    "- Header `X-Session-Id: <session_id>`\n"
                    "- Header `X-Api-Key: <api_key>`\n"
                    "- Cookie sesi `session_id`"
                ),
                "contact": {"name": "LaundryFlow Team"},
                "license": {"name": "LGPL-3.0", "url": "https://www.gnu.org/licenses/lgpl-3.0.html"},
            },
            "servers": servers,
            "tags": [
                {"name": "Authentication", "description": "Autentikasi pengguna dan pembuatan sesi akses API."},
                {"name": "Customers", "description": "Pencarian dan penambahan data pelanggan LaundryFlow (`res.partner`)."},
                {"name": "Products", "description": "Katalog produk layanan laundry (`product.template`) untuk pelanggan."},
                {"name": "Inventory", "description": "Monitoring stok bahan laundry internal, data batch/lot, dan status kedaluwarsa."},
                {"name": "Orders", "description": "Pengelolaan pesanan laundry (`laundry.order`), kecepatan pengerjaan, dan kalkulasi subtotal."},
            ],
            "paths": {
                "/api/laundry/auth/login": {
                    "post": {
                        "tags": ["Authentication"],
                        "summary": "Login Pengguna",
                        "operationId": "loginUser",
                        "description": "Autentikasi pengguna Odoo menggunakan kredensial dan mengembalikan `session_id`.",
                        "security": [],
                        "requestBody": {
                            "required": True,
                            "content": {
                                "application/json": {
                                    "schema": {"$ref": "#/components/schemas/LoginRequest"},
                                    "example": {
                                        "login": "admin",
                                        "password": "your_password_here",
                                        "db": "odoo20"
                                    }
                                }
                            }
                        },
                        "responses": {
                            "200": {
                                "description": "Login berhasil.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/LoginResponse"},
                                        "example": {
                                            "success": True,
                                            "message": "Login berhasil",
                                            "data": {
                                                "uid": 2,
                                                "name": "Mitchell Admin",
                                                "username": "admin",
                                                "session_id": "a1b2c3d4e5f67890abcdef1234567890"
                                            }
                                        }
                                    }
                                }
                            },
                            "400": {
                                "description": "Request body tidak valid atau kredensial kosong.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/ErrorResponse"},
                                        "example": {"success": False, "message": "Username dan password wajib diisi"}
                                    }
                                }
                            },
                            "401": {
                                "description": "Kredensial login atau password salah.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/ErrorResponse"},
                                        "example": {"success": False, "message": "Autentikasi gagal. Username atau password salah."}
                                    }
                                }
                            }
                        }
                    }
                },
                "/api/laundry/customers/search": {
                    "get": {
                        "tags": ["Customers"],
                        "summary": "Cari Pelanggan",
                        "operationId": "searchCustomers",
                        "description": "Mencari pelanggan berdasarkan nama, nomor telepon, atau alamat email.",
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "parameters": [
                            {"name": "q", "in": "query", "required": False, "description": "Kata kunci pencarian nama atau telepon.", "schema": {"type": "string"}, "example": "Rian"}
                        ],
                        "responses": {
                            "200": {
                                "description": "Pencarian pelanggan berhasil.",
                                "content": {
                                    "application/json": {
                                        "example": {
                                            "success": True,
                                            "count": 1,
                                            "data": [
                                                {"id": 11, "name": "Rian Ardiansyah", "phone": "08123456789", "email": "rian@example.com", "address": "Jl. Mawar No. 10"}
                                            ]
                                        }
                                    }
                                }
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Autentikasi diperlukan."}}}
                            }
                        }
                    }
                },
                "/api/laundry/customers": {
                    "post": {
                        "tags": ["Customers"],
                        "summary": "Buat Pelanggan Baru",
                        "operationId": "createCustomer",
                        "description": (
                            "Menambahkan data pelanggan baru ke Odoo (`res.partner`).\n\n"
                            "**Route Alias yang Didukung:**\n"
                            "- `POST /api/laundry/customers`\n"
                            "- `POST /api/laundry/customers/create`\n"
                            "- `POST /api/customers`"
                        ),
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "requestBody": {
                            "required": True,
                            "content": {
                                "application/json": {
                                    "example": {
                                        "name": "Budi Santoso",
                                        "phone": "085712345678",
                                        "address": "Jl. Melati No. 4",
                                        "city": "Surabaya"
                                    }
                                }
                            }
                        },
                        "responses": {
                            "201": {
                                "description": "Pelanggan berhasil dibuat.",
                                "content": {
                                    "application/json": {
                                        "example": {
                                            "success": True,
                                            "message": "Pelanggan berhasil ditambahkan",
                                            "data": {"id": 105, "name": "Budi Santoso", "phone": "085712345678", "address": "Jl. Melati No. 4"}
                                        }
                                    }
                                }
                            },
                            "400": {
                                "description": "Nama pelanggan wajib diisi.",
                                "content": {"application/json": {"example": {"success": False, "message": "Nama pelanggan wajib diisi"}}}
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Autentikasi diperlukan."}}}
                            }
                        }
                    }
                },
                "/api/laundry/customers/{customer_id}": {
                    "delete": {
                        "tags": ["Customers"],
                        "summary": "Hapus Pelanggan",
                        "operationId": "deleteCustomer",
                        "description": "Menghapus data pelanggan berdasarkan ID (`res.partner`).",
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "parameters": [
                            {"name": "customer_id", "in": "path", "required": True, "description": "ID pelanggan.", "schema": {"type": "integer"}, "example": 105}
                        ],
                        "responses": {
                            "200": {
                                "description": "Pelanggan berhasil dihapus.",
                                "content": {"application/json": {"example": {"success": True, "message": "Pelanggan berhasil dihapus."}}}
                            },
                            "404": {
                                "description": "Pelanggan tidak ditemukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Pelanggan tidak ditemukan."}}}
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Autentikasi diperlukan."}}}
                            }
                        }
                    }
                },
                "/api/laundry/products": {
                    "get": {
                        "tags": ["Products"],
                        "summary": "Daftar Layanan Laundry",
                        "operationId": "getProductsList",
                        "description": (
                            "Mengambil katalog layanan laundry yang tersedia untuk pelanggan.\n\n"
                            "**Ketentuan Bisnis:**\n"
                            "- Hanya menampilkan produk layanan laundry (`type = service`).\n"
                            "- Bahan inventory (`MAT-`) **tidak pernah muncul** pada katalog pelanggan.\n"
                            "- Mengembalikan HTTP 200 dengan `{\"data\": []}` jika pencarian tidak menemukan hasil."
                        ),
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "parameters": [
                            {"name": "q", "in": "query", "required": False, "description": "Pencarian nama layanan.", "schema": {"type": "string"}, "example": "Cuci"},
                            {"name": "category", "in": "query", "required": False, "description": "Filter kategori.", "schema": {"type": "string"}, "example": "Layanan Laundry"}
                        ],
                        "responses": {
                            "200": {
                                "description": "Daftar layanan berhasil diambil.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/ProductListResponse"},
                                        "example": {
                                            "success": True,
                                            "count": 3,
                                            "data": [
                                                {"id": 11, "sku": "SRV-WSH-001", "name": "Cuci Kiloan", "unit_price": 8000.0, "uom": "kg", "category": "Layanan Laundry", "pricing_type": "weight"},
                                                {"id": 12, "sku": "SRV-WSH-003", "name": "Cuci Setrika", "unit_price": 10000.0, "uom": "kg", "category": "Layanan Laundry", "pricing_type": "weight"},
                                                {"id": 86, "sku": "SRV-HME-001", "name": "Karpet", "unit_price": 10000.0, "uom": "m²", "category": "Laundry Karpet & Perlengkapan Rumah", "pricing_type": "area"}
                                            ]
                                        }
                                    }
                                }
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Autentikasi diperlukan."}}}
                            }
                        }
                    }
                },
                "/api/laundry/products/{product_id}": {
                    "get": {
                        "tags": ["Products"],
                        "summary": "Detail Layanan Laundry",
                        "operationId": "getProductDetail",
                        "description": "Mengambil detail satu layanan laundry berdasarkan ID (`product.template`).",
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "parameters": [
                            {"name": "product_id", "in": "path", "required": True, "description": "ID unik produk layanan.", "schema": {"type": "integer"}, "example": 12}
                        ],
                        "responses": {
                            "200": {
                                "description": "Detail layanan ditemukan.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/ProductDetailResponse"},
                                        "example": {
                                            "success": True,
                                            "data": {
                                                "id": 12,
                                                "sku": "SRV-WSH-003",
                                                "name": "Cuci Setrika",
                                                "unit_price": 10000.0,
                                                "uom": "kg",
                                                "category": "Layanan Laundry",
                                                "pricing_type": "weight",
                                                "active": True
                                            }
                                        }
                                    }
                                }
                            },
                            "404": {
                                "description": "Layanan tidak ditemukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Data produk tidak ditemukan"}}}
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Autentikasi diperlukan."}}}
                            }
                        }
                    },
                    "put": {
                        "tags": ["Products"],
                        "summary": "Perbarui Harga / Data Layanan Laundry",
                        "operationId": "updateProduct",
                        "description": "Memperbarui harga jual (`list_price`), nama, deskripsi, atau status layanan laundry di Odoo oleh Admin/Staff.",
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "parameters": [
                            {"name": "product_id", "in": "path", "required": True, "description": "ID unik produk layanan.", "schema": {"type": "integer"}, "example": 11}
                        ],
                        "requestBody": {
                            "required": True,
                            "content": {
                                "application/json": {
                                    "example": {
                                        "price": 8500,
                                        "name": "Cuci Kiloan Reguler"
                                    }
                                }
                            }
                        },
                        "responses": {
                            "200": {
                                "description": "Harga dan data produk berhasil diperbarui.",
                                "content": {
                                    "application/json": {
                                        "example": {
                                            "success": True,
                                            "message": "Data produk berhasil diperbarui",
                                            "data": {
                                                "id": 11,
                                                "sku": "SRV-WSH-001",
                                                "name": "Cuci Kiloan Reguler",
                                                "unit_price": 8500.0,
                                                "uom": "kg",
                                                "category": "Layanan Laundry",
                                                "pricing_type": "weight",
                                                "active": True
                                            }
                                        }
                                    }
                                }
                            },
                            "400": {
                                "description": "Validasi gagal (harga tidak valid atau format salah).",
                                "content": {"application/json": {"example": {"success": False, "message": "Harga produk harus berupa angka lebih besar dari 0"}}}
                            },
                            "403": {
                                "description": "Akses ditolak (hanya internal/admin yang berwenang).",
                                "content": {"application/json": {"example": {"success": False, "message": "Akses ditolak: Hanya admin atau staf yang berwenang mengubah harga produk."}}}
                            },
                            "404": {
                                "description": "Produk tidak ditemukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Data produk tidak ditemukan atau bukan merupakan layanan laundry"}}}
                            }
                        }
                    }
                },
                "/api/laundry/inventory": {
                    "get": {
                        "tags": ["Inventory"],
                        "summary": "Monitoring Inventory Bahan Laundry",
                        "operationId": "getInventoryList",
                        "description": (
                            "Mengambil data monitoring inventory bahan laundry dari lokasi gudang internal Odoo beserta rincian batch dan status kedaluwarsa.\n\n"
                            "**Keamanan & Hak Akses:**\n"
                            "- Hanya untuk **Admin** dan **Pegawai internal** Odoo (`base.group_user`).\n"
                            "- **Pelanggan ditolak** dengan HTTP 403 Forbidden.\n"
                            "- **Harga beli (`purchase_price` / `standard_price`)**: Merupakan informasi rahasia internal dan dilarang untuk pelanggan.\n"
                            "- **Harga jual (`sale_price` / `list_price`)**: Ditampilkan sesuai peruntukan.\n"
                            "- **Stok fisik aktual (`quantity_on_hand`)**: Murni berasal dari lokasi gudang internal Odoo (`usage = 'internal'`).\n"
                            "- **Tanggal Kedaluwarsa**: Dicatat per masing-masing batch (`stock.lot`). Satu produk dapat memiliki beberapa batch dengan tanggal kedaluwarsa dan kuantitas yang berbeda-beda.\n"
                            "- Produk stok nol tetap ditampilkan dengan `quantity_on_hand: 0.0`.\n\n"
                            "**Route Alias:**\n"
                            "- `GET /api/laundry/inventory`\n"
                            "- `GET /api/inventory`"
                        ),
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "responses": {
                            "200": {
                                "description": "Daftar inventory bahan laundry berhasil diambil. Contoh di bawah menggambarkan satu produk dengan dua batch berbeda.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/InventoryListResponse"},
                                        "example": {
                                            "data": [
                                                {
                                                    "id": 92,
                                                    "sku": "MAT-DET-001",
                                                    "name": "Deterjen Bubuk",
                                                    "category": "Bahan Laundry",
                                                    "quantity_on_hand": 25.0,
                                                    "uom": "kg",
                                                    "purchase_price": 15000.0,
                                                    "sale_price": 22000.0,
                                                    "batches": [
                                                        {
                                                            "lot_id": 51,
                                                            "batch_number": "BATCH-DET-202610-01",
                                                            "received_date": "2026-10-10",
                                                            "expiration_date": "2027-04-10",
                                                            "quantity": 25.0,
                                                            "expiration_status": "safe"
                                                        }
                                                    ]
                                                },
                                                {
                                                    "id": 93,
                                                    "sku": "MAT-DET-002",
                                                    "name": "Deterjen Cair",
                                                    "category": "Bahan Laundry",
                                                    "quantity_on_hand": 25.0,
                                                    "uom": "L",
                                                    "purchase_price": 18000.0,
                                                    "sale_price": 0.0,
                                                    "batches": [
                                                        {
                                                            "lot_id": 101,
                                                            "batch_number": "BATCH-LIQ-202610-01",
                                                            "received_date": "2026-10-15",
                                                            "expiration_date": "2027-04-15",
                                                            "quantity": 10.0,
                                                            "expiration_status": "safe"
                                                        },
                                                        {
                                                            "lot_id": 102,
                                                            "batch_number": "BATCH-LIQ-202610-02",
                                                            "received_date": "2026-10-20",
                                                            "expiration_date": "2026-11-10",
                                                            "quantity": 15.0,
                                                            "expiration_status": "expiring_soon"
                                                        }
                                                    ]
                                                },
                                                {
                                                    "id": 95,
                                                    "sku": "MAT-PRF-001",
                                                    "name": "Pelicin dan Parfum Setrika",
                                                    "category": "Bahan Laundry",
                                                    "quantity_on_hand": 5.0,
                                                    "uom": "L",
                                                    "purchase_price": 25000.0,
                                                    "sale_price": 0.0,
                                                    "batches": [
                                                        {
                                                            "lot_id": 103,
                                                            "batch_number": "BATCH-PRF-NOEXP",
                                                            "received_date": "2026-10-25",
                                                            "expiration_date": None,
                                                            "quantity": 5.0,
                                                            "expiration_status": "unknown"
                                                        }
                                                    ]
                                                }
                                            ]
                                        }
                                    }
                                }
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"error": "Unauthorized", "message": "Autentikasi diperlukan untuk mengakses inventory laundry."}}}
                            },
                            "403": {
                                "description": "Akses ditolak untuk pelanggan (Customer).",
                                "content": {"application/json": {"example": {"error": "Forbidden", "message": "Akses ditolak. Pelanggan tidak memiliki izin untuk melihat inventory atau data internal."}}}
                            }
                        }
                    }
                },
                "/api/laundry/inventory/{product_id}": {
                    "get": {
                        "tags": ["Inventory"],
                        "summary": "Detail Inventory Bahan Laundry",
                        "operationId": "getInventoryDetail",
                        "description": "Mengambil rincian stok internal dan daftar batch untuk satu bahan laundry tertentu.",
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "parameters": [
                            {"name": "product_id", "in": "path", "required": True, "description": "ID unik produk bahan laundry (`product.product`).", "schema": {"type": "integer"}, "example": 93}
                        ],
                        "responses": {
                            "200": {
                                "description": "Detail inventory produk ditemukan dengan rincian dua batch berbeda.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/InventoryDetailResponse"},
                                        "example": {
                                            "data": {
                                                "id": 93,
                                                "sku": "MAT-DET-002",
                                                "name": "Deterjen Cair",
                                                "category": "Bahan Laundry",
                                                "quantity_on_hand": 25.0,
                                                "uom": "L",
                                                "purchase_price": 18000.0,
                                                "sale_price": 0.0,
                                                "batches": [
                                                    {
                                                        "lot_id": 101,
                                                        "batch_number": "BATCH-LIQ-202610-01",
                                                        "received_date": "2026-10-15",
                                                        "expiration_date": "2027-04-15",
                                                        "quantity": 10.0,
                                                        "expiration_status": "safe"
                                                    },
                                                    {
                                                        "lot_id": 102,
                                                        "batch_number": "BATCH-LIQ-202610-02",
                                                        "received_date": "2026-10-20",
                                                        "expiration_date": "2026-11-10",
                                                        "quantity": 15.0,
                                                        "expiration_status": "expiring_soon"
                                                    }
                                                ]
                                            }
                                        }
                                    }
                                }
                            },
                            "404": {
                                "description": "Bahan laundry tidak ditemukan.",
                                "content": {"application/json": {"example": {"error": "Not Found", "message": "Bahan laundry dengan ID 999999 tidak ditemukan."}}}
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"error": "Unauthorized", "message": "Autentikasi diperlukan untuk mengakses inventory laundry."}}}
                            },
                            "403": {
                                "description": "Akses ditolak untuk pelanggan.",
                                "content": {"application/json": {"example": {"error": "Forbidden", "message": "Akses ditolak. Pelanggan tidak memiliki izin untuk melihat inventory atau data internal."}}}
                            }
                        }
                    }
                },
                "/api/laundry/service-speeds": {
                    "get": {
                        "tags": ["Orders"],
                        "summary": "Daftar Opsi Kecepatan Pengerjaan",
                        "operationId": "getServiceSpeeds",
                        "description": (
                            "Mengambil daftar pilihan kecepatan pengerjaan pesanan laundry yang tersedia (Reguler dan Same Day Service).\n\n"
                            "**Aturan Bisnis & Operasional:**\n"
                            "- Pelanggan dapat memilih antara `regular` (Reguler) atau `same_day` (Same Day Service).\n"
                            "- Admin dapat mengatur ketersediaan Same Day melalui konfigurasi Odoo.\n"
                            "- Jika Same Day tidak aktif, field `available` bernilai `false`.\n"
                            "- Tarif biaya tambahan diambil dari konfigurasi Odoo (`0.0` jika belum ada tarif yang dikonfirmasi).\n\n"
                            "**Route Alias:**\n"
                            "- `GET /api/laundry/service-speeds`\n"
                            "- `GET /api/laundry/orders/options`"
                        ),
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "responses": {
                            "200": {
                                "description": "Daftar opsi kecepatan pengerjaan berhasil diambil.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/ServiceSpeedListResponse"},
                                        "example": {
                                            "success": True,
                                            "count": 2,
                                            "data": [
                                                {"code": "regular", "name": "Reguler", "available": True, "fee": 0.0, "description": "Pengerjaan standar laundry sesuai antrean"},
                                                {"code": "same_day", "name": "Same Day Service", "available": True, "fee": 0.0, "description": "Pengerjaan prioritas selesai di hari yang sama"}
                                            ]
                                        }
                                    }
                                }
                            },
                            "401": {
                                "description": "Autentikasi gagal atau sesi tidak valid.",
                                "content": {"application/json": {"example": {"success": False, "message": "Autentikasi diperlukan. Akses tidak diizinkan."}}}
                            }
                        }
                    }
                },
                "/api/laundry/orders": {
                    "get": {
                        "tags": ["Orders"],
                        "summary": "Daftar Pesanan Laundry",
                        "operationId": "getOrdersList",
                        "description": "Mengembalikan daftar riwayat transaksi pesanan laundry dengan opsi filter dan pagination.",
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "parameters": [
                            {"name": "partner_id", "in": "query", "required": False, "description": "Filter pesanan berdasarkan ID pelanggan.", "schema": {"type": "integer"}},
                            {"name": "state", "in": "query", "required": False, "description": "Filter status pesanan (received, washing, ironing, ready, completed, cancelled).", "schema": {"type": "string"}},
                            {"name": "service_speed", "in": "query", "required": False, "description": "Filter kecepatan pengerjaan (regular, same_day).", "schema": {"type": "string"}},
                            {"name": "limit", "in": "query", "required": False, "description": "Jumlah maksimal baris data (maks 100).", "schema": {"type": "integer", "default": 50}},
                            {"name": "offset", "in": "query", "required": False, "description": "Offset baris data untuk paging.", "schema": {"type": "integer", "default": 0}}
                        ],
                        "responses": {
                            "200": {
                                "description": "Daftar pesanan berhasil diambil.",
                                "content": {
                                    "application/json": {
                                        "example": {
                                            "success": True,
                                            "count": 2,
                                            "data": [
                                                {
                                                    "id": 279,
                                                    "name": "LDR/2026/00315",
                                                    "order_date": "2026-10-30T09:19:48",
                                                    "partner_id": 11,
                                                    "partner_name": "Rian Ardiansyah",
                                                    "service_speed": "same_day",
                                                    "service_speed_fee": 15000.0,
                                                    "weight": 2.0,
                                                    "total_amount": 35000.0,
                                                    "state": "received",
                                                    "notes": "Pesanan kilat",
                                                    "lines_count": 1
                                                }
                                            ]
                                        }
                                    }
                                }
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Autentikasi diperlukan. Akses tidak diizinkan."}}}
                            }
                        }
                    },
                    "post": {
                        "tags": ["Orders"],
                        "summary": "Buat Pesanan Laundry",
                        "operationId": "createOrder",
                        "description": (
                            "Membuat transaksi pesanan laundry dengan dukungan satu atau beberapa layanan sekaligus (multi-detail).\n\n"
                            "**Aturan Kalkulasi Backend & Integritas:**\n"
                            "1. **Backend Menghitung Ulang Seluruh Harga**: Total harga tidak pernah mempercayai nilai dari Flutter. Manipulasi harga client diabaikan.\n"
                            "2. **Kalkulasi Satuan**:\n"
                            "   - **Kg (Berat)**: `subtotal = berat * harga_per_kg`\n"
                            "   - **Pcs (Satuan)**: `subtotal = jumlah * harga_per_pcs`\n"
                            "   - **Set (Perlengkapan)**: `subtotal = jumlah_set * harga_per_set`\n"
                            "   - **Karpet (m²)**: `luas = panjang * lebar`, `subtotal = luas * harga_per_m²`. Panjang dan lebar wajib positif (> 0); ukuran nol atau negatif ditolak dengan HTTP 400.\n"
                            "3. **Kecepatan Pengerjaan**:\n"
                            "   - `service_speed`: `regular` atau `same_day`.\n"
                            "   - Biaya surcharge Same Day di-snapshot ke `service_speed_fee` dari konfigurasi Odoo.\n"
                            "   - Jika Same Day dinonaktifkan oleh Admin, pembuatan pesanan ditolak dengan HTTP 400.\n"
                            "4. **Snapshot Harga Transaksi**: Harga satuan saat transaksi disimpan pada record line pesanan sehingga perubahan harga katalog Odoo masa depan tidak mengubah transaksi lama.\n\n"
                            "**Route Alias:**\n"
                            "- `POST /api/laundry/orders`\n"
                            "- `POST /api/orders`"
                        ),
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "requestBody": {
                            "required": True,
                            "content": {
                                "application/json": {
                                    "schema": {"$ref": "#/components/schemas/OrderCreateRequest"},
                                    "examples": {
                                        "multiDetailOrder": {
                                            "summary": "Order Multi-Detail (Cuci Setrika 3 kg + Karpet 2x3m + Selimut 1 pcs)",
                                            "value": {
                                                "partner_id": 11,
                                                "service_speed": "same_day",
                                                "notes": "Pesanan campur prioritas same day",
                                                "lines": [
                                                    {"product_template_id": 12, "weight": 3.0, "item_details": "Pakaian sehari-hari"},
                                                    {"product_template_id": 86, "length": 2.0, "width": 3.0, "item_details": "Karpet Ruang Tamu"},
                                                    {"product_template_id": 14, "quantity": 1.0, "item_details": "Selimut Bulu"}
                                                ]
                                            }
                                        },
                                        "singleServiceOrder": {
                                            "summary": "Order Satu Layanan Kiloan",
                                            "value": {
                                                "partner_id": 11,
                                                "service_speed": "regular",
                                                "lines": [
                                                    {"product_template_id": 12, "weight": 4.0}
                                                ]
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        "responses": {
                            "201": {
                                "description": "Pesanan berhasil dibuat.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/OrderCreateResponse"},
                                        "example": {
                                            "success": True,
                                            "message": "Pesanan berhasil dibuat.",
                                            "data": {
                                                "id": 88,
                                                "name": "ORD/2026/00088",
                                                "partner_id": 11,
                                                "service_speed": "same_day",
                                                "service_speed_fee": 0.0,
                                                "total_amount": 115000.0,
                                                "weight": 3.0,
                                                "state": "received"
                                            }
                                        }
                                    }
                                }
                            },
                            "400": {
                                "description": "Validasi gagal: ukuran nol/negatif, pelanggan kosong, atau opsi Same Day tidak aktif.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/ErrorResponse"},
                                        "examples": {
                                            "zeroCarpetDimension": {
                                                "summary": "Ukuran karpet nol atau negatif",
                                                "value": {"success": False, "message": "Panjang dan lebar karpet harus berupa angka positif lebih dari 0."}
                                            },
                                            "missingCustomer": {
                                                "summary": "Pelanggan belum dipilih",
                                                "value": {"success": False, "message": "Pelanggan (partner_id) wajib diisi."}
                                            },
                                            "sameDayDisabled": {
                                                "summary": "Same Day Service sedang tidak tersedia",
                                                "value": {"success": False, "message": "Layanan Same Day Service saat ini sedang tidak tersedia."}
                                            }
                                        }
                                    }
                                }
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Autentikasi diperlukan. Akses tidak diizinkan."}}}
                            }
                        }
                    }
                },
                "/api/laundry/orders/{order_id}": {
                    "get": {
                        "tags": ["Orders"],
                        "summary": "Detail Pesanan Laundry",
                        "operationId": "getOrderDetail",
                        "description": "Mengambil rincian lengkap satu transaksi pesanan laundry beserta detail baris layanan, snapshot harga satuan, luas karpet (m²), subtotal, dan total pesanan.",
                        "security": [{"BearerAuth": []}, {"SessionHeaderAuth": []}],
                        "parameters": [
                            {"name": "order_id", "in": "path", "required": True, "description": "ID unik transaksi pesanan laundry.", "schema": {"type": "integer"}, "example": 88}
                        ],
                        "responses": {
                            "200": {
                                "description": "Detail pesanan berhasil ditemukan.",
                                "content": {
                                    "application/json": {
                                        "schema": {"$ref": "#/components/schemas/OrderDetailResponse"},
                                        "example": {
                                            "success": True,
                                            "data": {
                                                "id": 88,
                                                "name": "ORD/2026/00088",
                                                "order_date": "2026-10-30T10:00:00Z",
                                                "partner_id": 11,
                                                "partner_name": "Rian Ardiansyah",
                                                "service_speed": "same_day",
                                                "service_speed_fee": 0.0,
                                                "weight": 3.0,
                                                "total_amount": 115000.0,
                                                "state": "received",
                                                "notes": "Pesanan campur prioritas same day",
                                                "lines": [
                                                    {
                                                        "id": 120,
                                                        "product_id": 12,
                                                        "product_name": "Cuci Setrika",
                                                        "pricing_type": "weight",
                                                        "uom": "kg",
                                                        "weight": 3.0,
                                                        "quantity": 3.0,
                                                        "length": 0.0,
                                                        "width": 0.0,
                                                        "area": 0.0,
                                                        "price_unit": 10000.0,
                                                        "subtotal": 30000.0,
                                                        "item_details": "Pakaian sehari-hari"
                                                    },
                                                    {
                                                        "id": 121,
                                                        "product_id": 86,
                                                        "product_name": "Karpet",
                                                        "pricing_type": "area",
                                                        "uom": "m²",
                                                        "weight": 0.0,
                                                        "quantity": 6.0,
                                                        "length": 2.0,
                                                        "width": 3.0,
                                                        "area": 6.0,
                                                        "price_unit": 10000.0,
                                                        "subtotal": 60000.0,
                                                        "item_details": "Karpet Ruang Tamu"
                                                    },
                                                    {
                                                        "id": 122,
                                                        "product_id": 14,
                                                        "product_name": "Selimut",
                                                        "pricing_type": "unit",
                                                        "uom": "pcs",
                                                        "weight": 0.0,
                                                        "quantity": 1.0,
                                                        "length": 0.0,
                                                        "width": 0.0,
                                                        "area": 0.0,
                                                        "price_unit": 25000.0,
                                                        "subtotal": 25000.0,
                                                        "item_details": "Selimut Bulu"
                                                    }
                                                ]
                                            }
                                        }
                                    }
                                }
                            },
                            "404": {
                                "description": "Pesanan tidak ditemukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Pesanan dengan ID 999999 tidak ditemukan."}}}
                            },
                            "401": {
                                "description": "Autentikasi diperlukan.",
                                "content": {"application/json": {"example": {"success": False, "message": "Autentikasi diperlukan. Akses tidak diizinkan."}}}
                            }
                        }
                    }
                }
            },
            "components": {
                "securitySchemes": {
                    "BearerAuth": {
                        "type": "http",
                        "scheme": "bearer",
                        "description": "Gunakan `session_id` pada header `Authorization: Bearer <session_id>`.",
                    },
                    "SessionHeaderAuth": {
                        "type": "apiKey",
                        "in": "header",
                        "name": "X-Session-Id",
                        "description": "Gunakan `session_id` pada header `X-Session-Id`.",
                    },
                    "ApiKeyHeaderAuth": {
                        "type": "apiKey",
                        "in": "header",
                        "name": "X-Api-Key",
                        "description": "Gunakan API Key pengguna Odoo pada header `X-Api-Key`.",
                    },
                },
                "schemas": {
                    "LoginRequest": {
                        "type": "object",
                        "required": ["password"],
                        "properties": {
                            "login": {"type": "string", "example": "admin"},
                            "username": {"type": "string", "example": "admin"},
                            "password": {"type": "string", "format": "password", "example": "password123"},
                            "db": {"type": "string", "default": "odoo20", "example": "odoo20"}
                        }
                    },
                    "LoginResponse": {
                        "type": "object",
                        "required": ["success", "message", "data"],
                        "properties": {
                            "success": {"type": "boolean", "example": True},
                            "message": {"type": "string", "example": "Login berhasil"},
                            "data": {
                                "type": "object",
                                "properties": {
                                    "uid": {"type": "integer", "example": 2},
                                    "name": {"type": "string", "example": "Mitchell Admin"},
                                    "username": {"type": "string", "example": "admin"},
                                    "session_id": {"type": "string", "example": "a1b2c3d4e5f67890abcdef1234567890"}
                                }
                            }
                        }
                    },
                    "ErrorResponse": {
                        "type": "object",
                        "required": ["success", "message"],
                        "properties": {
                            "success": {"type": "boolean", "example": False},
                            "message": {"type": "string", "example": "Pesan deskripsi kesalahan"}
                        }
                    },
                    "ProductItem": {
                        "type": "object",
                        "required": ["id", "name", "unit_price", "uom"],
                        "properties": {
                            "id": {"type": "integer", "example": 11},
                            "sku": {"type": "string", "example": "SRV-WSH-001"},
                            "name": {"type": "string", "example": "Cuci Kiloan"},
                            "unit_price": {"type": "number", "example": 8000.0},
                            "uom": {"type": "string", "example": "kg"},
                            "category": {"type": "string", "example": "Layanan Laundry"},
                            "pricing_type": {"type": "string", "enum": ["weight", "unit", "set", "area"], "example": "weight"},
                            "active": {"type": "boolean", "example": True}
                        }
                    },
                    "ProductListResponse": {
                        "type": "object",
                        "required": ["success", "count", "data"],
                        "properties": {
                            "success": {"type": "boolean", "example": True},
                            "count": {"type": "integer", "example": 3},
                            "data": {"type": "array", "items": {"$ref": "#/components/schemas/ProductItem"}}
                        }
                    },
                    "ProductDetailResponse": {
                        "type": "object",
                        "required": ["success", "data"],
                        "properties": {
                            "success": {"type": "boolean", "example": True},
                            "data": {"$ref": "#/components/schemas/ProductItem"}
                        }
                    },
                    "InventoryBatchItem": {
                        "type": "object",
                        "required": ["lot_id", "batch_number", "quantity", "expiration_status"],
                        "properties": {
                            "lot_id": {"type": "integer", "description": "ID record stock.lot di Odoo.", "example": 101},
                            "batch_number": {"type": "string", "description": "Nomor identifikasi batch/lot.", "example": "BATCH-LIQ-202610-01"},
                            "received_date": {"type": "string", "format": "date", "nullable": True, "description": "Tanggal penerimaan barang di gudang.", "example": "2026-10-15"},
                            "expiration_date": {"type": "string", "format": "date", "nullable": True, "description": "Tanggal kedaluwarsa batch (null jika tanpa kedaluwarsa).", "example": "2027-04-15"},
                            "quantity": {"type": "number", "description": "Jumlah fisik stok batch pada lokasi internal.", "example": 10.0},
                            "expiration_status": {"type": "string", "enum": ["safe", "expiring_soon", "expired", "unknown"], "description": "Status kedaluwarsa batch.", "example": "safe"}
                        }
                    },
                    "InventoryProductItem": {
                        "type": "object",
                        "required": ["id", "sku", "name", "category", "quantity_on_hand", "uom", "purchase_price", "sale_price", "batches"],
                        "properties": {
                            "id": {"type": "integer", "description": "ID unik produk di Odoo.", "example": 93},
                            "sku": {"type": "string", "description": "SKU Internal Reference bahan laundry.", "example": "MAT-DET-002"},
                            "name": {"type": "string", "description": "Nama bahan laundry.", "example": "Deterjen Cair"},
                            "category": {"type": "string", "description": "Kategori bahan (`Bahan Laundry`).", "example": "Bahan Laundry"},
                            "quantity_on_hand": {"type": "number", "description": "Stok fisik aktual murni dari lokasi gudang internal Odoo.", "example": 25.0},
                            "uom": {"type": "string", "description": "Satuan ukuran bahan (kg, L).", "example": "L"},
                            "purchase_price": {"type": "number", "description": "Harga beli / Cost standar Odoo (standard_price). Bersifat rahasia internal dan dilarang untuk pelanggan.", "example": 18000.0},
                            "sale_price": {"type": "number", "description": "Harga jual jika relevan (list_price).", "example": 0.0},
                            "batches": {
                                "type": "array",
                                "description": "Rincian seluruh batch/lot yang tercatat untuk bahan ini.",
                                "items": {"$ref": "#/components/schemas/InventoryBatchItem"}
                            }
                        }
                    },
                    "InventoryListResponse": {
                        "type": "object",
                        "required": ["data"],
                        "properties": {
                            "data": {"type": "array", "items": {"$ref": "#/components/schemas/InventoryProductItem"}}
                        }
                    },
                    "InventoryDetailResponse": {
                        "type": "object",
                        "required": ["data"],
                        "properties": {
                            "data": {"$ref": "#/components/schemas/InventoryProductItem"}
                        }
                    },
                    "ServiceSpeedListResponse": {
                        "type": "object",
                        "required": ["success", "count", "data"],
                        "properties": {
                            "success": {"type": "boolean", "example": True},
                            "count": {"type": "integer", "example": 2},
                            "data": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "code": {"type": "string", "example": "same_day"},
                                        "name": {"type": "string", "example": "Same Day Service"},
                                        "available": {"type": "boolean", "example": True},
                                        "fee": {"type": "number", "example": 0.0},
                                        "description": {"type": "string", "example": "Pengerjaan prioritas selesai di hari yang sama"}
                                    }
                                }
                            }
                        }
                    },
                    "OrderLineInput": {
                        "type": "object",
                        "required": ["product_template_id"],
                        "properties": {
                            "product_template_id": {"type": "integer", "description": "ID unik produk layanan di Odoo.", "example": 12},
                            "quantity": {"type": "number", "description": "Jumlah pcs atau set (default: 1.0).", "example": 1.0},
                            "weight": {"type": "number", "description": "Berat cucian dalam kg untuk layanan kiloan.", "example": 3.0},
                            "length": {"type": "number", "description": "Panjang karpet dalam meter (wajib > 0 untuk karpet).", "example": 2.0},
                            "width": {"type": "number", "description": "Lebar karpet dalam meter (wajib > 0 untuk karpet).", "example": 3.0},
                            "item_details": {"type": "string", "description": "Catatan detail pakaian/barang.", "example": "Pakaian sehari-hari"}
                        }
                    },
                    "OrderCreateRequest": {
                        "type": "object",
                        "required": ["partner_id", "lines"],
                        "properties": {
                            "partner_id": {"type": "integer", "description": "ID pelanggan di Odoo (`res.partner`).", "example": 11},
                            "service_speed": {"type": "string", "enum": ["regular", "same_day"], "default": "regular", "example": "same_day"},
                            "notes": {"type": "string", "example": "Pesanan prioritas same day"},
                            "lines": {
                                "type": "array",
                                "description": "Daftar detail layanan yang dipesan (minimal 1 baris).",
                                "items": {"$ref": "#/components/schemas/OrderLineInput"}
                            }
                        }
                    },
                    "OrderCreateResponse": {
                        "type": "object",
                        "required": ["success", "message", "data"],
                        "properties": {
                            "success": {"type": "boolean", "example": True},
                            "message": {"type": "string", "example": "Pesanan berhasil dibuat."},
                            "data": {
                                "type": "object",
                                "properties": {
                                    "id": {"type": "integer", "example": 88},
                                    "name": {"type": "string", "example": "ORD/2026/00088"},
                                    "partner_id": {"type": "integer", "example": 11},
                                    "service_speed": {"type": "string", "example": "same_day"},
                                    "service_speed_fee": {"type": "number", "example": 0.0},
                                    "total_amount": {"type": "number", "example": 115000.0},
                                    "weight": {"type": "number", "example": 3.0},
                                    "state": {"type": "string", "example": "received"}
                                }
                            }
                        }
                    },
                    "OrderDetailResponse": {
                        "type": "object",
                        "required": ["success", "data"],
                        "properties": {
                            "success": {"type": "boolean", "example": True},
                            "data": {
                                "type": "object",
                                "properties": {
                                    "id": {"type": "integer", "example": 88},
                                    "name": {"type": "string", "example": "ORD/2026/00088"},
                                    "order_date": {"type": "string", "format": "date-time", "example": "2026-10-30T10:00:00Z"},
                                    "partner_id": {"type": "integer", "example": 11},
                                    "partner_name": {"type": "string", "example": "Rian Ardiansyah"},
                                    "service_speed": {"type": "string", "example": "same_day"},
                                    "service_speed_fee": {"type": "number", "example": 0.0},
                                    "weight": {"type": "number", "example": 3.0},
                                    "total_amount": {"type": "number", "example": 115000.0},
                                    "state": {"type": "string", "example": "received"},
                                    "notes": {"type": "string", "example": "Pesanan campur prioritas same day"},
                                    "lines": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "id": {"type": "integer", "example": 120},
                                                "product_id": {"type": "integer", "example": 12},
                                                "product_name": {"type": "string", "example": "Cuci Setrika"},
                                                "pricing_type": {"type": "string", "example": "weight"},
                                                "uom": {"type": "string", "example": "kg"},
                                                "weight": {"type": "number", "example": 3.0},
                                                "quantity": {"type": "number", "example": 3.0},
                                                "length": {"type": "number", "example": 0.0},
                                                "width": {"type": "number", "example": 0.0},
                                                "area": {"type": "number", "example": 0.0},
                                                "price_unit": {"type": "number", "example": 10000.0},
                                                "subtotal": {"type": "number", "example": 30000.0},
                                                "item_details": {"type": "string", "example": "Pakaian sehari-hari"}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    @http.route(
        ["/api/openapi.json", "/api/laundry/openapi.json", "/api/docs/openapi.json"],
        type="http",
        auth="none",
        methods=["GET", "OPTIONS"],
        csrf=False,
    )
    def openapi_spec(self, **kwargs):
        """Mengembalikan spesifikasi OpenAPI 3.0.3 dalam format JSON."""
        headers = {
            "Content-Type": "application/json; charset=utf-8",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Requested-With, X-Session-Id, X-Api-Key",
        }
        if request.httprequest.method == "OPTIONS":
            return Response(json.dumps({"status": "ok"}), status=200, headers=headers)

        base_url = getattr(request.httprequest, "host_url", None)
        spec = self._get_openapi_spec(base_url=base_url)
        return Response(
            json.dumps(spec, indent=2, ensure_ascii=False),
            status=200,
            headers=headers,
        )

    @http.route(
        ["/api/docs", "/api/laundry/docs", "/docs"],
        type="http",
        auth="none",
        methods=["GET"],
        csrf=False,
    )
    def scalar_docs(self, **kwargs):
        """Menampilkan halaman dokumentasi API interaktif menggunakan Scalar API Reference."""
        spec_url = "/api/openapi.json"
        scalar_config = json.dumps({
            "theme": "purple",
            "layout": "modern",
            "showSidebar": True,
            "hideDownloadButton": False,
            "metaData": {
                "title": "LaundryFlow API Documentation",
            },
        })
        html_content = f"""<!doctype html>
<html lang="id">
  <head>
    <title>LaundryFlow API Documentation — Scalar</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      body {{
        margin: 0;
        padding: 0;
      }}
    </style>
  </head>
  <body>
    <script
      id="api-reference"
      data-url="{spec_url}"
      data-configuration='{scalar_config}'
    ></script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  </body>
</html>
"""
        return Response(
            html_content,
            status=200,
            headers={
                "Content-Type": "text/html; charset=utf-8",
            },
        )
