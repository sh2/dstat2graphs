# dstat2graphs

This is a web application that draws graphs based on dstat CSV files.
It accepts files output with the following options.

    $ dstat -tfvn --output data.csv [delay]
    $ dstat -tfvnrl --output data.csv [delay]

## Sample

You can actually use the following demo site.

- [dstat2graphs - dbstudy.info](https://dbstudy.info/dstat2graphs/)

Here is a sample of the output results.

- [k01sl6.local 2017/01/29 17:54:14 - dstat2graphs](https://dbstudy.info/sample/reports/20230312-002928_HTurMGXN/)

Data uploaded to the demo site can be viewed by anyone.
Therefore, please do not upload data that you do not want others to see.

## Setup Instructions

### Using a container

We have tested the operation with Podman/Buildah.
First, build the container image using `build.sh`.

    $ ./build.sh

After building the container image, start the container with TCP port 80 exposed.

    $ podman run --detach --publish=8080:80 --name=dstat2graphs dstat2graphs:latest

Once the container is started, open http://localhost:8080/dstat2graphs/ in your web browser.

### To install on Rocky Linux 9

Install the necessary packages.

    $ sudo dnf install httpd perl-Archive-Zip perl-HTML-Parser php rrdtool-perl

Start Apache HTTP Server and add firewall rules to allow external access.

    $ sudo systemctl enable httpd
    $ sudo systemctl start httpd
    $ sudo firewall-cmd --add-service=http --permanent
    $ sudo firewall-cmd --reload

Get the application source code and copy the necessary files under the document root.

    $ git clone https://github.com/sh2/dstat2graphs.git
    $ sudo rsync -rp dstat2graphs/src/ /var/www/html/dstat2graphs

Prepare a directory to store the reports output by the application.
This directory must be writable by the `apache` user and labeled with the `httpd_sys_rw_content` type if SELinux is enabled.

    $ sudo mkdir /var/www/html/dstat2graphs/reports
    $ sudo chown apache:apache /var/www/html/dstat2graphs/reports
    $ sudo semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/dstat2graphs/reports(/.*)?'
    $ sudo restorecon -R /var/www/html/dstat2graphs/reports

Once you have set this up, open http://localhost/dstat2graphs/ in your web browser.

### To install on Ubuntu 22.04 LTS

Install the necessary packages.

    $ sudo apt update
    $ sudo apt install apache2 libarchive-zip-perl libhtml-parser-perl librrds-perl php

Start Apache HTTP Server.

    $ sudo systemctl enable apache2
    $ sudo systemctl start apache2

Get the application source code and copy the necessary files under the document root.

    $ git clone https://github.com/sh2/dstat2graphs.git
    $ sudo rsync -rp dstat2graphs/src/ /var/www/html/dstat2graphs

Prepare a directory to store the reports output by the application.
This directory must be writable by the `www-data` user.

    $ sudo mkdir /var/www/html/dstat2graphs/reports
    $ sudo chown www-data:www-data /var/www/html/dstat2graphs/reports

Once you have set this up, open http://localhost/dstat2graphs/ in your web browser.

### Configuration of PHP

Depending on the size of the CSV file output by dstat, PHP must be able to handle large files.
Create a configuration file such as `/etc/php.d/php_dstat.ini` on Rocky Linux 9 or `/etc/php/8.1/apache2/conf.d/php_dstat.ini` on Ubuntu 22.04 LTS and set the parameter `upload_ max_filesize` to a value larger than the size of the CSV file you want to upload.
At this time, set other parameters as necessary to satisfy the relation `upload_max_filesize` < `post_max_size` < `memory_limit`.

    memory_limit = 128M
    post_max_size = 64M
    upload_max_filesize = 32M

After creating the configuration file, reload the service.
On Rocky Linux 9 with event MPM enabled, reload the `php-fpm` service.

    $ sudo systemctl reload php-fpm

On Ubuntu 22.04 LTS with perfork MPM enabled, reload the `apache2` service.

    $ sudo systemctl reload apache2

## Notes on using pcp-dstat

There are two versions of dstat: the original version developed by Dag Wieers and pcp-dstat developed by Red Hat. The original version is developed in Python 2, while pcp-dstat is developed in Python 3.

Although dstat2graphs supports both dstats, pcp-dstat had some bugs in its CSV output function until the recent version, and it was not possible to read CSV files with dstat2graphs. A summary of the bugs and their status by distribution is given below.

- Bug 1 ... The -f (--full) option does not work properly. This bug has been fixed in pcp-dstat 5.2.1.
- Bug 2 ... Some headers of CSV files are missing. This bug is expected to be fixed in pcp-dstat 6.0.x.

|distribution|dstat version|CSV output function|
|-|-|-|
|CentOS 7|dstat 0.7.2|works fine|
|Rocky Linux 8|pcp-dstat 5.3.7|affected by bug 2|
|Rocky Linux 9|pcp-dstat 5.3.7|affected by bug 2
|Ubuntu 18.04 LTS|dstat 0.7.3|works fine|
|Ubuntu 20.04 LTS|pcp-dstat 5.0.3|affected by bug 1 and 2|
|Ubuntu 22.04 LTS|pcp-dstat 5.3.6|affected by bug 2|

For distributions affected by the bugs, it is recommended to obtain the latest version of `pcp-dstat.py` from GitHub and use it.

    $ curl -LO https://raw.githubusercontent.com/performancecopilot/pcp/main/src/pcp/dstat/pcp-dstat.py
    $ chmod +x pcp-dstat.py

Bug 2 can be worked around by a runtime tweak.
Redirecting the standard output of dstat as follows will change the internal behavior so that the headers of the CSV file are output properly.

    $ dstat -tfvnrl --output data.csv 1 > stdout.log

## Web UI

Open the URL in a web browser, and a screen for uploading a CSV file will appear.
Specify the CSV file and click the Upload button to draw a graph.

- dstat CSV File
    - dstat CSV File ... Specify the CSV file you want to upload.
- Graph Size
    - Width ... Specify the horizontal size of the graph. The unit is pixels.
    - Height ... Specify the vertical size of the graph. The unit is pixels.
- Graph Upper Limits
    - Disk I/O ... Specify the maximum value for the Y axis of the Disk I/O graphs.
      The unit is bytes/second.
      If 0 is specified, it is adjusted automatically.
    - Disk IOPS ... Specify the maximum value on the Y axis for the Disk IOPS graphs.
      The unit is times/second.
      If 0 is specified, it is adjusted automatically.
    - Network I/O ... Specify the maximum value on the Y axis for the Network I/O graphs.
      The unit is bytes/second.
      If 0 is specified, it is adjusted automatically.
- Other Settings
    - X-axis ... Select whether to display elapsed time or actual time on the X axis.
    - Offset ... Cuts from the beginning of the CSV file for the specified time.
      The unit is seconds.
    - Duration ... Draws a specified time from the beginning of the CSV file or from the Offset position.
      The unit is seconds.
      If 0 is specified, the CSV file is drawn to the end of the CSV file.

## Perl CLI

The Perl script dstat2graphs.pl by itself can create graphs.
The command line options are as follows, all but the last two must be specified.

    $ perl dstat2graph.pl csv_file report_dir width height disk_limit net_limit offset duration [io_limit] [is_actual]

- report_dir ... Specifies the directory to output graphs.
  If the directory does not exist, it is automatically created.

The options other than report_dir are the same as those that can be specified from the Web UI.
