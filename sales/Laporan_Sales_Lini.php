<?php
defined('BASEPATH') OR exit('No direct script access allowed');
// Laporan Sales by Lini Bisnis & Mentor/SPV (format sheet "AT DETAIL" di views/report/REPORT SALES.xlsx).
// Sumber data : procedure lap_sales_lini_mentor(tgl)  (lihat lap_sales_lini_mentor.sql di folder ini)
// View        : views/report/v_laporan_sales_lini.php
class Laporan_Sales_Lini extends CI_Controller
{
    // hari kerja default untuk target daily (di excel: target / 22),
    // dipakai jika tahun & bulan belum diisi di tabel sales_hari_kerja
    const HARI_KERJA = 22;

    public function __construct()
    {
        parent::__construct();
        $this->load->database();
        $this->load->helper("url");
    }

    // pengganti $this->admin->logged_id()
    private function _logged_id()
    {
        return $this->session->userdata('user_id');
    }

    // data per sales x lini bisnis untuk tgl tertentu
    private function _data($tgl)
    {
        $tgl   = $this->db->escape($tgl);
        $hasil = $this->db->query("call lap_sales_lini_mentor($tgl)");
        $rows  = $hasil->result();
        // bersihkan result set procedure supaya query berikutnya tidak error "commands out of sync"
        $hasil->free_result();
        if (method_exists($this->db->conn_id, 'next_result')) {
            while ($this->db->conn_id->more_results() && $this->db->conn_id->next_result()) {}
        }
        return $rows;
    }

    // hari kerja bulan dari tgl dipilih (tabel sales_hari_kerja), jika tidak ada -> 22
    private function _hari_kerja($tgl)
    {
        if (!$this->db->table_exists('sales_hari_kerja')) {
            return self::HARI_KERJA;
        }
        $tahun = (int) date('Y', strtotime($tgl));
        $bulan = (int) date('n', strtotime($tgl));
        $row = $this->db->query("select hari_kerja from sales_hari_kerja
                                 where tahun = $tahun and bulan = $bulan limit 1")->row();
        if ($row && (int) $row->hari_kerja > 0) {
            return (int) $row->hari_kerja;
        }
        return self::HARI_KERJA;
    }

    // susun jadi cabang -> mentor -> sales -> lini (urutan sudah dari procedure)
    private function _tree($rows)
    {
        $tree = array();
        foreach ($rows as $r) {
            $c = ''; // cabang tidak ditampilkan -> semua jadi 1 grup, langsung per mentor
            $m = $r->spv_id;
            $s = $r->sales_id;
            if (!isset($tree[$c])) {
                $tree[$c] = array('nama' => $r->nama_cabang, 'mentor' => array());
            }
            if (!isset($tree[$c]['mentor'][$m])) {
                $tree[$c]['mentor'][$m] = array('nama' => $r->spv_name, 'sales' => array());
            }
            if (!isset($tree[$c]['mentor'][$m]['sales'][$s])) {
                $tree[$c]['mentor'][$m]['sales'][$s] = array('nama' => $r->sales_name ? $r->sales_name : $s, 'lini' => array());
            }
            $tree[$c]['mentor'][$m]['sales'][$s]['lini'][] = $r;
        }
        return $tree;
    }

    public function index()
    {
        if($this->_logged_id())
        {
            $cappid = 'M.sales1';
            $cuserid = $this->session->userdata("user_id");
            $csql = "select akses from userapp_web where userid = '$cuserid' and appid = '$cappid' limit 1";
            $hasil = $this->db->query($csql);
            $cakses = 0;
            foreach ($hasil->result() as $row){
                $cakses = $row->akses;
            }
            if($cakses == 1){
                $tgl = $this->input->post('tgl');
                if (!$tgl || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $tgl)) {
                    $tgl = date('Y-m-d');
                }

                $data['tgl']        = $tgl;
                $data['hari_kerja'] = $this->_hari_kerja($tgl);
                $data['tree']       = $this->_tree($this->_data($tgl));
                $this->load->view('report/v_laporan_sales_lini', $data);
            }else{
                $this->load->view('admin/accessdenied');
            }
        }else{
            $this->load->view('login');
        }
    }
}

/*
 * ALUR LAPORAN
 * - Buka index.php/sales/Laporan_Sales_Lini -> default tgl hari ini.
 * - Pilih tgl (POST) -> call lap_sales_lini_mentor('Y-m-d').
 * - Kolom (sama dengan sheet AT DETAIL):
 *     Target All      = target bulan dari tgl dipilih (trans_targetsales_detail)
 *     Target Daily    = Target All / hari kerja (tabel sales_hari_kerja by tahun & bulan, default 22)
 *     Sales Tgl 01-xx = penjualan tgl 1 s/d (tgl dipilih - 1)  (tgl 1 -> 0)
 *     Sales Tgl xx    = penjualan tgl dipilih
 *     Total           = Sales Tgl 01-xx + Sales Tgl xx
 *     Pencapaian Daily= Sales Tgl xx / Target Daily
 *     Pencapaian All  = Total / Target All
 *     Deviasi All     = Total - Target All
 *   penjualan = invitem_ppn - batal - retur approve, per lini bisnis dari product.linibisnis_id
 * - Subtotal: per salesman, TOTAL TIM <mentor>, TOTAL TIM CABANG <cabang>, GRAND TOTAL.
 */
