dstat2graphs
============

dstatのCSVログファイルをグラフに変換します。

セットアップ
------------

Red Hat Enterprise Linux 5、6と、
それらのクローンディストリビューションを対象にしています。

RRDtoolとPerlのRRDsモジュールが必要ですので、
Red Hat Enterprise Linux 6では以下のようにしてインストールしてください。
Red Hat Enterprise Linux 5の場合はEPELリポジトリから入手してください。

    # yum install rrdtool rrdtool-perl

PerlのArchive::Zipモジュールも必要ですので、
以下のようにしてインストールしてください。

    # yum install perl-Archive-Zip

本ツールは作業ディレクトリとして/dev/shmを利用します。
以下のようにして作業ディレクトリを作成してください。
本ツールを恒久的に使用する場合は、/etc/rc.localに
作業ディレクトリ作成処理を記載するなどしてください。

    # mkdir /dev/shm/dstat2graphs
    # chown apache:apache /dev/shm/dstat2graphs

Apacheのドキュメントルート配下にスクリプトを配置してください。
スクリプトを配置したディレクトリの直下にreportsディレクトリを作成し、
apacheユーザが書き込みを行える状態にしてください。

    # mkdir <document_root>/<script_dir>/reports
    # chmod 777 <document_root>/<script_dir>/reports

スクリプトを配置したディレクトリ直下、
およびreportsディレクトリ直下にcss、img、jsの各ディレクトリを作成し、
jQueryとTwitter Bootstrapを配置してください。

ウェブ画面からの使い方
----------------------

(あとで)

Perlスクリプト単体での使い方
----------------------------

(あとで)

