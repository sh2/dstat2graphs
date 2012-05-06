dstat2graphs
============

Converting a dstat CSV log file to graphs.

Setup
-----

    # yum install rrdtool rrdtool-perl
    # mkdir /dev/shm/dstat2graphs
    # chown apache:apache /dev/shm/dstat2graphs
    # mkdir <document_root>/<script_dir>/reports
    # chmod 777 <document_root>/<script_dir>/reports
