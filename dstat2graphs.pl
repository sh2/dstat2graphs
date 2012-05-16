#!/usr/bin/perl

use strict;
use warnings;

use File::Path;
use HTML::Entities;
use POSIX qw/floor ceil/;
use RRDs;
use Text::ParseWords;
use Time::Local;

if ($#ARGV != 5) {
    die 'Usage: perl dstat2graph.pl csv_file report_dir width height disk_limit net_limit';
}

my $csv_file   = $ARGV[0];
my $report_dir = $ARGV[1];
my $width      = $ARGV[2];
my $height     = $ARGV[3];
my $disk_limit = $ARGV[4];
my $net_limit  = $ARGV[5];

my @colors = (
    '008FFF', 'FF00BF', 'BFBF00', 'BF00FF',
    'FF8F00', '00BFBF', '7F5FBF', 'BF5F7F',
    '7F8F7F', '005FFF', 'FF007F', '7FBF00',
    '7F00FF', 'FF5F00', '00BF7F', '008FBF',
    'BF00BF', 'BF8F00', '7F5F7F', '005FBF',
    'BF007F', '7F8F00', '7F00BF', 'BF5F00',
    '008F7F', '0000FF', 'FF0000', '00BF00',
    '005F7F', '7F007F', '7F5F00', '0000BF',
    'BF0000', '008F00'
    );

my $epoch = 978274800; # 2001/01/01 00:00:00
my $top_dir = '..';
my $rrd_file = '/dev/shm/dstat2graphs/' . &random_str() . '.rrd';

my ($hostname, $year, @data, %index_disk, %index_cpu, %index_net);
my ($start_time, $end_time, $memory_size) = (0, 0, 0);

&load_csv();
&create_rrd();
&update_rrd();
&create_dir();
&create_graph();
&delete_rrd();
&create_html();

sub load_csv {
    open(my $fh, '<', "${csv_file}") or die $!;
    
    while (my $line = <$fh>) {
        chomp($line);
        
        if ($line eq '') {
            # Empty
        } elsif ($line =~ /^"?[a-zA-Z]/) {
            # Header
            my @cols = parse_line(',', 0, $line);
            
            if ($cols[0] =~ /^Dstat/) {
                # Title
            } elsif ($cols[0] eq 'Author:') {
                # Author, URL
            } elsif ($cols[0] eq 'Host:') {
                # Host, User
                $hostname = $cols[1];
            } elsif ($cols[0] eq 'Cmdline:') {
                # Cmdline, Date
                if ($cols[6] =~ /^\d+ \w+ (\d+)/) {
                    $year = $1;
                }
            # RHEL5:time, RHEL6:system
            } elsif (($cols[0] eq 'time') or ($cols[0] eq 'system')) {
                # Column name main
                my $index = -1;
                
                foreach my $col (@cols) {
                    $index++;
                    
                    if (!defined($col)) {
                        # Empty
                    } elsif (($col =~ /^dsk\/(\w+[a-z])$/)
                             or ($col =~ /^dsk\/cciss\/(c\d+d\d+)$/)) {
                        # Disk
                        my $disk = $1;
                        $disk =~ tr/\//_/;
                        $index_disk{$disk} = $index;
                    } elsif ($col =~ /^cpu(\d+)/) {
                        # CPU
                        $index_cpu{$1} = $index;
                    } elsif ($col =~ /^net\/(\w+)/) {
                        # Network
                        my $net = $1;
                        $net =~ tr/\//_/;
                        $index_net{$net} = $index;
                    }
                }
            } elsif ($cols[0] eq 'date/time') {
                # Column name sub
            } else {
                die 'It is not a dstat CSV file.';
            }
        } else {
            # Body
            my ($disk_read, $disk_writ, $net_recv, $net_send) = (0, 0, 0, 0);
            my @cols = parse_line(',', 0, $line);
            
            if ($start_time == 0) {
                if (!defined($hostname)) {
                    die 'It is not a dstat CSV file. No \'Host:\' column found.';
                }
                
                if (!defined($year)) {
                    die 'It is not a dstat CSV file. No \'Date:\' column found.';
                }
                
                if (!%index_disk) {
                    die 'It is not a dstat CSV file. No \'dsk/*:\' columns found.';
                }
                
                if (!%index_cpu) {
                    die 'It is not a dstat CSV file. No \'cpu*:\' columns found.';
                }
                
                if (!%index_net) {
                    die 'It is not a dstat CSV file. No \'net/*\' columns found.';
                }
                
                $start_time = &get_unixtime($year, $cols[0]);
            }
            
            my $unixtime = &get_unixtime($year, $cols[0]);
            
            if ($unixtime <= $end_time) {
                next;
            }
            
            $end_time = $unixtime;
            push @data, $line;
            
            if ($memory_size < $cols[4] + $cols[5] + $cols[6] + $cols[7]) {
                $memory_size = $cols[4] + $cols[5] + $cols[6] + $cols[7];
            }
        }
    }
    close($fh);
}

sub create_rrd {
    my @options;
    my $steps = floor(($end_time - $start_time) / 3600) + 1;
    my $rows = ceil(($end_time - $start_time) / $steps) + 1;
    
    # --start
    push @options, '--start';
    push @options, $epoch - 1;
    
    # --step
    push @options, '--step';
    push @options, 1;
    
    # Processes
    push @options, 'DS:PROCS_RUN:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:PROCS_BLK:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:PROCS_NEW:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    # Memory
    push @options, 'DS:MEMORY_USED:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:MEMORY_BUFF:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:MEMORY_CACH:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    # Paging
    push @options, 'DS:PAGE_IN:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:PAGE_OUT:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    # Disk total
    push @options, 'DS:DISK_READ:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:DISK_WRIT:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    # Disk individual
    foreach my $disk (sort keys %index_disk) {
        push @options, "DS:DISK_${disk}_READ:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
        
        push @options, "DS:DISK_${disk}_WRIT:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    }
    
    # Interrupts
    push @options, 'DS:INTERRUPTS:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    # Context Switches
    push @options, 'DS:CSWITCHES:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    # CPU total
    push @options, 'DS:CPU_USR:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:CPU_SYS:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:CPU_HIQ:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:CPU_SIQ:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:CPU_WAI:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    # CPU individual
    foreach my $cpu (sort { $a <=> $b } keys %index_cpu) {
        push @options, "DS:CPU${cpu}_USR:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
        
        push @options, "DS:CPU${cpu}_SYS:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
        
        push @options, "DS:CPU${cpu}_HIQ:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
        
        push @options, "DS:CPU${cpu}_SIQ:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
        
        push @options, "DS:CPU${cpu}_WAI:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    }
    
    # Network total
    push @options, 'DS:NET_RECV:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    push @options, 'DS:NET_SEND:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    
    # Network individual
    foreach my $net (sort keys %index_net) {
        push @options, "DS:NET_${net}_RECV:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
        
        push @options, "DS:NET_${net}_SEND:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:${steps}:${rows}";
    }
    
    RRDs::create($rrd_file, @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
}

sub update_rrd {
    my @entries;
    
    foreach my $row (@data) {
        my $entry = '';
        my @cols = parse_line(',', 0, $row);
        
        $entry .= $epoch + &get_unixtime($year, $cols[0]) - $start_time;
        
        # Processes
        $entry .= ":${cols[1]}:${cols[2]}:${cols[3]}";
        
        # Memory
        $entry .= ":${cols[4]}:${cols[5]}:${cols[6]}";
        
        # Paging
        $entry .= ":${cols[8]}:${cols[9]}";
        
        # Disk total
        my ($disk_read, $disk_writ) = (0, 0);
        
        foreach my $disk (keys %index_disk) {
            $disk_read += $cols[$index_disk{$disk}];
            $disk_writ += $cols[$index_disk{$disk} + 1];
        }
        
        $entry .= ":${disk_read}:${disk_writ}";
        
        # Disk individual
        foreach my $disk (sort keys %index_disk) {
            $disk_read = $cols[$index_disk{$disk}];
            $disk_writ = $cols[$index_disk{$disk} + 1];
            
            $entry .= ":${disk_read}:${disk_writ}";
        }
        
        # Interrupts
        $entry .= ":${cols[${index_cpu{'0'}} - 2]}";
        
        # Context Switches
        $entry .= ":${cols[${index_cpu{'0'}} - 1]}";
        
        # CPU total
        my ($cpu_usr, $cpu_sys, $cpu_hiq, $cpu_siq, $cpu_wai) = (0, 0, 0, 0, 0);
        
        foreach my $cpu (keys %index_cpu) {
            $cpu_usr += $cols[$index_cpu{$cpu}];
            $cpu_sys += $cols[$index_cpu{$cpu} + 1];
            $cpu_hiq += $cols[$index_cpu{$cpu} + 4];
            $cpu_siq += $cols[$index_cpu{$cpu} + 5];
            $cpu_wai += $cols[$index_cpu{$cpu} + 3];
        }
        
        $cpu_usr /= scalar(keys %index_cpu);
        $cpu_sys /= scalar(keys %index_cpu);
        $cpu_hiq /= scalar(keys %index_cpu);
        $cpu_siq /= scalar(keys %index_cpu);
        $cpu_wai /= scalar(keys %index_cpu);
        
        $entry .= ":${cpu_usr}:${cpu_sys}:${cpu_hiq}:${cpu_siq}:${cpu_wai}";
        
        # CPU individual
        foreach my $cpu (sort { $a <=> $b } keys %index_cpu) {
            $cpu_usr = $cols[$index_cpu{$cpu}];
            $cpu_sys = $cols[$index_cpu{$cpu} + 1];
            $cpu_hiq = $cols[$index_cpu{$cpu} + 4];
            $cpu_siq = $cols[$index_cpu{$cpu} + 5];
            $cpu_wai = $cols[$index_cpu{$cpu} + 3];
            $entry .= ":${cpu_usr}:${cpu_sys}:${cpu_hiq}:${cpu_siq}:${cpu_wai}";
        }
        
        # Network total
        my ($net_recv, $net_send) = (0, 0);
        
        foreach my $net (keys %index_net) {
            $net_recv += $cols[$index_net{$net}];
            $net_send += $cols[$index_net{$net} + 1];
        }
        
        $entry .= ":${net_recv}:${net_send}";
        
        # Network individual
        foreach my $net (sort keys %index_net) {
            $net_recv = $cols[$index_net{$net}];
            $net_send = $cols[$index_net{$net} + 1];
            
            $entry .= ":${net_recv}:${net_send}";
        }
        
        push @entries, $entry;
    }
    
    RRDs::update($rrd_file, @entries);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
}

sub create_dir {
    eval {
        mkpath($report_dir);
    };
    
    if ($@) {
        &delete_rrd();
        die $@;
    }
}

sub create_graph {
    my (@template, @options);
    my $window = (floor(($end_time - $start_time) / 3600) + 1) * 60;
    
    # Template
    push @template, '--start';
    push @template, $epoch;
    
    push @template, '--end';
    push @template, $epoch + $end_time - $start_time;
    
    push @template, '--width';
    push @template, $width;
    
    push @template, '--height';
    push @template, $height;
    
    push @template, '--lower-limit';
    push @template, 0;
    
    push @template, '--rigid';
    
    # Processes running
    @options = @template;
    
    push @options, '--title';
    push @options, 'Processes running';
    
    push @options, "DEF:RUN=${rrd_file}:PROCS_RUN:AVERAGE";
    push @options, "AREA:RUN#${colors[0]}:running";
    
    push @options, "CDEF:RUN_AVG=RUN,${window},TREND";
    push @options, "LINE1:RUN_AVG#${colors[1]}:running_${window}sec";
    
    RRDs::graph("${report_dir}/procs_run.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # Processes blocked
    @options = @template;
    
    push @options, '--title';
    push @options, 'Processes blocked';
    
    push @options, "DEF:BLK=${rrd_file}:PROCS_BLK:AVERAGE";
    push @options, "AREA:BLK#${colors[0]}:blocked";
    
    push @options, "CDEF:BLK_AVG=BLK,${window},TREND";
    push @options, "LINE1:BLK_AVG#${colors[1]}:blocked_${window}sec";
    
    RRDs::graph("${report_dir}/procs_blk.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # Processes new
    @options = @template;
    
    push @options, '--title';
    push @options, 'Processes new (/sec)';
    
    push @options, "DEF:NEW=${rrd_file}:PROCS_NEW:AVERAGE";
    push @options, "AREA:NEW#${colors[0]}:new";
    
    push @options, "CDEF:NEW_AVG=NEW,${window},TREND";
    push @options, "LINE1:NEW_AVG#${colors[1]}:new_${window}sec";
    
    RRDs::graph("${report_dir}/procs_new.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # Memory
    @options = @template;
    
    push @options, '--upper-limit';
    push @options, $memory_size;
    
    push @options, '--base';
    push @options, 1024;
    
    push @options, '--title';
    push @options, 'Memory Usage (Bytes)';
    
    push @options, "DEF:USED=${rrd_file}:MEMORY_USED:AVERAGE";
    push @options, "AREA:USED#${colors[0]}:used";
    
    push @options, "DEF:BUFF=${rrd_file}:MEMORY_BUFF:AVERAGE";
    push @options, "STACK:BUFF#${colors[1]}:buffer";
    
    push @options, "DEF:CACH=${rrd_file}:MEMORY_CACH:AVERAGE";
    push @options, "STACK:CACH#${colors[2]}:cached";
    
    RRDs::graph("${report_dir}/memory.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # Paging
    @options = @template;
    
    push @options, '--base';
    push @options, 1024;
    
    push @options, '--title';
    push @options, 'Paging (Bytes/sec)';
    
    push @options, "DEF:IN=${rrd_file}:PAGE_IN:AVERAGE";
    push @options, "LINE1:IN#${colors[0]}:page_in";
    
    push @options, "DEF:OUT=${rrd_file}:PAGE_OUT:AVERAGE";
    push @options, "LINE1:OUT#${colors[1]}:page_out";
    
    RRDs::graph("${report_dir}/paging.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # Disk total
    @options = @template;
    
    if ($disk_limit != 0) {
        push @options, '--upper-limit';
        push @options, $disk_limit;
    }
    
    push @options, '--base';
    push @options, 1024;
    
    push @options, '--title';
    push @options, 'Disk I/O total (Bytes/sec)';
    
    push @options, "DEF:READ=${rrd_file}:DISK_READ:AVERAGE";
    push @options, "LINE1:READ#${colors[0]}:read";
    
    push @options, "DEF:WRIT=${rrd_file}:DISK_WRIT:AVERAGE";
    push @options, "LINE1:WRIT#${colors[1]}:write";
    
    RRDs::graph("${report_dir}/disk.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # Disk individual
    foreach my $disk (sort keys %index_disk) {
        @options = @template;
        
        if ($disk_limit != 0) {
            push @options, '--upper-limit';
            push @options, $disk_limit;
        }
        
        push @options, '--base';
        push @options, 1024;
        
        push @options, '--title';
        push @options, "Disk I/O ${disk} (Bytes/sec)";
        
        push @options, "DEF:READ=${rrd_file}:DISK_${disk}_READ:AVERAGE";
        push @options, "LINE1:READ#${colors[0]}:read";
        
        push @options, "DEF:WRIT=${rrd_file}:DISK_${disk}_WRIT:AVERAGE";
        push @options, "LINE1:WRIT#${colors[1]}:write";
        
        RRDs::graph("${report_dir}/disk_${disk}.png", @options);
        
        if (my $error = RRDs::error) {
            &delete_rrd();
            die $error;
        }
    }
    
    # Interrupts
    @options = @template;
    
    push @options, '--title';
    push @options, 'Interrupts (/sec)';
    
    push @options, "DEF:INT=${rrd_file}:INTERRUPTS:AVERAGE";
    push @options, "LINE1:INT#${colors[0]}:interrupts";
    
    RRDs::graph("${report_dir}/interrupts.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # Context Switches
    @options = @template;
    
    push @options, '--title';
    push @options, 'Context Switches (/sec)';
    
    push @options, "DEF:CSW=${rrd_file}:CSWITCHES:AVERAGE";
    push @options, "LINE1:CSW#${colors[0]}:context_switches";
    
    RRDs::graph("${report_dir}/cswitches.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # CPU total
    @options = @template;
    
    push @options, '--upper-limit';
    push @options, 100;
    
    push @options, '--title';
    push @options, 'CPU Usage total (%)';
    
    push @options, "DEF:USR=${rrd_file}:CPU_USR:AVERAGE";
    push @options, "AREA:USR#${colors[0]}:user";
    
    push @options, "DEF:SYS=${rrd_file}:CPU_SYS:AVERAGE";
    push @options, "STACK:SYS#${colors[1]}:system";
    
    push @options, "DEF:HIQ=${rrd_file}:CPU_HIQ:AVERAGE";
    push @options, "STACK:HIQ#${colors[2]}:hardirq";
    
    push @options, "DEF:SIQ=${rrd_file}:CPU_SIQ:AVERAGE";
    push @options, "STACK:SIQ#${colors[3]}:softirq";
    
    push @options, "DEF:WAI=${rrd_file}:CPU_WAI:AVERAGE";
    push @options, "STACK:WAI#${colors[4]}:wait";
    
    RRDs::graph("${report_dir}/cpu.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # CPU individual
    foreach my $cpu (sort { $a <=> $b } keys %index_cpu) {
        @options = @template;
        
        push @options, '--upper-limit';
        push @options, 100;
        
        push @options, '--title';
        push @options, "CPU Usage cpu${cpu} (%)";
        
        push @options, "DEF:USR=${rrd_file}:CPU${cpu}_USR:AVERAGE";
        push @options, "AREA:USR#${colors[0]}:user";
        
        push @options, "DEF:SYS=${rrd_file}:CPU${cpu}_SYS:AVERAGE";
        push @options, "STACK:SYS#${colors[1]}:system";
        
        push @options, "DEF:HIQ=${rrd_file}:CPU${cpu}_HIQ:AVERAGE";
        push @options, "STACK:HIQ#${colors[2]}:hardirq";
        
        push @options, "DEF:SIQ=${rrd_file}:CPU${cpu}_SIQ:AVERAGE";
        push @options, "STACK:SIQ#${colors[3]}:softirq";
        
        push @options, "DEF:WAI=${rrd_file}:CPU${cpu}_WAI:AVERAGE";
        push @options, "STACK:WAI#${colors[4]}:wait";
        
        RRDs::graph("${report_dir}/cpu${cpu}.png", @options);
        
        if (my $error = RRDs::error) {
            &delete_rrd();
            die $error;
        }
    }
    
    # Network total
    @options = @template;
    
    if ($net_limit != 0) {
        push @options, '--upper-limit';
        push @options, $net_limit;
    }
    
    push @options, '--base';
    push @options, 1024;
    
    push @options, '--title';
    push @options, 'Network I/O total (Bytes/sec)';
    
    push @options, "DEF:RECV=${rrd_file}:NET_RECV:AVERAGE";
    push @options, "LINE1:RECV#${colors[0]}:receive";
    
    push @options, "DEF:SEND=${rrd_file}:NET_SEND:AVERAGE";
    push @options, "LINE1:SEND#${colors[1]}:send";
    
    RRDs::graph("${report_dir}/net.png", @options);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
    
    # Network individual
    foreach my $net (sort keys %index_net) {
        @options = @template;
        
        if ($net_limit != 0) {
            push @options, '--upper-limit';
            push @options, $net_limit;
        }
        
        push @options, '--base';
        push @options, 1024;
        
        push @options, '--title';
        push @options, "Network I/O ${net} (Bytes/sec)";
        
        push @options, "DEF:RECV=${rrd_file}:NET_${net}_RECV:AVERAGE";
        push @options, "LINE1:RECV#${colors[0]}:receive";
        
        push @options, "DEF:SEND=${rrd_file}:NET_${net}_SEND:AVERAGE";
        push @options, "LINE1:SEND#${colors[1]}:send";
        
        RRDs::graph("${report_dir}/net_${net}.png", @options);
        
        if (my $error = RRDs::error) {
            &delete_rrd();
            die $error;
        }
    }
}

sub delete_rrd {
    unlink $rrd_file;
}

sub create_html {
    my $hostname_enc = encode_entities($hostname);
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime($start_time);
    
    my $datetime = sprintf("%04d/%02d/%02d %02d:%02d:%02d",
        $year + 1900, $mon + 1, $mday, $hour, $min, $sec); 
        
    my $duration = $end_time - $start_time;
    
    open(my $fh, '>', "${report_dir}/index.html") or die $!;
    
    print $fh <<_EOF_;
<!DOCTYPE html>
<html>
  <head>
    <title>${hostname_enc} ${datetime} - dstat2graphs</title>
    <link href="${top_dir}/css/bootstrap.min.css" rel="stylesheet" />
    <style type="text/css">
      body {
        padding-top: 20px;
        padding-bottom: 20px;
      }
      .sidebar-nav {
        padding: 12px 4px;
      }
      .hero-unit {
        padding: 24px;
      }
    </style>
  </head>
  <body>
    <div class="container-fluid">
      <div class="row-fluid">
        <div class="span3">
          <div class="well sidebar-nav">
            <ul class="nav nav-list">
              <li class="nav-header">Processes</li>
              <li><a href="#procs_run">Processes running</a></li>
              <li><a href="#procs_blk">Processes blocked</a></li>
              <li><a href="#procs_new">Processes new</a></li>
              <li class="nav-header">Memory Usage</li>
              <li><a href="#memory">Memory Usage</a></li>
              <li class="nav-header">Paging</li>
              <li><a href="#paging">Paging</a></li>
              <li class="nav-header">Disk I/O</li>
              <li><a href="#disk">Disk I/O total</a></li>
_EOF_
    
    foreach my $disk (sort keys %index_disk) {
        print $fh ' ' x 14;
        print $fh "<li><a href=\"#disk_${disk}\">Disk I/O ${disk}</a></li>\n";
    }
    
    print $fh <<_EOF_;
              <li class="nav-header">System</li>
              <li><a href="#interrupts">Interrupts</a></li>
              <li><a href="#cswitches">Context Switches</a></li>
              <li class="nav-header">CPU Usage</li>
              <li><a href="#cpu">CPU Usage total</a></li>
_EOF_
    
    foreach my $cpu (sort { $a <=> $b } keys %index_cpu) {
        print $fh ' ' x 14;
        print $fh "<li><a href=\"#cpu${cpu}\">CPU Usage cpu${cpu}</a></li>\n";
    }
    
    print $fh <<_EOF_;
              <li class="nav-header">Network I/O</li>
              <li><a href="#net">Network I/O total</a></li>
_EOF_
    
    foreach my $net (sort keys %index_net) {
        print $fh ' ' x 14;
        print $fh "<li><a href=\"#net_${net}\">Network I/O ${net}</a></li>\n";
    }
    
    print $fh <<_EOF_;
            </ul>
          </div>
        </div>
        <div class="span9">
          <div class="hero-unit">
            <h1>dstat2graphs</h1>
            <ul>
              <li>Hostname: ${hostname_enc}</li>
              <li>Datetime: ${datetime}</li>
              <li>Duration: ${duration} (seconds)</li>
            </ul>
          </div>
          <h2>Processes</h2>
          <h3 id="procs_run">Processes running</h3>
          <p><img src="procs_run.png" alt="Processes running" /></p>
          <h3 id="procs_blk">Processes blocked</h3>
          <p><img src="procs_blk.png" alt="Processes blocked" /></p>
          <h3 id="procs_new">Processes new</h3>
          <p><img src="procs_new.png" alt="Processes new" /></p>
          <hr />
          <h2>Memory Usage</h2>
          <h3 id="memory">Memory Usage</h3>
          <p><img src="memory.png" alt="Memory Usage" /></p>
          <hr />
          <h2>Paging</h2>
          <h3 id="paging">Paging</h3>
          <p><img src="paging.png" alt="Paging" /></p>
          <hr />
          <h2>Disk I/O</h2>
          <h3 id="disk">Disk I/O total</h3>
          <p><img src="disk.png" alt="Disk I/O total" /></p>
_EOF_
    
    foreach my $disk (sort keys %index_disk) {
        print $fh ' ' x 10;
        print $fh "<h3 id=\"disk_${disk}\">Disk I/O ${disk}</h3>\n";
        print $fh ' ' x 10;
        print $fh "<p><img src=\"disk_${disk}.png\" alt=\"Disk I/O ${disk}\"></p>\n";
    }
    
    print $fh <<_EOF_;
          <hr />
          <h2>System</h2>
          <h3 id="interrupts">Interrupts</h3>
          <p><img src="interrupts.png" alt="Interrupts" /></p>
          <h3 id="cswitches">Context Switches</h3>
          <p><img src="cswitches.png" alt="Context Switches" /></p>
          <hr />
          <h2>CPU Usage</h2>
          <h3 id="cpu">CPU Usage total</h3>
          <p><img src="cpu.png" alt="CPU Usage total" /></p>
_EOF_
    
    foreach my $cpu (sort { $a <=> $b } keys %index_cpu) {
        print $fh ' ' x 10;
        print $fh "<h3 id=\"cpu${cpu}\">CPU Usage cpu${cpu}</h3>\n";
        print $fh ' ' x 10;
        print $fh "<p><img src=\"cpu${cpu}.png\" alt=\"CPU Usage cpu${cpu}\" /></p>\n";
    }
    
    print $fh <<_EOF_;
          <hr />
          <h2>Network I/O</h2>
          <h3 id="net">Network I/O total</h3>
          <p><img src="net.png" alt="Network I/O total" /></p>
_EOF_
    
    foreach my $net (sort keys %index_net) {
        print $fh ' ' x 10;
        print $fh "<h3 id=\"net_${net}\">Network I/O ${net}</h3>\n";
        print $fh ' ' x 10;
        print $fh "<p><img src=\"net_${net}.png\" alt=\"Network I/O ${net}\" /></p>\n";
    }
    
    print $fh <<_EOF_;
        </div>
      </div>
      <hr />
      <div class="footer">
        (c) 2012, Sadao Hiratsuka.
      </div>
    </div>
    <script src="${top_dir}/js/jquery-1.7.2.min.js"></script>
    <script src="${top_dir}/js/bootstrap.min.js"></script>
  </body>
</html>
_EOF_
    
    close($fh);
}

sub random_str {
    my $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    my $length = length($chars);
    my $str = '';
    
    for (my $i = 0; $i < 16; $i++) {
        $str .= substr($chars, int(rand($length)), 1);
    }
    
    return $str;
}

sub get_unixtime {
    my ($year, $datetime) = @_;
    my $unixtime = 0;
    
    if ($datetime =~ /^(\d+)-(\d+) (\d+):(\d+):(\d+)/) {
        $unixtime = timelocal($5, $4, $3, $1, $2 -1, $year);
    }
    
    return $unixtime;
}

