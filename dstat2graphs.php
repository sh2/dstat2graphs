<?php

// error_reporting(E_ALL|E_STRICT);

function get_report_dir() {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    $report_dir = 'reports/' . date('Ymd-His_');
    
    for ($i = 0; $i < 8; $i++) {
        $report_dir .= $chars{mt_rand(0, strlen($chars) - 1)};
    }
    
    return $report_dir;
}

function validate_number($input, $min, $max, $default) {
    if (preg_match('/^\d+$/D', $input)) {
        if ($input < $min) {
            return $min;
        } elseif ($input > $max) {
            return $max;
        } else {
            return $input;
        }
    } else {
        return $default;
    }
}

$csv_file   = escapeshellarg($_FILES['csv_file']['tmp_name']);
$report_dir = get_report_dir();
$width      = validate_number($_POST['width'], 64, 1024, 512);
$height     = validate_number($_POST['height'], 64, 1024, 192);
$disk_limit = validate_number($_POST['disk_limit'], 0, PHP_INT_MAX, 0);
$net_limit  = validate_number($_POST['net_limit'], 0, PHP_INT_MAX, 0);
$message    = '';

if (is_uploaded_file($_FILES['csv_file']['tmp_name'])) {
    exec("perl dstat2graphs.pl {$csv_file} {$report_dir} {$width} {$height} {$disk_limit} {$net_limit} 2>&1",
        $output, $return_var);
    
    if ($return_var == 0) {
        header("Location: {$report_dir}/");
        exit();
    } else {
        foreach ($output as $line) {
            $message .= htmlspecialchars($line) . "<br />\n";
        }
    }
} else {
    if (($_FILES['csv_file']['error'] == UPLOAD_ERR_INI_SIZE)
        || ($_FILES['csv_file']['error'] == UPLOAD_ERR_FORM_SIZE)) {
        
        $message = "File size limit exceeded.\n";
    } else {
        $message = "Failed to upload file.\n";
    }
}

?>
<!DOCTYPE html>
<html>
  <head>
    <title>Error - dstat2graphs</title>
  </head>
  <body>
    <p>
<?php print $message; ?>
    </p>
  </body>
</html>

