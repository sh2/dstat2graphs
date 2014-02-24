dstat2graphs
============

dstatのCSVログファイルをグラフに変換します。以下のオプションで出力されたファイルのみ受け付けます。

    $ dstat -tvfn --output log.csv 1

セットアップ
------------

Red Hat Enterprise Linux 6と、そのクローンディストリビューションを対象にしています。

Apatch HTTP ServerとPHPがインストールされている必要があります。初めにパッケージグループWeb ServerとPHP Supportをインストールしてください。

    # yum groupinstall 'Web Server' 'PHP Support'

続いて以下のパッケージをインストールしてください。

* perl-Archive-Zip
* rrdtool
* rrdtool-perl

<!-- dummy comment line for breaking list -->

    # yum install perl-Archive-Zip rrdtool rrdtool-perl

本ツールは作業ディレクトリとして/dev/shmを使用します。以下のようにして作業ディレクトリを作成し、apacheユーザが書き込みを行える状態にしてください。本ツールを恒久的に使用する場合は、/etc/rc.localに作業ディレクトリ作成処理を追加するなどしてください。

    # mkdir /dev/shm/dstat2graphs
    # chown apache:apache /dev/shm/dstat2graphs

Apache HTTP Serverのドキュメントルート配下にスクリプトを配置してください。スクリプトを配置したディレクトリの直下にreportsディレクトリを作成し、apacheユーザが書き込みを行える状態にしてください。

    # mkdir <document_root>/<script_dir>/reports
    # chmod 777 <document_root>/<script_dir>/reports

ウェブ画面からの使い方
----------------------

(あとで)

Perlスクリプト単体での使い方
----------------------------

(あとで)
