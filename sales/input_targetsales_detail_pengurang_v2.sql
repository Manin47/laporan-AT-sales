-- =====================================================================
-- Procedure : input_targetsales_detail_pengurang_v2
-- Versi per TANGGAL dari Input_TargetSales_Detail_Pengurang (per bulan).
--
-- Contoh  : call input_targetsales_detail_pengurang_v2('2026-08-01','2026-08-15');
--
-- Bedanya dengan versi lama:
--  - parameter range tanggal (ctgl1, ctgl2), bukan tahun & bulan.
--  - actual dihitung langsung dari transaksi di range tanggal itu,
--    TIDAK meng-update kolom actual01..12 di trans_targetsales_detail
--    (kolom itu tetap milik procedure bulanan, supaya tidak tertimpa angka sebagian bulan).
--  - TIDAK insert ke trans_targetsales_detail (procedure ini hanya baca/laporan).
--  - target = jumlah target bulan-bulan yang masuk range (tahun dari ctgl1).
--    Contoh range 01-08 s/d 15-08 -> target08 (target 1 bulan penuh).
--  - kolom hasil sama dengan versi lama + tot & ar2:
--    id, sales_id, sales_name, linibisnis_id, linibisnis_name, tahun,
--    target, actual, batal, retur, ar, batalx, returx, tot, ar2,
--    target01..target12 (target per bulan, tahun ctgl1)
--    baris TOTAL per sales: linibisnis_id = 'XX', linibisnis_name = 'TOTAL'.
-- =====================================================================

DROP PROCEDURE IF EXISTS `input_targetsales_detail_pengurang_v2`;

DELIMITER $$

CREATE DEFINER=`root`@`%` PROCEDURE `input_targetsales_detail_pengurang_v2`(
    IN ctgl1 date,
    IN ctgl2 date)
BEGIN
    DECLARE ctahun int;
    DECLARE cbln1  int;
    DECLARE cbln2  int;

    SET ctahun = YEAR(ctgl1);
    SET cbln1  = MONTH(ctgl1);
    -- range beda tahun: target dihitung sampai Desember tahun ctgl1
    SET cbln2  = IF(YEAR(ctgl2) > ctahun, 12, MONTH(ctgl2));

    DROP TEMPORARY TABLE IF EXISTS tB0, tB2, tretur, tbatal, tkey, ttarget, targettemp, tbs, trs, ttotal;

-- Ambil data transaksi penjualan (per tanggal)
    CREATE TEMPORARY TABLE tB0 AS
        SELECT a.sales_id, e.linibisnis_id, b.subtotal AS Total_Netto
        FROM invitem_ppn b
        LEFT JOIN invheader_ppn a ON a.TransactionInv_id = b.TransactionInv_Id AND a.TransactionInv_id2 = b.TransactionInv_id2
        LEFT JOIN product e ON b.Plu = e.Plu
        WHERE a.transaction_Date >= ctgl1
          AND a.transaction_Date <  ctgl2 + INTERVAL 1 DAY;

-- Ambil data retur (per tanggal retur, yang sudah approve)
    CREATE TEMPORARY TABLE tretur AS
        SELECT g.sales_id, e.linibisnis_id, SUM(b.subtotal) AS Total_Netto
        FROM returnitem_ppn b
        LEFT JOIN return_ppn a ON a.Return_id = b.Return_id
        LEFT JOIN invheader_ppn g ON g.TransactionInv_id = b.TransactionInv_Id
        LEFT JOIN product e ON b.Plu = e.Plu
        WHERE a.transaction_Date >= ctgl1
          AND a.transaction_Date <  ctgl2 + INTERVAL 1 DAY
          AND b.approval = 1
        GROUP BY g.sales_id, e.linibisnis_id;

-- Ambil data pembatalan (per tanggal batal)
    CREATE TEMPORARY TABLE tbatal AS
        SELECT a.sales_id, e.linibisnis_id, SUM(b.subtotal) AS Total_Netto
        FROM invitem_ppn b
        LEFT JOIN invheader_ppn a ON a.TransactionInv_id = b.TransactionInv_Id AND a.TransactionInv_id2 = b.TransactionInv_id2
        LEFT JOIN product e ON b.Plu = e.Plu
        WHERE a.tglbatal >= ctgl1
          AND a.tglbatal <  ctgl2 + INTERVAL 1 DAY
          AND a.batal = 1
        GROUP BY a.sales_id, e.linibisnis_id;

-- Rekap per sales & lini bisnis
    CREATE TEMPORARY TABLE tB2 AS
        SELECT tB0.sales_id, tB0.linibisnis_id,
               COALESCE(tr.Total_Netto, 0) AS Retur,
               COALESCE(bt.Total_Netto, 0) AS Batal,
               SUM(tB0.Total_Netto) AS Total_Netto
        FROM tB0
        LEFT JOIN tretur tr ON tr.sales_id = tB0.sales_id AND tr.linibisnis_id = tB0.linibisnis_id
        LEFT JOIN tbatal bt ON bt.sales_id = tB0.sales_id AND bt.linibisnis_id = tB0.linibisnis_id
        GROUP BY tB0.sales_id, tB0.linibisnis_id;
    ALTER TABLE tB2 ADD INDEX (sales_id, linibisnis_id);

-- Target per sales & lini bisnis = jumlah target bulan cbln1..cbln2
    CREATE TEMPORARY TABLE ttarget AS
        SELECT a.id, a.sales_id, a.linibisnis_id,
               IF( 1 BETWEEN cbln1 AND cbln2, IFNULL(a.target01,0), 0)
             + IF( 2 BETWEEN cbln1 AND cbln2, IFNULL(a.target02,0), 0)
             + IF( 3 BETWEEN cbln1 AND cbln2, IFNULL(a.target03,0), 0)
             + IF( 4 BETWEEN cbln1 AND cbln2, IFNULL(a.target04,0), 0)
             + IF( 5 BETWEEN cbln1 AND cbln2, IFNULL(a.target05,0), 0)
             + IF( 6 BETWEEN cbln1 AND cbln2, IFNULL(a.target06,0), 0)
             + IF( 7 BETWEEN cbln1 AND cbln2, IFNULL(a.target07,0), 0)
             + IF( 8 BETWEEN cbln1 AND cbln2, IFNULL(a.target08,0), 0)
             + IF( 9 BETWEEN cbln1 AND cbln2, IFNULL(a.target09,0), 0)
             + IF(10 BETWEEN cbln1 AND cbln2, IFNULL(a.target10,0), 0)
             + IF(11 BETWEEN cbln1 AND cbln2, IFNULL(a.target11,0), 0)
             + IF(12 BETWEEN cbln1 AND cbln2, IFNULL(a.target12,0), 0) AS target,
               IFNULL(a.target01,0) AS target01, IFNULL(a.target02,0) AS target02,
               IFNULL(a.target03,0) AS target03, IFNULL(a.target04,0) AS target04,
               IFNULL(a.target05,0) AS target05, IFNULL(a.target06,0) AS target06,
               IFNULL(a.target07,0) AS target07, IFNULL(a.target08,0) AS target08,
               IFNULL(a.target09,0) AS target09, IFNULL(a.target10,0) AS target10,
               IFNULL(a.target11,0) AS target11, IFNULL(a.target12,0) AS target12
        FROM trans_targetsales_detail a
        WHERE a.tahun = ctahun;
    ALTER TABLE ttarget ADD INDEX (sales_id, linibisnis_id);

-- Kunci sales & lini bisnis: yang ada di target + yang ada transaksi
    CREATE TEMPORARY TABLE tkey AS
        SELECT sales_id, linibisnis_id FROM ttarget
        UNION
        SELECT sales_id, linibisnis_id FROM tB2;

-- Detail per lini bisnis
    CREATE TEMPORARY TABLE targettemp AS
        SELECT t.id, k.sales_id, s.sales_name, k.linibisnis_id, c.linibisnis_name,
               ctahun AS tahun,
               IFNULL(t.target, 0)        AS target,
               IFNULL(b.Total_Netto, 0)   AS actual,
               IFNULL(b.Batal, 0)         AS batal,
               IFNULL(b.Retur, 0)         AS retur,
               CAST(0 AS DECIMAL(20,2))   AS batalx,
               CAST(0 AS DECIMAL(20,2))   AS returx,
               IFNULL(t.target01,0) AS target01, IFNULL(t.target02,0) AS target02,
               IFNULL(t.target03,0) AS target03, IFNULL(t.target04,0) AS target04,
               IFNULL(t.target05,0) AS target05, IFNULL(t.target06,0) AS target06,
               IFNULL(t.target07,0) AS target07, IFNULL(t.target08,0) AS target08,
               IFNULL(t.target09,0) AS target09, IFNULL(t.target10,0) AS target10,
               IFNULL(t.target11,0) AS target11, IFNULL(t.target12,0) AS target12
        FROM tkey k
        LEFT JOIN ttarget t     ON t.sales_id = k.sales_id AND t.linibisnis_id = k.linibisnis_id
        LEFT JOIN tB2 b         ON b.sales_id = k.sales_id AND b.linibisnis_id = k.linibisnis_id
        LEFT JOIN sales s       ON s.sales_id = k.sales_id
        LEFT JOIN lini_bisnis c ON c.linibisnis_id = k.linibisnis_id;

-- Baris TOTAL per sales (retur & batal total diambil dari tretur / tbatal per sales)
-- (temporary table tidak boleh dipakai 2x dalam 1 query, jadi dipecah ke tabel bantu)
    CREATE TEMPORARY TABLE tbs AS SELECT sales_id, SUM(Total_Netto) AS total_batal FROM tbatal GROUP BY sales_id;
    CREATE TEMPORARY TABLE trs AS SELECT sales_id, SUM(Total_Netto) AS total_retur FROM tretur GROUP BY sales_id;

    CREATE TEMPORARY TABLE ttotal AS
        SELECT a.sales_id, MAX(a.sales_name) AS sales_name,
               SUM(a.target) AS target, SUM(a.actual) AS actual,
               SUM(a.target01) AS target01, SUM(a.target02) AS target02,
               SUM(a.target03) AS target03, SUM(a.target04) AS target04,
               SUM(a.target05) AS target05, SUM(a.target06) AS target06,
               SUM(a.target07) AS target07, SUM(a.target08) AS target08,
               SUM(a.target09) AS target09, SUM(a.target10) AS target10,
               SUM(a.target11) AS target11, SUM(a.target12) AS target12
        FROM targettemp a
        GROUP BY a.sales_id;

    INSERT INTO targettemp (id, sales_id, sales_name, linibisnis_id, linibisnis_name, tahun,
                            target, actual, batal, retur, batalx, returx,
                            target01, target02, target03, target04, target05, target06,
                            target07, target08, target09, target10, target11, target12)
        SELECT NULL, t.sales_id, t.sales_name, 'XX', 'TOTAL', ctahun,
               t.target, t.actual,
               IFNULL(bs.total_batal, 0), IFNULL(rs.total_retur, 0),
               IFNULL(bs.total_batal, 0), IFNULL(rs.total_retur, 0),
               t.target01, t.target02, t.target03, t.target04, t.target05, t.target06,
               t.target07, t.target08, t.target09, t.target10, t.target11, t.target12
        FROM ttotal t
        LEFT JOIN tbs bs ON bs.sales_id = t.sales_id
        LEFT JOIN trs rs ON rs.sales_id = t.sales_id;

-- Hasil
    SELECT a.id, a.sales_id, a.sales_name, a.linibisnis_id, a.linibisnis_name,
           a.tahun, a.target, a.actual, a.batal, a.retur,
           IF(a.target = 0, 0, a.actual / a.target) AS ar,
           a.batalx, a.returx,
           (a.actual - a.batal - a.retur) AS tot,
           IF(a.target = 0, 0, (a.actual - a.batal - a.retur) / a.target) AS ar2,
           a.target01, a.target02, a.target03, a.target04, a.target05, a.target06,
           a.target07, a.target08, a.target09, a.target10, a.target11, a.target12
    FROM targettemp a
    ORDER BY a.sales_id, a.linibisnis_id;

    DROP TEMPORARY TABLE IF EXISTS tB0, tB2, tretur, tbatal, tkey, ttarget, targettemp, tbs, trs, ttotal;
END$$

DELIMITER ;
