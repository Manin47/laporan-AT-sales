<?php
defined('BASEPATH') OR exit('No direct script access allowed');
// Laporan Monitoring A/T (Actual / Target) Sales Harian All Lini Bisnis.
// Sumber data : procedure lap_at_sales_harian(tgl)  (lihat lap_at_sales_harian.sql di folder ini)
//               target = target tahun & bulan dari tgl dipilih, actual = tgl 1 s/d tgl dipilih.
// View        : views/report/v_monitoring_at_sales.php
class Monitoring_AT_Sales extends CI_Controller
{
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

    // data A/T per sales untuk tgl tertentu
    private function _data_at($tgl)
    {
        $tgl  = $this->db->escape($tgl);
        $hasil = $this->db->query("call lap_at_sales_harian($tgl)");
        $rows  = $hasil->result();
        // bersihkan result set procedure supaya query berikutnya tidak error "commands out of sync"
        $hasil->free_result();
        if (method_exists($this->db->conn_id, 'next_result')) {
            while ($this->db->conn_id->more_results() && $this->db->conn_id->next_result()) {}
        }
        // cabang: sales_id -> mastersup_position.kode_cabang
        $csql = "select p.sales_id, max(p.kode_cabang) as cabang
                 from mastersup_position p
                 group by p.sales_id";
        $cabang = array();
        foreach ($this->db->query($csql)->result() as $c) {
            $cabang[$c->sales_id] = $c->cabang;
        }
        foreach ($rows as $r) {
            $r->cabang = isset($cabang[$r->sales_id]) ? $cabang[$r->sales_id] : '';
        }

        // urut A/T terbesar paling atas
        usort($rows, function ($a, $b) {
            if ((float) $a->at == (float) $b->at) return 0;
            return ((float) $a->at < (float) $b->at) ? 1 : -1;
        });
        return $rows;
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

                $data['tgl'] = $tgl;
                $data['dat'] = $this->_data_at($tgl);
                $this->load->view('report/v_monitoring_at_sales', $data);
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
 * - Buka index.php/sales/Monitoring_AT_Sales -> default tgl hari ini.
 * - Pilih tgl (POST) -> call lap_at_sales_harian('Y-m-d').
 *     target      = target tahun & bulan dari tgl (2026-08-05 -> tahun 2026, target08)
 *     actual_hari = penjualan tgl itu saja
 *     tot         = penjualan tgl 1 s/d tgl dipilih - batal - retur
 * - A/T     = tot / target * 100 (%), jika target 0 -> 0.
 * - Deviasi = tot - target (minus = di bawah target).
 * - Baris TOTAL = jumlah semua sales, A/T total = total actual / total target.
 */
