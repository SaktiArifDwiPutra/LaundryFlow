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
                    "### Mekanisme Autentikasi\n"
                    "Endpoint yang dilindungi memerlukan autentikasi pengguna Odoo yang valid (bukan *public user*). "
                    "Anda dapat melakukan autentikasi melalui salah satu cara berikut:\n"
                    "1. **Bearer Token**: Header `Authorization: Bearer <session_id>`\n"
                    "2. **Token Header**: Header `Authorization: Token <session_id>`\n"
                    "3. **Session Header**: Header `X-Session-Id: <session_id>`\n"
                    "4. **API Key Header**: Header `X-Api-Key: <api_key>`\n"
                    "5. **Query Parameter**: `?session_id=<session_id>` atau `?api_key=<api_key>`\n"
                    "6. **Cookie Session Odoo**: Cookie `session_id` aktif dari sesi HTTP Odoo.\n\n"
                    "Gunakan endpoint **POST `/api/laundry/auth/login`** terlebih dahulu untuk mendapatkan `session_id`."
                ),
                "contact": {
                    "name": "LaundryFlow Team",
                },
                "license": {
                    "name": "LGPL-3.0",
                    "url": "https://www.gnu.org/licenses/lgpl-3.0.html",
                },
            },
            "servers": servers,
            "tags": [
                {
                    "name": "Authentication",
                    "description": "Autentikasi pengguna dan pembuatan sesi akses API.",
                },
                {
                    "name": "Customers",
                    "description": "Pencarian dan penambahan data pelanggan LaundryFlow (`res.partner`).",
                },
            ],
            "paths": {
                "/api/laundry/auth/login": {
                    "post": {
                        "tags": ["Authentication"],
                        "summary": "Login Pengguna",
                        "operationId": "loginUser",
                        "description": (
                            "Melakukan autentikasi pengguna menggunakan kredensial Odoo dan mengembalikan `session_id` "
                            "yang dapat dipakai sebagai Bearer Token atau `X-Session-Id` pada endpoint lain.\n\n"
                            "**Route Alias yang Didukung:**\n"
                            "- `POST /api/laundry/auth/login`\n"
                            "- `POST /api/auth/login`"
                        ),
                        "security": [],
                        "requestBody": {
                            "required": True,
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "$ref": "#/components/schemas/LoginRequest",
                                    },
                                    "examples": {
                                        "loginWithLoginField": {
                                            "summary": "Login dengan field login",
                                            "value": {
                                                "login": "user@example.com",
                                                "password": "your_password_here",
                                                "db": "odoo20",
                                            },
                                        },
                                        "loginWithUsernameField": {
                                            "summary": "Login dengan field username",
                                            "value": {
                                                "username": "user@example.com",
                                                "password": "your_password_here",
                                            },
                                        },
                                    },
                                }
                            },
                        },
                        "responses": {
                            "200": {
                                "description": "Login berhasil dan mengembalikan informasi sesi pengguna.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/LoginResponse",
                                        },
                                        "example": {
                                            "success": True,
                                            "message": "Login berhasil",
                                            "data": {
                                                "uid": 2,
                                                "name": "Mitchell Admin",
                                                "username": "user@example.com",
                                                "session_id": "<session_id_token>",
                                            },
                                        },
                                    }
                                },
                            },
                            "400": {
                                "description": "Username atau password tidak disertakan dalam request body.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "example": {
                                            "success": False,
                                            "message": "Username dan password wajib diisi",
                                        },
                                    }
                                },
                            },
                            "401": {
                                "description": "Kredensial tidak valid atau autentikasi gagal.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "examples": {
                                            "invalidCredentials": {
                                                "summary": "Username atau password salah",
                                                "value": {
                                                    "success": False,
                                                    "message": "Username atau password salah",
                                                },
                                            },
                                            "authFailed": {
                                                "summary": "Autentikasi gagal",
                                                "value": {
                                                    "success": False,
                                                    "message": "Autentikasi gagal",
                                                },
                                            },
                                        },
                                    }
                                },
                            },
                        },
                    }
                },
                "/api/laundry/customers/search": {
                    "get": {
                        "tags": ["Customers"],
                        "summary": "Cari Pelanggan (Customer Search)",
                        "operationId": "searchCustomers",
                        "description": (
                            "Mencari pelanggan aktif (`res.partner` dengan `active = True`) berdasarkan nama (`name`) "
                            "atau nomor telepon (`phone`) secara *case-insensitive* (`ilike`).\n\n"
                            "Hasil diurutkan berdasarkan `name asc` dan hanya mengembalikan field kontak pelanggan "
                            "(`id`, `name`, `phone`, `email`, `street`, `city`) tanpa mengekspos data internal atau sensitif.\n\n"
                            "**Route Alias yang Didukung:**\n"
                            "- `GET /api/laundry/customers/search`\n"
                            "- `GET /api/customers/search`"
                        ),
                        "security": [
                            {"BearerAuth": []},
                            {"SessionHeaderAuth": []},
                            {"ApiKeyHeaderAuth": []},
                        ],
                        "parameters": [
                            {
                                "name": "q",
                                "in": "query",
                                "required": True,
                                "description": (
                                    "Kata kunci pencarian untuk nama atau nomor telepon pelanggan "
                                    "(wajib diisi, tidak boleh kosong atau hanya spasi). "
                                    "Endpoint juga menerima alias parameter `query`."
                                ),
                                "schema": {
                                    "type": "string",
                                    "minLength": 1,
                                },
                                "examples": {
                                    "byName": {
                                        "summary": "Cari berdasarkan nama",
                                        "value": "Budi",
                                    },
                                    "byPhone": {
                                        "summary": "Cari berdasarkan nomor telepon",
                                        "value": "0812",
                                    },
                                },
                            },
                            {
                                "name": "limit",
                                "in": "query",
                                "required": False,
                                "description": (
                                    "Batas jumlah hasil pencarian yang dikembalikan. "
                                    "Default adalah `20`, nilai harus `> 0`, dan nilai di atas `50` akan otomatis dibatasi menjadi `50`."
                                ),
                                "schema": {
                                    "type": "integer",
                                    "default": 20,
                                    "minimum": 1,
                                    "maximum": 50,
                                },
                                "example": 20,
                            },
                        ],
                        "responses": {
                            "200": {
                                "description": "Pencarian berhasil dilakukan.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/CustomerSearchResponse",
                                        },
                                        "examples": {
                                            "found": {
                                                "summary": "Pelanggan ditemukan",
                                                "value": {
                                                    "success": True,
                                                    "count": 2,
                                                    "data": [
                                                        {
                                                            "id": 14,
                                                            "name": "Budi Santoso",
                                                            "phone": "081234567890",
                                                            "email": "budi@example.com",
                                                            "street": "Jl. Merdeka No. 10",
                                                            "city": "Jakarta",
                                                        },
                                                        {
                                                            "id": 19,
                                                            "name": "Budi Raharjo",
                                                            "phone": "081298765432",
                                                            "email": "",
                                                            "street": "Jl. Sudirman No. 22",
                                                            "city": "Bandung",
                                                        },
                                                    ],
                                                },
                                            },
                                            "empty": {
                                                "summary": "Tidak ada pelanggan yang cocok",
                                                "value": {
                                                    "success": True,
                                                    "count": 0,
                                                    "data": [],
                                                },
                                            },
                                        },
                                    }
                                },
                            },
                            "400": {
                                "description": "Parameter pencarian `q` kosong atau parameter `limit` tidak valid.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "examples": {
                                            "missingQuery": {
                                                "summary": "Parameter q tidak diisi atau kosong",
                                                "value": {
                                                    "success": False,
                                                    "message": "Parameter pencarian (q) wajib diisi",
                                                },
                                            },
                                            "negativeLimit": {
                                                "summary": "Parameter limit <= 0",
                                                "value": {
                                                    "success": False,
                                                    "message": "Parameter limit harus lebih besar dari 0",
                                                },
                                            },
                                            "invalidLimitType": {
                                                "summary": "Parameter limit bukan angka",
                                                "value": {
                                                    "success": False,
                                                    "message": "Parameter limit harus berupa angka yang valid",
                                                },
                                            },
                                        },
                                    }
                                },
                            },
                            "401": {
                                "description": "Permintaan belum terautentikasi atau token tidak valid.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "example": {
                                            "success": False,
                                            "message": "Autentikasi diperlukan. Akses tidak diizinkan.",
                                        },
                                    }
                                },
                            },
                            "403": {
                                "description": "Pengguna terautentikasi tetapi tidak memiliki hak akses baca (`read`) pada `res.partner`.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "example": {
                                            "success": False,
                                            "message": "Akses ditolak: Anda tidak memiliki izin untuk melihat data pelanggan.",
                                        },
                                    }
                                },
                            },
                            "500": {
                                "description": "Kesalahan internal pada server.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "example": {
                                            "success": False,
                                            "message": "Terjadi kesalahan internal pada server",
                                        },
                                    }
                                },
                            },
                        },
                    }
                },
                "/api/laundry/customers": {
                    "post": {
                        "tags": ["Customers"],
                        "summary": "Tambah Pelanggan Baru (Customer Creation)",
                        "operationId": "createCustomer",
                        "description": (
                            "Membuat data pelanggan baru pada model `res.partner` dengan `customer_rank = 1`.\n\n"
                            "Field `name` dan `phone` wajib diisi. Field `street` (atau alias `address`), `email`, dan `city` bersifat opsional.\n\n"
                            "**Route Alias yang Didukung:**\n"
                            "- `POST /api/laundry/customers`\n"
                            "- `POST /api/customers`\n"
                            "- `POST /api/laundry/customers/create`\n"
                            "- `POST /api/customers/create`"
                        ),
                        "security": [
                            {"BearerAuth": []},
                            {"SessionHeaderAuth": []},
                            {"ApiKeyHeaderAuth": []},
                        ],
                        "requestBody": {
                            "required": True,
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "$ref": "#/components/schemas/CustomerCreateRequest",
                                    },
                                    "examples": {
                                        "fullCustomer": {
                                            "summary": "Data pelanggan lengkap",
                                            "value": {
                                                "name": "Test Pelanggan",
                                                "phone": "08551234567",
                                                "address": "Jl. Kenanga No. 5",
                                                "email": "pelanggan@test.com",
                                                "city": "Surabaya",
                                            },
                                        },
                                        "minimalCustomer": {
                                            "summary": "Data pelanggan minimal (wajib saja)",
                                            "value": {
                                                "name": "Ahmad Fauzi",
                                                "phone": "081311223344",
                                            },
                                        },
                                    },
                                }
                            },
                        },
                        "responses": {
                            "201": {
                                "description": "Pelanggan baru berhasil dibuat.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/CustomerCreateResponse",
                                        },
                                        "example": {
                                            "success": True,
                                            "message": "Pelanggan berhasil ditambahkan",
                                            "data": {
                                                "id": 45,
                                                "name": "Test Pelanggan",
                                                "phone": "08551234567",
                                                "email": "pelanggan@test.com",
                                                "street": "Jl. Kenanga No. 5",
                                                "city": "Surabaya",
                                                "address": "Jl. Kenanga No. 5",
                                            },
                                        },
                                    }
                                },
                            },
                            "400": {
                                "description": "Request body tidak valid atau field wajib (`name`, `phone`) tidak diisi.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "examples": {
                                            "missingName": {
                                                "summary": "Field name kosong / tidak diisi",
                                                "value": {
                                                    "success": False,
                                                    "message": "Field name wajib diisi",
                                                },
                                            },
                                            "missingPhone": {
                                                "summary": "Field phone kosong / tidak diisi",
                                                "value": {
                                                    "success": False,
                                                    "message": "Field phone wajib diisi",
                                                },
                                            },
                                            "emptyBody": {
                                                "summary": "Request body kosong",
                                                "value": {
                                                    "success": False,
                                                    "message": "Request body tidak boleh kosong dan harus berupa objek JSON",
                                                },
                                            },
                                            "invalidJson": {
                                                "summary": "Format JSON tidak valid",
                                                "value": {
                                                    "success": False,
                                                    "message": "Format request tidak valid, data harus berformat JSON",
                                                },
                                            },
                                        },
                                    }
                                },
                            },
                            "401": {
                                "description": "Permintaan belum terautentikasi atau token tidak valid.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "example": {
                                            "success": False,
                                            "message": "Autentikasi diperlukan. Akses tidak diizinkan.",
                                        },
                                    }
                                },
                            },
                            "403": {
                                "description": "Pengguna terautentikasi tetapi tidak memiliki hak akses buat (`create`) pada `res.partner`.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "example": {
                                            "success": False,
                                            "message": "Akses ditolak: Anda tidak memiliki izin untuk membuat data pelanggan.",
                                        },
                                    }
                                },
                            },
                            "500": {
                                "description": "Kesalahan internal pada server.",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "$ref": "#/components/schemas/ErrorResponse",
                                        },
                                        "example": {
                                            "success": False,
                                            "message": "Terjadi kesalahan internal pada server",
                                        },
                                    }
                                },
                            },
                        },
                    }
                },
            },
            "components": {
                "securitySchemes": {
                    "BearerAuth": {
                        "type": "http",
                        "scheme": "bearer",
                        "description": "Gunakan `session_id` hasil login pada header `Authorization: Bearer <session_id>`.",
                    },
                    "SessionHeaderAuth": {
                        "type": "apiKey",
                        "in": "header",
                        "name": "X-Session-Id",
                        "description": "Gunakan `session_id` hasil login pada header `X-Session-Id`.",
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
                            "login": {
                                "type": "string",
                                "description": "Username atau email login pengguna Odoo (wajib jika `username` tidak diisi).",
                                "example": "user@example.com",
                            },
                            "username": {
                                "type": "string",
                                "description": "Alias alternatif untuk field `login`.",
                                "example": "user@example.com",
                            },
                            "password": {
                                "type": "string",
                                "format": "password",
                                "description": "Kata sandi pengguna Odoo (wajib).",
                                "example": "your_password_here",
                            },
                            "db": {
                                "type": "string",
                                "description": "Nama database Odoo (opsional, default: `odoo20`).",
                                "default": "odoo20",
                                "example": "odoo20",
                            },
                        },
                    },
                    "LoginResponse": {
                        "type": "object",
                        "required": ["success", "message", "data"],
                        "properties": {
                            "success": {
                                "type": "boolean",
                                "example": True,
                            },
                            "message": {
                                "type": "string",
                                "example": "Login berhasil",
                            },
                            "data": {
                                "type": "object",
                                "required": ["uid", "name", "username", "session_id"],
                                "properties": {
                                    "uid": {
                                        "type": "integer",
                                        "description": "ID record pengguna (`res.users`).",
                                        "example": 2,
                                    },
                                    "name": {
                                        "type": "string",
                                        "description": "Nama lengkap pengguna.",
                                        "example": "Mitchell Admin",
                                    },
                                    "username": {
                                        "type": "string",
                                        "description": "Username/login pengguna.",
                                        "example": "user@example.com",
                                    },
                                    "session_id": {
                                        "type": "string",
                                        "description": "Session ID aktif untuk autentikasi request selanjutnya.",
                                        "example": "<session_id_token>",
                                    },
                                },
                            },
                        },
                    },
                    "CustomerSearchItem": {
                        "type": "object",
                        "required": ["id", "name", "phone", "email", "street", "city"],
                        "properties": {
                            "id": {
                                "type": "integer",
                                "description": "ID unik record pelanggan (`res.partner`).",
                                "example": 14,
                            },
                            "name": {
                                "type": "string",
                                "description": "Nama pelanggan.",
                                "example": "Budi Santoso",
                            },
                            "phone": {
                                "type": "string",
                                "description": "Nomor telepon pelanggan.",
                                "example": "081234567890",
                            },
                            "email": {
                                "type": "string",
                                "description": "Alamat email pelanggan (string kosong jika belum diisi).",
                                "example": "budi@example.com",
                            },
                            "street": {
                                "type": "string",
                                "description": "Alamat jalan pelanggan (string kosong jika belum diisi).",
                                "example": "Jl. Merdeka No. 10",
                            },
                            "city": {
                                "type": "string",
                                "description": "Kota pelanggan (string kosong jika belum diisi).",
                                "example": "Jakarta",
                            },
                        },
                    },
                    "CustomerSearchResponse": {
                        "type": "object",
                        "required": ["success", "count", "data"],
                        "properties": {
                            "success": {
                                "type": "boolean",
                                "example": True,
                            },
                            "count": {
                                "type": "integer",
                                "description": "Jumlah pelanggan yang dikembalikan pada `data`.",
                                "example": 1,
                            },
                            "data": {
                                "type": "array",
                                "items": {
                                    "$ref": "#/components/schemas/CustomerSearchItem",
                                },
                            },
                        },
                    },
                    "CustomerCreateRequest": {
                        "type": "object",
                        "required": ["name", "phone"],
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Nama lengkap pelanggan (wajib, tidak boleh kosong).",
                                "example": "Test Pelanggan",
                            },
                            "phone": {
                                "type": "string",
                                "description": "Nomor telepon pelanggan (wajib, tidak boleh kosong).",
                                "example": "08551234567",
                            },
                            "street": {
                                "type": "string",
                                "description": "Alamat jalan pelanggan (opsional, alternatif dari `address`).",
                                "example": "Jl. Kenanga No. 5",
                            },
                            "address": {
                                "type": "string",
                                "description": "Alias untuk alamat jalan pelanggan (`street`, opsional).",
                                "example": "Jl. Kenanga No. 5",
                            },
                            "email": {
                                "type": "string",
                                "description": "Alamat email pelanggan (opsional).",
                                "example": "pelanggan@test.com",
                            },
                            "city": {
                                "type": "string",
                                "description": "Nama kota pelanggan (opsional).",
                                "example": "Surabaya",
                            },
                        },
                    },
                    "CustomerCreatedItem": {
                        "type": "object",
                        "required": ["id", "name", "phone", "email", "street", "city", "address"],
                        "properties": {
                            "id": {
                                "type": "integer",
                                "description": "ID unik pelanggan yang baru dibuat (`res.partner`).",
                                "example": 45,
                            },
                            "name": {
                                "type": "string",
                                "description": "Nama pelanggan.",
                                "example": "Test Pelanggan",
                            },
                            "phone": {
                                "type": "string",
                                "description": "Nomor telepon pelanggan.",
                                "example": "08551234567",
                            },
                            "email": {
                                "type": "string",
                                "description": "Alamat email pelanggan.",
                                "example": "pelanggan@test.com",
                            },
                            "street": {
                                "type": "string",
                                "description": "Alamat jalan pelanggan.",
                                "example": "Jl. Kenanga No. 5",
                            },
                            "city": {
                                "type": "string",
                                "description": "Kota pelanggan.",
                                "example": "Surabaya",
                            },
                            "address": {
                                "type": "string",
                                "description": "Alamat jalan pelanggan (bernilai sama dengan `street`).",
                                "example": "Jl. Kenanga No. 5",
                            },
                        },
                    },
                    "CustomerCreateResponse": {
                        "type": "object",
                        "required": ["success", "message", "data"],
                        "properties": {
                            "success": {
                                "type": "boolean",
                                "example": True,
                            },
                            "message": {
                                "type": "string",
                                "example": "Pelanggan berhasil ditambahkan",
                            },
                            "data": {
                                "$ref": "#/components/schemas/CustomerCreatedItem",
                            },
                        },
                    },
                    "ErrorResponse": {
                        "type": "object",
                        "required": ["success", "message"],
                        "properties": {
                            "success": {
                                "type": "boolean",
                                "example": False,
                            },
                            "message": {
                                "type": "string",
                                "description": "Pesan kesalahan yang menjelaskan penyebab kegagalan request.",
                                "example": "Autentikasi diperlukan. Akses tidak diizinkan.",
                            },
                        },
                    },
                },
            },
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

