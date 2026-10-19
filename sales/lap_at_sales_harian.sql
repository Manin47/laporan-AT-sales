-- =====================================================================
-- Procedure : lap_at_sales_harian
-- Untuk laporan Monitoring A/T Sales Harian (sales/Monitoring_AT_Sales).
-- (input_targetsales_detail_pengurang_v2 tetap jadi master data untuk report lain)
--
-- Contoh  : call lap_at_sales_harian('2026-08-05');
--
-- Hasil 1 baris per sales (semua lini bisnis dijumlah):
--  - target      : target bulan dari tgl dipilih -> 2026-08-05 = tahun 2026 kolom target08
--  - actual_hari : penjualan pada tgl dipilih saja (2026-08-05)
--  - actual      : penjualan tgl 1 s/d tgl dipilih (2026-08-01 s/d 2026-08-05)
--  - batal, retur: batal & retur tgl 1 s/d tgl dipilih
--  - tot         : actual - batal - retur
--  - at          : tot / target (rasio, x100 untuk %)
--  - deviasi     : tot - target
-- =====================================================================

DROP PROCEDURE IF EXISTS `lap_at_sales_harian`;

DELIMITER $$

CREATE DEFINER=`root`@`%` PROCEDURE `lap_at_sales_harian`(
    IN ctgl date)
BEGIN
    DECLARE ctahun int;
    DECLARE cbulan int;
    DECLARE ctgl1  date;

    SET ctahun = YEAR(ctgl);
    SET cbulan = MONTH(ctgl);
    SET ctgl1  = DATE_FORMAT(ctgl, '%Y-%m-01');

    DROP TEMPORARY TABLE IF EXISTS tjual, tretur, tbatal, ttarget, tkey;

-- Penjualan tgl 1 s/d tgl dipilih, per sales (actual_hari = khusus tgl dipilih)
    CREATE TEMPORARY TABLE tjual AS
        SELECT a.sales_id,
               SUM(b.subtotal) AS actual,
               SUM(IF(DATE(a.transaction_Date) = ctgl, b.subtotal, 0)) AS actual_hari
        FROM invitem_ppn b
        LEFT JOIN invheader_ppn a ON a.TransactionInv_id = b.TransactionInv_Id AND a.TransactionInv_id2 = b.TransactionInv_id2
        WHERE a.transaction_Date >= ctgl1
          AND a.transaction_Date <  ctgl + INTERVAL 1 DAY
        GROUP BY a.sales_id;

-- Retur (sudah approve) tgl 1 s/d tgl dipilih, per sales
    CREATE TEMPORARY TABLE tretur AS
        SELECT g.sales_id, SUM(b.subtotal) AS retur
        FROM returnitem_ppn b
        LEFT JOIN return_ppn a ON a.Return_id = b.Return_id
        LEFT JOIN invheader_ppn g ON g.TransactionInv_id = b.TransactionInv_Id
        WHERE a.transaction_Date >= ctgl1
          AND a.transaction_Date <  ctgl + INTERVAL 1 DAY
          AND b.approval = 1
        GROUP BY g.sales_id;

-- Batal tgl 1 s/d tgl dipilih (by tglbatal), per sales
    CREATE TEMPORARY TABLE tbatal AS
        SELECT a.sales_id, SUM(b.subtotal) AS batal
        FROM invitem_ppn b
        LEFT JOIN invheader_ppn a ON a.TransactionInv_id = b.TransactionInv_Id AND a.TransactionInv_id2 = b.TransactionInv_id2
        WHERE a.tglbatal >= ctgl1
          AND a.tglbatal <  ctgl + INTERVAL 1 DAY
          AND a.batal = 1
        GROUP BY a.sales_id;

-- Target tahun & bulan dari tgl dipilih, per sales (semua lini bisnis)
    CREATE TEMPORARY TABLE ttarget AS
        SELECT a.sales_id,
               SUM(CASE cbulan
                     WHEN  1 THEN IFNULL(a.target01,0) WHEN  2 THEN IFNULL(a.target02,0)
                     WHEN  3 THEN IFNULL(a.target03,0) WHEN  4 THEN IFNULL(a.target04,0)
                     WHEN  5 THEN IFNULL(a.target05,0) WHEN  6 THEN IFNULL(a.target06,0)
                     WHEN  7 THEN IFNULL(a.target07,0) WHEN  8 THEN IFNULL(a.target08,0)
                     WHEN  9 THEN IFNULL(a.target09,0) WHEN 10 THEN IFNULL(a.target10,0)
                     WHEN 11 THEN IFNULL(a.target11,0) ELSE IFNULL(a.target12,0)
                   END) AS target
        FROM trans_targetsales_detail a
        WHERE a.tahun = ctahun
        GROUP BY a.sales_id;

-- Kunci sales: yang punya target + yang ada transaksi
    CREATE TEMPORARY TABLE tkey AS
        SELECT sales_id FROM ttarget
        UNION
        SELECT sales_id FROM tjual
        UNION
        SELECT sales_id FROM tretur
        UNION
        SELECT sales_id FROM tbatal;

-- Hasil
    SELECT x.*,
           IF(x.target = 0, 0, x.tot / x.target) AS at,
           (x.tot - x.target)                    AS deviasi
    FROM (
        SELECT k.sales_id, s.sales_name,
               ctgl                     AS tanggal,
               ctahun                   AS tahun,
               cbulan                   AS bulan,
               IFNULL(t.target, 0)      AS target,
               IFNULL(j.actual_hari, 0) AS actual_hari,
               IFNULL(j.actual, 0)      AS actual,
               IFNULL(b.batal, 0)       AS batal,
               IFNULL(r.retur, 0)       AS retur,
               IFNULL(j.actual, 0) - IFNULL(b.batal, 0) - IFNULL(r.retur, 0) AS tot
        FROM tkey k
        LEFT JOIN ttarget t ON t.sales_id = k.sales_id
        LEFT JOIN tjual   j ON j.sales_id = k.sales_id
        LEFT JOIN tbatal  b ON b.sales_id = k.sales_id
        LEFT JOIN tretur  r ON r.sales_id = k.sales_id
        LEFT JOIN sales   s ON s.sales_id = k.sales_id
        WHERE IFNULL(t.target, 0) <> 0 OR IFNULL(j.actual, 0) <> 0
    ) x
    ORDER BY x.sales_name;

    DROP TEMPORARY TABLE IF EXISTS tjual, tretur, tbatal, ttarget, tkey;
END$$

DELIMITER ;
