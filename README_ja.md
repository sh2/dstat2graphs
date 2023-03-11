# dstat2graphs

dstatのCSVファイルをもとにグラフを描画するウェブアプリケーションです。
以下のオプションで出力されたファイルを受け付けます。

    $ dstat -tfvn --output data.csv [delay]
    $ dstat -tfvnrl --output data.csv [delay]

## サンプル

以下のデモサイトで実際に使用できます。

- [dstat2graphs - dbstudy.info](https://dbstudy.info/dstat2graphs/)

出力結果のサンプルです。

- [k01sl6.local 2017/01/29 17:54:14 - dstat2graphs](https://dbstudy.info/sample/reports/20230312-002928_HTurMGXN/)

デモサイトにアップロードされたデータは誰でも閲覧できます。
そのため他者に見られて困るデータはアップロードしないでください。

## セットアップ

### コンテナを利用する場合

Podman/Buildahで動作を確認しています。
まず`build.sh`を用いてコンテナイメージをビルドします。

    $ ./build.sh

コンテナイメージをビルドしたら、TCPの80番ポートを公開するようにしてコンテナを起動します。

    $ podman run --detach --publish=8080:80 --name=dstat2graphs dstat2graphs:latest

コンテナが起動したら、ウェブブラウザで http://localhost:8080/dstat2graphs/ を開いてください。

### Rocky Linux 9に導入する場合

必要なパッケージをインストールします。

    $ sudo dnf install httpd perl-Archive-Zip perl-HTML-Parser php rrdtool-perl

Apache HTTP Serverを起動して、外部からアクセスできるようにファイアウォールのルールを追加します。

    $ sudo systemctl enable httpd
    $ sudo systemctl start httpd
    $ sudo firewall-cmd --add-service=http --permanent
    $ sudo firewall-cmd --reload

アプリケーションのソースコードを取得して、必要なファイルをドキュメントルート配下にコピーします。

    $ git clone https://github.com/sh2/dstat2graphs.git
    $ sudo rsync -rp dstat2graphs/src/ /var/www/html/dstat2graphs

アプリケーションが出力するレポートを格納するディレクトリを準備します。
このディレクトリは`apache`ユーザーが書き込める必要があり、SELinuxが有効な場合は`httpd_sys_rw_content`タイプでラベル付けされている必要があります。

    $ sudo mkdir /var/www/html/dstat2graphs/reports
    $ sudo chown apache:apache /var/www/html/dstat2graphs/reports
    $ sudo semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/dstat2graphs/reports(/.*)?'
    $ sudo restorecon -R /var/www/html/dstat2graphs/reports

ここまで設定できたら、ウェブブラウザで http://localhost/dstat2graphs/ を開いてください。

### Ubuntu 22.04 LTSに導入する場合

必要なパッケージをインストールします。

    $ sudo apt update
    $ sudo apt install apache2 libarchive-zip-perl libhtml-parser-perl librrds-perl php

Apache HTTP Serverを起動します。

    $ sudo systemctl enable apache2
    $ sudo systemctl start apache2

アプリケーションのソースコードを取得して、必要なファイルをドキュメントルート配下にコピーします。

    $ git clone https://github.com/sh2/dstat2graphs.git
    $ sudo rsync -rp dstat2graphs/src/ /var/www/html/dstat2graphs

アプリケーションが出力するレポートを格納するディレクトリを準備します。
このディレクトリは`www-data`ユーザーが書き込める必要があります。

    $ sudo mkdir /var/www/html/dstat2graphs/reports
    $ sudo chown www-data:www-data /var/www/html/dstat2graphs/reports

ここまで設定できたら、ウェブブラウザで http://localhost/dstat2graphs/ を開いてください。

### PHPの設定について

dstatが出力するCSVファイルのサイズに応じて、PHPで大きなファイルを扱えるようにしておく必要があります。
Rocky Linux 9では`/etc/php.d/php_dstat.ini`、Ubuntu 22.04 LTSでは`/etc/php/8.1/apache2/conf.d/php_dstat.ini`といった設定ファイルを作成し、パラメーター`upload_max_filesize`にアップロードしたいCSVファイルサイズよりも大きな値を指定してください。
このとき`upload_max_filesize` < `post_max_size` < `memory_limit`という関係を満たすよう、必要に応じて他のパラメーターも設定してください。

    memory_limit = 128M
    post_max_size = 64M
    upload_max_filesize = 32M

設定ファイルを作成したらサービスをリロードします。
event MPMが有効化されているRocky Linux 9では`php-fpm`サービスをリロードします。

    $ sudo systemctl reload php-fpm

perfork MPMが有効化されているUbuntu 22.04 LTSでは`apache2`サービスをリロードします。

    $ sudo systemctl reload apache2

## pcp-dstat使用時の注意点

dstatにはDag Wieers氏が開発したオリジナル版のdstatと、Red Hat社が開発したpcp-dstatがあります。オリジナル版はPython 2で開発されており、pcp-dstatはPython 3で開発されています。

dstat2graphsは両方のdstatに対応していますが、pcp-dstatは最近のバージョンまでCSV出力機能にいくつか不具合があり、dstat2graphsでCSVファイルを読み込むことができませんでした。不具合の概要とディストリビューションごとの状況を以下に示します。

- 不具合1 … -f(--full)オプションが正常に動作しません。この不具合はpcp-dstat 5.2.1で修正されました。
- 不具合2 … CSVファイルのヘッダが一部欠落します。この不具合はpcp-dstat 6.0.xで修正される見込みです。

|ディストリビューション|dstatバージョン|CSV出力機能|
|-|-|-|
|CentOS 7|dstat 0.7.2|正常に動作します|
|Rocky Linux 8|pcp-dstat 5.3.7|不具合2の影響を受けます|
|Rocky Linux 9|pcp-dstat 5.3.7|不具合2の影響を受けます|
|Ubuntu 18.04 LTS|dstat 0.7.3|正常に動作します|
|Ubuntu 20.04 LTS|pcp-dstat 5.0.3|不具合1、2の影響を受けます|
|Ubuntu 22.04 LTS|pcp-dstat 5.3.6|不具合2の影響を受けます|

不具合の影響を受けるディストリビューションでは、GitHubから`pcp-dstat.py`の最新バージョンを取得して利用することをおすすめします。

    $ curl -LO https://raw.githubusercontent.com/performancecopilot/pcp/main/src/pcp/dstat/pcp-dstat.py
    $ chmod +x pcp-dstat.py

不具合2については実行時の工夫で回避できます。
以下のようにdstatの標準出力をリダイレクトすると、内部動作が変わってCSVファイルのヘッダが正常に出力されるようになります。

    $ dstat -tfvnrl --output data.csv 1 > stdout.log

## Web UI

ウェブブラウザでURLを開くと、CSVファイルをアップロードする画面が表示されます。
CSVファイルを指定してUploadボタンを押すと、グラフが描画されます。

- dstat CSV File
    - dstat CSV File … アップロードするCSVファイルを指定します。
- Graph Size
    - Width … グラフの横サイズを指定します。単位はピクセルです。
    - Height … グラフの縦サイズを指定します。単位はピクセルです。
- Graph Upper Limits
    - Disk I/O … Disk I/Oのグラフについて、Y軸の最大値を指定します。
      単位はバイト/秒です。
      0を指定すると自動調節します。
    - Disk IOPS … Disk IOPSのグラフについて、Y軸の最大値を指定します。
      単位は回/秒です。
      0を指定すると自動調節します。
    - Network I/O … Network I/Oのグラフについて、Y軸の最大値を指定します。
      単位はバイト/秒です。
      0を指定すると自動調節します。
- Other Settings
    - X-Axis … X軸に経過時間を表示するか実際の時刻を表示するかを選択します。
    - Offset … 指定した時間だけ、CSVファイルの先頭からカットします。
      単位は秒です。
    - Duration … CSVファイルの先頭、あるいはOffset位置から指定した時間のみ描画します。
      単位は秒です。
      0を指定するとCSVファイルの末尾まで描画します。

## Perl CLI

Perlスクリプトdstat2graphs.pl単体でグラフを作成することができます。
コマンドラインオプションは以下の通りで、最後の二つを除きすべて指定する必要があります。

    $ perl dstat2graph.pl csv_file report_dir width height disk_limit net_limit offset duration [io_limit] [is_actual]

- report_dir グラフを出力するディレクトリを指定します。
  ディレクトリが存在しない場合は自動作成します。

report_dir以外のオプションは、Web UIから指定できるものと同じです。
