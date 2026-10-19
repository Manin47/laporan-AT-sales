-- =====================================================================
-- Tabel : sales_hari_kerja
-- Jumlah hari kerja per tahun & bulan, untuk pembagi Target Daily
-- di laporan sales/Laporan_Sales_Lini (Target Daily = Target All / hari_kerja).
-- Jika tahun & bulan belum diisi di tabel ini, laporan pakai 22.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `sales_hari_kerja` (
  `id`         int(11)     NOT NULL AUTO_INCREMENT,
  `tahun`      int(4)      NOT NULL,
  `bulan`      int(2)      NOT NULL,
  `hari_kerja` int(2)      NOT NULL DEFAULT 22,
  `keterangan` varchar(255)         DEFAULT NULL,
  `created_at` datetime             DEFAULT CURRENT_TIMESTAMP,
  `created_by` varchar(50)          DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tahun_bulan` (`tahun`, `bulan`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Contoh isi (ubah sesuai kalender kerja):
-- INSERT INTO sales_hari_kerja (tahun, bulan, hari_kerja, keterangan) VALUES
--   (2026, 10, 22, 'Oktober 2026'),
--   (2026, 11, 21, 'November 2026')
-- ON DUPLICATE KEY UPDATE hari_kerja = VALUES(hari_kerja), keterangan = VALUES(keterangan);
