-- =====================================================================
-- Procedure : lap_sales_lini_mentor
-- Untuk laporan Sales by Lini Bisnis & Mentor/SPV (sales/Laporan_Sales_Lini),
-- format mengikuti sheet "AT DETAIL" di views/report/REPORT SALES.xlsx.
--
-- Contoh  : call lap_sales_lini_mentor('2026-10-11');
--
-- Hasil 1 baris per sales x lini bisnis (lini_bisnis.aktif = 1):
--  - kode_cabang, nama_cabang : mastersup_position.kode_cabang -> masterasm.remark (kode_asm)
--  - spv_id, spv_name         : mastersup_position.spv_id -> join sales (sales_id) -> sales_name (mentor)
--  - target                   : trans_targetsales_detail, tahun & bulan dari tgl dipilih (target01..12)
--  - sales_sd                 : penjualan tgl 1 s/d (tgl dipilih - 1)   -> kolom "Sales Tgl 01-10"
--  - sales_hari               : penjualan tgl dipilih                   -> kolom "Sales Tgl 11"
--    (jika tgl dipilih = tgl 1, sales_sd = 0 supaya tidak dobel dengan sales_hari)
--  penjualan = invitem_ppn (product.linibisnis_id) - batal (by tglbatal) - retur approve (by tgl retur)
-- Sales yang ditampilkan: punya target bulan itu ATAU ada transaksi di bulan itu s/d tgl dipilih.
-- =====================================================================

DROP PROCEDURE IF EXISTS `lap_sales_lini_mentor`;

DELIMITER $$

CREATE DEFINER=`root`@`%` PROCEDURE `lap_sales_lini_mentor`(
    IN ctgl date)
BEGIN
    DECLARE ctahun int;
    DECLARE cbulan int;
    DECLARE ctgl1  date;

    SET ctahun = YEAR(ctgl);
    SET cbulan = MONTH(ctgl);
    SET ctgl1  = DATE_FORMAT(ctgl, '%Y-%m-01');

    DROP TEMPORARY TABLE IF EXISTS tjual, tretur, tbatal, ttarget, tkey, tsales, tpos;

-- Penjualan per sales & lini: sd = tgl 1 s/d kemarin, hari = tgl dipilih
    CREATE TEMPORARY TABLE tjual AS
        SELECT a.sales_id, e.linibisnis_id,
               SUM(IF(a.transaction_Date <  ctgl, b.subtotal, 0)) AS sd,
               SUM(IF(a.transaction_Date >= ctgl, b.subtotal, 0)) AS hari
        FROM invitem_ppn b
        LEFT JOIN invheader_ppn a ON a.TransactionInv_id = b.TransactionInv_Id AND a.TransactionInv_id2 = b.TransactionInv_id2
        LEFT JOIN product e ON e.Plu = b.Plu
        WHERE a.transaction_Date >= ctgl1
          AND a.transaction_Date <  ctgl + INTERVAL 1 DAY
        GROUP BY a.sales_id, e.linibisnis_id;

-- Retur (sudah approve) per sales & lini
    CREATE TEMPORARY TABLE tretur AS
        SELECT g.sales_id, e.linibisnis_id,
               SUM(IF(a.transaction_Date <  ctgl, b.subtotal, 0)) AS sd,
               SUM(IF(a.transaction_Date >= ctgl, b.subtotal, 0)) AS hari
        FROM returnitem_ppn b
        LEFT JOIN return_ppn a ON a.Return_id = b.Return_id
        LEFT JOIN invheader_ppn g ON g.TransactionInv_id = b.TransactionInv_Id
        LEFT JOIN product e ON e.Plu = b.Plu
        WHERE a.transaction_Date >= ctgl1
          AND a.transaction_Date <  ctgl + INTERVAL 1 DAY
          AND b.approval = 1
        GROUP BY g.sales_id, e.linibisnis_id;

-- Batal (by tglbatal) per sales & lini
    CREATE TEMPORARY TABLE tbatal AS
        SELECT a.sales_id, e.linibisnis_id,
               SUM(IF(a.tglbatal <  ctgl, b.subtotal, 0)) AS sd,
               SUM(IF(a.tglbatal >= ctgl, b.subtotal, 0)) AS hari
        FROM invitem_ppn b
        LEFT JOIN invheader_ppn a ON a.TransactionInv_id = b.TransactionInv_Id AND a.TransactionInv_id2 = b.TransactionInv_id2
        LEFT JOIN product e ON e.Plu = b.Plu
        WHERE a.tglbatal >= ctgl1
          AND a.tglbatal <  ctgl + INTERVAL 1 DAY
          AND a.batal = 1
        GROUP BY a.sales_id, e.linibisnis_id;

-- Target tahun & bulan dari tgl dipilih per sales & lini
    CREATE TEMPORARY TABLE ttarget AS
        SELECT a.sales_id, a.linibisnis_id,
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
        GROUP BY a.sales_id, a.linibisnis_id;

-- Sales yang tampil: ada target atau ada transaksi
    CREATE TEMPORARY TABLE tkey AS
        SELECT sales_id FROM ttarget WHERE target <> 0
        UNION
        SELECT sales_id FROM tjual
        UNION
        SELECT sales_id FROM tretur
        UNION
        SELECT sales_id FROM tbatal;

    CREATE TEMPORARY TABLE tsales AS
        SELECT DISTINCT sales_id FROM tkey WHERE IFNULL(sales_id, '') <> '';

-- Posisi sales (cabang & mentor/spv), 1 baris per sales
    CREATE TEMPORARY TABLE tpos AS
        SELECT p.sales_id, MAX(p.kode_cabang) AS kode_cabang, MAX(p.spv_id) AS spv_id
        FROM mastersup_position p
        GROUP BY p.sales_id;

-- Hasil
    SELECT x.*,
           (x.jual_sd   - x.batal_sd   - x.retur_sd)   AS sales_sd,
           (x.jual_hari - x.batal_hari - x.retur_hari) AS sales_hari
    FROM (
        SELECT IFNULL(p.kode_cabang, '')                       AS kode_cabang,
               IFNULL(ma.remark, IFNULL(p.kode_cabang, ''))    AS nama_cabang,
               IFNULL(p.spv_id, '')                            AS spv_id,
               IFNULL(sp.sales_name, '')                       AS spv_name,
               s.sales_id, sl.sales_name,
               lb.linibisnis_id, lb.linibisnis_name,
               IFNULL(t.target, 0)                             AS target,
               IF(DAY(ctgl) = 1, 0, IFNULL(j.sd, 0))           AS jual_sd,
               IFNULL(j.hari, 0)                               AS jual_hari,
               IF(DAY(ctgl) = 1, 0, IFNULL(bt.sd, 0))          AS batal_sd,
               IFNULL(bt.hari, 0)                              AS batal_hari,
               IF(DAY(ctgl) = 1, 0, IFNULL(r.sd, 0))           AS retur_sd,
               IFNULL(r.hari, 0)                               AS retur_hari
        FROM tsales s
        JOIN lini_bisnis lb      ON lb.aktif = 1
        LEFT JOIN ttarget t      ON t.sales_id  = s.sales_id AND t.linibisnis_id  = lb.linibisnis_id
        LEFT JOIN tjual j        ON j.sales_id  = s.sales_id AND j.linibisnis_id  = lb.linibisnis_id
        LEFT JOIN tbatal bt      ON bt.sales_id = s.sales_id AND bt.linibisnis_id = lb.linibisnis_id
        LEFT JOIN tretur r       ON r.sales_id  = s.sales_id AND r.linibisnis_id  = lb.linibisnis_id
        LEFT JOIN sales sl       ON sl.sales_id = s.sales_id
        LEFT JOIN tpos p         ON p.sales_id  = s.sales_id
        LEFT JOIN (SELECT kode_asm, MAX(remark) AS remark FROM masterasm GROUP BY kode_asm) ma
                                 ON ma.kode_asm = p.kode_cabang
        LEFT JOIN sales sp       ON sp.sales_id = p.spv_id
    ) x
    ORDER BY x.nama_cabang, x.spv_name, x.sales_name, x.linibisnis_id;

    DROP TEMPORARY TABLE IF EXISTS tjual, tretur, tbatal, ttarget, tkey, tsales, tpos;
END$$

DELIMITER ;
