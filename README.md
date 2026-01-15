# Habit Hero 🛡️🎮

Aplikasi Habit Hero adalah aplikasi _to-do activity_ bertema gamifikasi ala Habitica.  
Pengguna bisa mencatat kebiasaan (Habit), tugas harian (Daily), dan to-do biasa (To-Do), lalu mendapatkan XP, Gold, dan menjaga HP layaknya karakter game RPG.

---

## 1. Anggota Tim

- Muhammad Luthfi – NIM: `2310120011`

---

## 2. Pembagian Tugas Antar Anggota

-Anggota 1 
  - Mendesain tampilan Login Page dan Home Page
  - Implementasi layout `Scaffold`, `AppBar`, `Card`, `ListView`, `Dialog`, dan komponen UI dasar Flutter
  - Membuat komponen list item task (ListTile, IconButton, ChoiceChip, dsb.)
  - Mengatur logika XP, Gold, HP, Level
  - Implementasi filter task (`Habit`, `Daily`, `To-Do`) dengan `TaskFilter` dan `ChoiceChip`
  - Mengatur perilaku tombol (habit positif/negatif, centang selesai, hapus task, end day / reset daily)
  - Implementasi SQLite (sqflite) untuk CRUD task
  - Implementasi SharedPreferences untuk menyimpan data terakhir (XP, Gold, HP, Filter, Tema, dan Username)
  - Menghubungkan data SQLite dan SharedPreferences dengan UI (load saat startup, simpan saat data berubah)

---

## 3. Penjelasan Fitur Login

- Aplikasi membuka dengan Login Page sederhana.
- Pengguna cukup memasukkan nama pengguna (username) pada `TextFormField`.
- Setelah klik tombol "Masuk":
  - Nama pengguna disimpan ke SharedPreferences dengan key, misalnya: `habithero_user_name`.
  - Setelah tersimpan, halaman akan berpindah ke Home Page Habit Hero.
- Pada AppBar di halaman utama tersedia tombol Logout yang:
  - Menghapus data username dari SharedPreferences.
  - Mengembalikan aplikasi ke Login Page.

> Fitur login ini tidak menggunakan autentikasi server, melainkan hanya menyimpan nama pengguna lokal untuk memenuhi spesifikasi tugas.

---

## 4. Penjelasan Fitur Light/Dark Mode

- Aplikasi menggunakan ThemeMode di root `MaterialApp`:
  - `theme`  → untuk Light Mode
  - `darkTheme` → untuk Dark Mode
  - `themeMode` → diatur berdasarkan preferensi pengguna
- Status apakah saat ini dark mode aktif atau tidak disimpan di SharedPreferences dengan key seperti:
  - `habithero_theme_dark = true/false`
-Tombol toggle tema:
  - Ada di AppBar Login Page dan AppBar Home Page.
  - Ikon:
    - `Icons.dark_mode` → untuk mengaktifkan Dark Mode
    - `Icons.light_mode` → untuk kembali ke Light Mode
- Ketika user mengganti tema:
  - Nilai boolean `isDarkMode` diubah.
  - Disimpan ke SharedPreferences.
  - `setState` memicu rebuild, sehingga tampilan aplikasi langsung berubah sesuai tema terbaru.
- Saat aplikasi dibuka kembali:
  - Aplikasi membaca nilai `habithero_theme_dark` dari SharedPreferences.
  - Tema terakhir yang dipilih pengguna otomatis diterapkan.

---

## 5. Penjelasan Implementasi SQLite & SharedPreferences

### a. SQLite (sqflite) – CRUD Data Task

- Menggunakan package: `sqflite` dan `path`.
- Dibuat helper class, misalnya: `TaskDatabase`, dengan fungsi:
  - `getAllTasks()` → mengambil semua task dari tabel `tasks`.
  - `insertTask(TodoTask task)` → menyimpan task baru.
  - `updateTask(TodoTask task)` → mengubah data task (misalnya status `is_done`).
  - `deleteTask(int id)` → menghapus task berdasarkan `id`.
- Struktur tabel `tasks`:

  | Kolom       | Tipe    | Keterangan                        |
  |------------|---------|------------------------------------|
  | id         | INTEGER | PRIMARY KEY AUTOINCREMENT         |
  | title      | TEXT    | Judul task                        |
  | type       | INTEGER | 0 = Habit, 1 = Daily, 2 = To-Do   |
  | difficulty | INTEGER | 0 = Mudah, 1 = Sedang, 2 = Sulit  |
  | is_done    | INTEGER | 0 = belum selesai, 1 = sudah      |

- Saat aplikasi dibuka:
  - `getAllTasks()` dipanggil untuk mengisi List in-memory `_tasks` di `State`.
- Saat menambah, mengedit status selesai, atau menghapus task:
  - Operasi dilakukan ke database (insert/update/delete).
  - Setelah sukses, List in-memory diperbarui dan UI direbuild.

### b. SharedPreferences – Menyimpan Data Terakhir

Aplikasi menggunakan SharedPreferences untuk menyimpan:

-Statistik pemain:
  - `habithero_xp` → total XP.
  - `habithero_gold` → jumlah Gold.
  - `habithero_hp` → HP karakter (0–100).
-Pengaturan:
  - `habithero_theme_dark` → `true` jika Dark Mode, `false` jika Light Mode.
  - `habithero_filter` → index filter terbaru (All / Habit / Daily / To-Do).
  - `habithero_user_name` → nama pengguna yang terakhir login.

Tujuan:

- Saat aplikasi ditutup dan dibuka lagi, **XP, Gold, HP, Filter, Tema, dan Username** tetap tersimpan dan digunakan untuk mengembalikan state terakhir aplikasi.


