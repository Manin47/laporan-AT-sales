<?php
$this->load->view('template/head');
?>

<?php
$this->load->view('template/topbar');
$this->load->view('template/sidebar');
?>
<!--tambahkan custom css disini-->
<style>
  #tbl_at { width: 100%; }
  #tbl_at thead th { background: #00b0f0; color: #000; font-weight: normal; vertical-align: bottom; }
  #tbl_at tfoot td { background: #ffff00; font-weight: bold; }
  #tbl_at .minus { color: #dd0000; }
  #tbl_at td.num { text-align: right; }
</style>

    <section class="content">
    <div class="row">
        <div class="col-xs-12">
          <div class="box">
                <div class="box-header">
                <?php $this->load->view("admin/_partials/breadcrumb.php") ?>

                <!-- filter -->
                <form method="post" action="<?php echo site_url('sales/Monitoring_AT_Sales') ?>" class="form-inline">
                  <div class="form-group">
                    <label>Tgl Awal</label>
                    <input type="date" id="tgl_awal" class="form-control input-sm" value="<?php echo date('Y-m-01', strtotime($tgl)) ?>" readonly>
                  </div>
                  <div class="form-group">
                    <label>s/d Tgl Akhir</label>
                    <input type="date" name="tgl" id="tgl_akhir" class="form-control input-sm" value="<?php echo $tgl ?>" required>
                  </div>
                  <button type="submit" class="btn btn-primary btn-sm">Cari</button>
                </form>
                <br>

                <h4 style="margin-bottom:2px">MONITORING A/T SALES HARIAN ALL LINI BISNIS</h4>
                <h5 style="margin-top:0">PER TGL <?php echo date('d-m-Y', strtotime($tgl)) ?>
                  &nbsp;|&nbsp; Target bulan <?php echo date('m-Y', strtotime($tgl)) ?>,
                  Actual <?php echo date('01-m-Y', strtotime($tgl)) ?> s/d <?php echo date('d-m-Y', strtotime($tgl)) ?></h5>

                <table class="table table-bordered table-sm" id="tbl_at" cellspacing="0">
                  <thead>
                    <tr class="input-sm">
                      <th class="text-center" style="width:60px">NO</th>
                      <th class="text-center">CABANG</th>
                      <th class="text-center">RAYON MARKETING</th>
                      <th class="text-center">TARGET</th>
                      <th class="text-center">ACTUAL </th>
                      <th class="text-center" style="width:100px">A/T</th>
                      <th class="text-center">DEVIASI</th>
                    </tr>
                  </thead>
                  <tbody>
                    <?php
                    $no = 1;
                    $tot_target = 0;
                    $tot_actual = 0;
                    foreach($dat as $u){
                        $target  = (float) $u->target;
                        $actual  = (float) $u->tot;
                        $at      = (float) $u->at * 100;
                        $deviasi = (float) $u->deviasi;
                        $tot_target += $target;
                        $tot_actual += $actual;
                    ?>
                    <tr class="input-sm">
                      <td class="text-center"><?php echo $no++ ?></td>
                      <td><?php echo $u->cabang ?></td>
                      <td><?php echo $u->sales_name ? $u->sales_name : $u->sales_id ?></td>
                      <td class="num"><?php echo number_format($target, 0, '.', ',') ?></td>
                      <td class="num"><?php echo number_format($actual, 0, '.', ',') ?></td>
                      <td class="num"><?php echo number_format($at, 2, '.', ',') ?>%</td>
                      <td class="num <?php echo ($deviasi < 0) ? 'minus' : '' ?>"><?php echo number_format($deviasi, 0, '.', ',') ?></td>
                    </tr>
                    <?php } ?>
                  </tbody>
                  <?php
                    $tot_at      = ($tot_target != 0) ? ($tot_actual / $tot_target * 100) : 0;
                    $tot_deviasi = $tot_actual - $tot_target;
                  ?>
                  <tfoot>
                    <tr class="input-sm">
                      <td colspan="3">TOTAL</td>
                      <td class="num"><?php echo number_format($tot_target, 0, '.', ',') ?></td>
                      <td class="num"><?php echo number_format($tot_actual, 0, '.', ',') ?></td>
                      <td class="num"><?php echo number_format($tot_at, 2, '.', ',') ?>%</td>
                      <td class="num <?php echo ($tot_deviasi < 0) ? 'minus' : '' ?>"><?php echo number_format($tot_deviasi, 0, '.', ',') ?></td>
                    </tr>
                  </tfoot>
                </table>

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
    $('#tbl_at').DataTable({
      dom: 'Bfrtip',
      paging: false,
      ordering: false,
      buttons: ['excel', 'print']
    });

    // tgl awal selalu tgl 01 dari bulan tgl akhir
    $('#tgl_akhir').on('change', function() {
      var v = $(this).val(); // yyyy-mm-dd
      if (v) { $('#tgl_awal').val(v.substr(0, 8) + '01'); }
    });
  });
</script>
<?php
$this->load->view('template/foot');
?>
