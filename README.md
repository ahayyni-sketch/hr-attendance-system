# ATTENDIX — Supabase + Vercel

Aplikasi ini menggunakan HTML/CSS/JavaScript dan Supabase Auth, Database, serta Storage. Tidak memerlukan build step.

## Isi ZIP
- `index.html` — aplikasi ATTENDIX.
- `js/supabase-config.js` — URL dan Publishable Key Supabase.
- `supabase/migrations/001_attendix_schema.sql` — skema database, trigger pendaftaran, RLS, dan bucket foto.
- `vercel.json` — konfigurasi hosting SPA/static.
- `README.md` — petunjuk instalasi.

## 1. Siapkan Supabase
1. Buka project Supabase yang sudah dibuat.
2. Masuk ke **SQL Editor**.
3. Buka file `supabase/migrations/001_attendix_schema.sql` dari ZIP ini.
4. Salin seluruh isinya ke SQL Editor lalu tekan **Run**.
5. Pada bagian paling bawah SQL, ganti `Perusahaan Anda` dan `ATTENDIX-DAFTAR-001` dengan nama perusahaan serta kode undangan rahasia yang akan dibagikan kepada karyawan. Jika SQL sudah dijalankan, ubah data perusahaan melalui Table Editor > companies.
6. Buka **Authentication > Providers > Email**. Tentukan apakah konfirmasi email akan diaktifkan. Jika aktif, karyawan harus mengonfirmasi email sebelum login.
7. Pastikan URL aplikasi Vercel ditambahkan ke **Authentication > URL Configuration > Redirect URLs** jika memakai konfirmasi email.

## 2. Deploy ke GitHub dan Vercel
1. Ekstrak ZIP.
2. Upload semua isi folder `ATTENDIX-Supabase-Ready` ke repository GitHub (file `index.html` harus berada di root repository).
3. Import repository tersebut di Vercel.
4. Framework preset: **Other**. Build command dan Output Directory dapat dikosongkan; root directory `./`.
5. Deploy. Setelah selesai, buka URL Vercel.

## 3. Cara penggunaan
- Pengguna baru memilih **Daftar Akun Karyawan**.
- Isi nama, NIP, divisi, jabatan, email, password, dan kode perusahaan.
- Kode perusahaan harus cocok dengan `companies.join_code`.
- Trigger database membuat profil karyawan dan menghubungkannya ke perusahaan secara otomatis.
- Setelah login, aplikasi memuat profil serta riwayat presensi milik akun tersebut.

## Keamanan penting
- `sb_publishable_...` adalah kunci publik dan boleh ada di frontend. Jangan pernah memasukkan `service_role` atau secret key ke ZIP/GitHub.
- RLS membatasi profil dan presensi karyawan ke akun pemiliknya. Akses data lintas karyawan/perusahaan untuk HR/Admin memerlukan role dan policy tambahan yang dirancang terpisah.
- Bucket foto presensi dibuat private. Foto hanya dapat dibaca oleh pemilik akun.
- Kode perusahaan adalah kode undangan, bukan password administrator. Bagikan hanya kepada karyawan yang berhak.
- Pengaturan radius geofence sudah disimpan di database, tetapi validasi jarak server-side dan dashboard HR/Admin belum diaktifkan pada versi integrasi ini. Jangan anggap geofencing sebagai kontrol keamanan final.
- Periksa kebijakan RLS dan lakukan uji akun lintas perusahaan sebelum digunakan untuk data kehadiran produksi.

## Batas implementasi versi ini
Login, registrasi, asosiasi perusahaan, profil dasar, riwayat presensi, foto check-in/check-out, dan penyimpanan Supabase sudah diintegrasikan. Beberapa modul pada prototipe lama (mis. persetujuan cuti/lembur, direktori tim lintas karyawan, kalender bersama, dan laporan HR) masih berupa tampilan/prototipe dan belum menjadi workflow database multi-role. Data demo tidak dipakai sebagai data akun aktif.
