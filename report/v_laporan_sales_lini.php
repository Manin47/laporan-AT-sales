<?php
$this->load->view('template/head');
?>

<?php
$this->load->view('template/topbar');
$this->load->view('template/sidebar');
?>
<!--tambahkan custom css disini-->
<style>
  #tbl_lini { width: 100%; font-size: 12px; }
  #tbl_lini thead th { background: #00b0f0; color: #000; text-align: center; vertical-align: middle; }
  #tbl_lini td.num { text-align: right; white-space: nowrap; }
  #tbl_lini tr.sub-sales td  { background: #f1f6e1; font-weight: bold; }
  #tbl_lini tr.sub-mentor td { background: #ffe699; font-weight: bold; }
  #tbl_lini tr.sub-cabang td { background: #ffff00; font-weight: bold; }
  #tbl_lini tr.grand td      { background: #92d050; font-weight: bold; }
  #tbl_lini .minus { color: #dd0000; }
</style>

<?php
$nama_bulan = array(1=>'JANUARI','FEBRUARI','MARET','APRIL','MEI','JUNI','JULI','AGUSTUS','SEPTEMBER','OKTOBER','NOVEMBER','DESEMBER');
$ts   = strtotime($tgl);
$hari = (int) date('j', $ts);
$bln  = $nama_bulan[(int) date('n', $ts)];
// label kolom penjualan: tgl 11 -> "Sales Tgl 01-10" | "Sales Tgl 11", tgl 1 -> "-" | "Sales Tgl 01"
$lbl_sd   = ($hari > 1) ? 'Sales Tgl 01-'.str_pad($hari - 1, 2, '0', STR_PAD_LEFT) : 'Sales Tgl -';
$lbl_hari = 'Sales Tgl '.str_pad($hari, 2, '0', STR_PAD_LEFT);

// akumulator kosong
if (!function_exists('lini_zero')) {
function lini_zero() { return array('target' => 0, 'sd' => 0, 'hari' => 0); }
function lini_add(&$a, $b) { $a['target'] += $b['target']; $a['sd'] += $b['sd']; $a['hari'] += $b['hari']; }

// cetak kolom angka (Target All .. Deviasi All) sesuai rumus excel
function lini_cols($v, $hari_kerja) {
    $daily   = $v['target'] / $hari_kerja;
    $total   = $v['sd'] + $v['hari'];
    $p_daily = ($daily != 0) ? $v['hari'] / $daily * 100 : 0;
    $p_all   = ($v['target'] != 0) ? $total / $v['target'] * 100 : 0;
    $dev     = $total - $v['target'];
    $f = function ($n) { return number_format($n, 0, '.', ','); };
    return '<td class="num">'.$f($v['target']).'</td>'
         . '<td class="num">'.$f($daily).'</td>'
         . '<td class="num">'.$f($v['sd']).'</td>'
         . '<td class="num">'.$f($v['hari']).'</td>'
         . '<td class="num">'.$f($total).'</td>'
         . '<td class="num">'.number_format($p_daily, 2, '.', ',').'%</td>'
         . '<td class="num">'.number_format($p_all, 2, '.', ',').'%</td>'
         . '<td class="num'.($dev < 0 ? ' minus' : '').'">'.$f($dev).'</td>';
}
}
?>

    <section class="content">
    <div class="row">
        <div class="col-xs-12">
          <div class="box">
                <div class="box-header">
                <?php $this->load->view("admin/_partials/breadcrumb.php") ?>

                <!-- filter -->
                <form method="post" action="<?php echo site_url('sales/Laporan_Sales_Lini') ?>" class="form-inline">
                  <div class="form-group">
                    <label>Tgl Awal</label>
                    <input type="date" id="tgl_awal" class="form-control input-sm" value="<?php echo date('Y-m-01', $ts) ?>" readonly>
                  </div>
                  <div class="form-group">
                    <label>s/d Tgl Akhir</label>
                    <input type="date" name="tgl" id="tgl_akhir" class="form-control input-sm" value="<?php echo $tgl ?>" required>
                  </div>
                  <button type="submit" class="btn btn-primary btn-sm">Cari</button>
                  <button type="button" id="btn_excel" class="btn btn-success btn-sm"><i class="fa fa-file-excel-o"></i> Export Excel</button>
                  <button type="button" id="btn_pdf" class="btn btn-danger btn-sm"><i class="fa fa-file-pdf-o"></i> Export PDF</button>
                </form>
                <br>

                <h4 id="judul1" style="margin-bottom:2px">PENCAPAIAN SALES PT. ANARA TRISAKTI MEDIKA PERIODE <?php echo $bln.' '.date('Y', $ts) ?></h4>
                <h5 id="judul2" style="margin-top:0">PER TGL <?php echo date('d-m-Y', $ts) ?></h5>

                <div class="table-responsive">
                <table class="table table-bordered table-condensed" id="tbl_lini" cellspacing="0">
                  <thead>
                    <tr>
                      <th rowspan="2">NO</th>
                      <th rowspan="2">MENTOR</th>
                      <th rowspan="2">SALESMAN</th>
                      <th rowspan="2">LINI BISNIS</th>
                      <th colspan="2">TARGET <?php echo $bln ?></th>
                      <th colspan="2">PENJUALAN</th>
                      <th rowspan="2">TOTAL</th>
                      <th colspan="3">PENCAPAIAN</th>
                    </tr>
                    <tr>
                      <th>ALL</th>
                      <th>DAILY</th>
                      <th><?php echo $lbl_sd ?></th>
                      <th><?php echo $lbl_hari ?></th>
                      <th>Daily</th>
                      <th>All</th>
                      <th>Deviasi All</th>
                    </tr>
                  </thead>
                  <tbody>
                  <?php
                  $no    = 1;
                  $grand = lini_zero();
                  foreach ($tree as $cab) {
                      $tot_cab = lini_zero();
                      $first_cab = true;
                      foreach ($cab['mentor'] as $mentor) {
                          $tot_mentor = lini_zero();
                          $first_mentor = true;
                          foreach ($mentor['sales'] as $sales) {
                              $tot_sales = lini_zero();
                              $first_sales = true;
                              foreach ($sales['lini'] as $l) {
                                  $v = array('target' => (float) $l->target, 'sd' => (float) $l->sales_sd, 'hari' => (float) $l->sales_hari);
                                  lini_add($tot_sales, $v);
                                  echo '<tr>';
                                  echo '<td class="text-center">'.($first_sales ? $no++ : '').'</td>';
                                  echo '<td>'.($first_mentor ? $mentor['nama'] : '').'</td>';
                                  echo '<td>'.($first_sales ? $sales['nama'] : '').'</td>';
                                  echo '<td>'.$l->linibisnis_name.'</td>';
                                  echo lini_cols($v, $hari_kerja);
                                  echo '</tr>';
                                  $first_cab = $first_mentor = $first_sales = false;
                              }
                              // subtotal per salesman
                              echo '<tr class="sub-sales"><td></td><td></td><td colspan="2">TOTAL '.$sales['nama'].'</td>'.lini_cols($tot_sales, $hari_kerja).'</tr>';
                              lini_add($tot_mentor, $tot_sales);
                          }
                          // total tim mentor
                          $nm_mentor = $mentor['nama'] !== '' ? $mentor['nama'] : '(TANPA MENTOR)';
                          echo '<tr class="sub-mentor"><td></td><td colspan="3">TOTAL TIM '.$nm_mentor.'</td>'.lini_cols($tot_mentor, $hari_kerja).'</tr>';
                          lini_add($tot_cab, $tot_mentor);
                      }
                      // (total cabang tidak ditampilkan)
                      lini_add($grand, $tot_cab);
                  }
                  ?>
                  </tbody>
                  <tfoot>
                    <tr class="grand"><td colspan="4">GRAND TOTAL</td><?php echo lini_cols($grand, $hari_kerja) ?></tr>
                  </tfoot>
                </table>
                </div>

                <small>Target Daily = Target All / <?php echo $hari_kerja ?> hari kerja.
                Penjualan = faktur - batal - retur (approve), per lini bisnis barang.</small>

                </div>
          </div>
        </div>
    </div>
      <!-- /.row -->
    </section>
    <!-- /.content -->

<?php
$this->load->view('template/js');
?>
<!--tambahkan custom js disini-->
<script type="text/javascript">
  $(document).ready(function() {
    // tgl awal selalu tgl 01 dari bulan tgl akhir
    $('#tgl_akhir').on('change', function() {
      var v = $(this).val(); // yyyy-mm-dd
      if (v) { $('#tgl_awal').val(v.substr(0, 8) + '01'); }
    });

    var nama_file = 'Laporan_Sales_Lini_<?php echo $tgl ?>';

    // warna baris subtotal (sama dengan css)
    function warnaBaris(tr) {
      if ($(tr).hasClass('grand'))      return '#92d050';
      if ($(tr).hasClass('sub-cabang')) return '#ffff00';
      if ($(tr).hasClass('sub-mentor')) return '#ffe699';
      if ($(tr).hasClass('sub-sales'))  return '#f1f6e1';
      return null;
    }

    // ===== Export Excel: tabel html -> .xls (colspan, warna, judul ikut) =====
    $('#btn_excel').on('click', function() {
      var $tbl = $('#tbl_lini').clone();
      $tbl.attr('border', '1');
      $tbl.find('thead th').attr('style', 'background:#00b0f0;');
      $tbl.find('tr').each(function() {
        var w = warnaBaris(this);
        if (w) $(this).find('td').attr('style', 'background:' + w + ';font-weight:bold;');
      });
      $tbl.find('td.minus').css('color', '#dd0000');
      var html = '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">'
               + '<head><meta charset="UTF-8"></head><body>'
               + '<h3>' + $('#judul1').text() + '</h3><h4>' + $('#judul2').text() + '</h4>'
               + $tbl.prop('outerHTML') + '</body></html>';
      var blob = new Blob(['﻿', html], { type: 'application/vnd.ms-excel' });
      var a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = nama_file + '.xls';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    });

    // ===== Export PDF: pdfmake (sudah di-load di template/js) =====
    $('#btn_pdf').on('click', function() {
      var body = [];
      var jmlKolom = 12; // NO, MENTOR, SALESMAN, LINI, TARGET ALL, DAILY, SALES SD, SALES HARI, TOTAL, P.DAILY, P.ALL, DEVIASI

      // header 2 baris (rowspan / colspan)
      var pending = {}; // kolom yang tertutup rowspan dari baris atas
      $('#tbl_lini thead tr').each(function(ri) {
        var row = [], col = 0;
        $(this).find('th').each(function() {
          while (pending[ri] && pending[ri][col]) { row.push({}); col++; }
          var cs = parseInt($(this).attr('colspan') || 1, 10);
          var rs = parseInt($(this).attr('rowspan') || 1, 10);
          var cell = { text: $(this).text().trim(), bold: true, alignment: 'center', fillColor: '#00b0f0' };
          if (cs > 1) cell.colSpan = cs;
          if (rs > 1) {
            cell.rowSpan = rs;
            for (var k = 1; k < rs; k++) { pending[ri + k] = pending[ri + k] || {}; pending[ri + k][col] = true; }
          }
          row.push(cell);
          for (var c = 1; c < cs; c++) row.push({});
          col += cs;
        });
        while (row.length < jmlKolom) row.push({});
        body.push(row);
      });

      // isi (tbody + tfoot)
      $('#tbl_lini tbody tr, #tbl_lini tfoot tr').each(function() {
        var row = [], w = warnaBaris(this);
        $(this).find('td').each(function() {
          var cs = parseInt($(this).attr('colspan') || 1, 10);
          var cell = { text: $(this).text().trim() };
          if ($(this).hasClass('num')) cell.alignment = 'right';
          if ($(this).hasClass('minus')) cell.color = '#dd0000';
          if (w) { cell.fillColor = w; cell.bold = true; }
          if (cs > 1) cell.colSpan = cs;
          row.push(cell);
          for (var c = 1; c < cs; c++) row.push({});
        });
        while (row.length < jmlKolom) row.push({});
        body.push(row);
      });

      var doc = {
        pageSize: 'A4',
        pageOrientation: 'landscape',
        pageMargins: [15, 20, 15, 20],
        defaultStyle: { fontSize: 6.5 },
        content: [
          { text: $('#judul1').text(), bold: true, fontSize: 10 },
          { text: $('#judul2').text(), fontSize: 8, margin: [0, 0, 0, 6] },
          { table: { headerRows: 2, body: body }, layout: { hLineWidth: function() { return 0.5; }, vLineWidth: function() { return 0.5; } } }
        ]
      };
      pdfMake.createPdf(doc).download(nama_file + '.pdf');
    });
  });
</script>
<?php
$this->load->view('template/foot');
?>
