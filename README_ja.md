dstat2graphs
============

dstatのCSVログファイルをグラフに変換します。

セットアップ
------------

Red Hat Enterprise Linux 5、6と、それらのクローンディストリビューションを対象にしています。

以下のパッケージが必要ですので、あらかじめインストールしておいてください。Red Hat Enterprise Linux 5の場合、rrdtool、rrdtool-perlはEPELリポジトリから入手してください。

* perl-Archive-Zip
* perl-HTML-Parser
* rrdtool
* rrdtool-perl

本ツールは作業ディレクトリとして/dev/shmを利用します。以下のようにして作業ディレクトリを作成してください。本ツールを恒久的に使用する場合は、/etc/rc.localに作業ディレクトリ作成処理を記載するなどしてください。

    # mkdir /dev/shm/dstat2graphs
    # chown apache:apache /dev/shm/dstat2graphs

Apacheのドキュメントルート配下にスクリプトを配置してください。スクリプトを配置したディレクトリの直下にreportsディレクトリを作成し、apacheユーザが書き込みを行える状態にしてください。

    # mkdir (document_root)/(script_dir)/reports
    # chmod 777 (document_root>/<script_dir>/reports

ウェブ画面からの使い方
----------------------

(あとで)

Perlスクリプト単体での使い方
----------------------------

(あとで)

