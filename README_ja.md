# dstat2graphs

dstatのCSVファイルをもとにグラフを描画するWebアプリケーションです。以下のオプションで出力されたファイルを受け付けます。

    $ dstat -tfvn --output log.csv [delay]
    $ dstat -tfvnrl --output log.csv [delay]

## サンプル

以下のデモサイトで実際に使用できます。

- [dstat2graphs - dbstudy.info](https://dbstudy.info/dstat2graphs/)

出力結果のサンプルです。

- [k01sl6.local 2017/01/29 17:54:14 - dstat2graphs](https://dbstudy.info/dstat2graphs/reports/20170129-190238_KRmlSfIV/)

デモサイトの使用に際しては、次の点に注意してください。

- アップロードできるCSVファイルサイズは、4MBytesまでです。
- アクセス制御はしていませんので、他者に見られて困るデータはアップロードしないでください。

## セットアップ

### コンテナを利用する場合

Podman/Buildahで動作を確認しています。まず`build.sh`を用いてコンテナイメージをビルドします。

    $ ./build.sh

コンテナイメージをビルドしたら、TCPの80番ポートを公開するようにしてコンテナを起動します。

    $ podman run --detach --publish=8080:80 --name=dstat2graphs dstat2graphs:latest

コンテナが起動したら、ウェブブラウザで http://localhost:8080/dstat2graphs/ を開いてください。

### Rocky Linux 9に導入する場合

最初に必要なパッケージをインストールします。

    $ sudo dnf install httpd perl-Archive-Zip perl-HTML-Parser php rrdtool-perl

Apache HTTP Serverを起動して、外部からアクセスできるようにファイアウォールのルールを追加します。

    $ sudo systemctl enable httpd
    $ sudo systemctl start httpd
    $ sudo firewall-cmd --add-service=http --permanent
    $ sudo firewall-cmd --reload

アプリケーションのソースコードを取得して、必要なファイルをドキュメントルート配下にコピーします。

    $ git clone https://github.com/sh2/dstat2graphs.git
    $ sudo rsync -rp dstat2graphs/src/ /var/www/html/dstat2graphs

アプリケーションが出力するレポートを格納するディレクトリを準備します。このディレクトリは`apache`ユーザーが書き込める必要があり、SELinuxが有効な場合は`httpd_sys_rw_content`タイプでラベル付けされている必要があります。

    $ sudo mkdir /var/www/html/dstat2graphs/reports
    $ sudo chown apache:apache /var/www/html/dstat2graphs/reports
    $ sudo semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/dstat2graphs/reports(/.*)?'
    $ sudo restorecon -R /var/www/html/dstat2graphs/reports

ここまで設定できたら、ウェブブラウザで http://localhost/dstat2graphs/ を開いてください。

### Ubuntu 22.04 LTSに導入する場合

WIP

### 以前の構築手順

Red Hat Enterprise Linux 6/7と、それらのクローンディストリビューションを対象にしています。

Apache HTTP ServerとPHPがインストールされている必要があります。初めにパッケージグループWeb ServerとPHP Supportをインストールしてください。

    # yum groupinstall 'Web Server' 'PHP Support'

続いて以下のパッケージをインストールしてください。

- perl-Archive-Zip
- perl-HTML-Parser
- rrdtool
- rrdtool-perl

<!-- dummy comment line for breaking list -->

    # yum install perl-Archive-Zip perl-HTML-Parser rrdtool rrdtool-perl

本ツールは作業ディレクトリとして/dev/shmを使用します。以下のようにして作業ディレクトリを作成し、apacheユーザが書き込みを行える状態にしてください。本ツールを恒久的に使用する場合は、/etc/rc.localに作業ディレクトリ作成処理を追加するなどしてください。

    # mkdir /dev/shm/dstat2graphs
    # chown apache:apache /dev/shm/dstat2graphs

Apache HTTP Serverのドキュメントルート配下にスクリプトを配置してください。スクリプトを配置したディレクトリの直下にreportsディレクトリを作成し、apacheユーザが書き込みを行える状態にしてください。

    # mkdir <document_root>/<script_dir>/reports
    # chown apache:apache <document_root>/<script_dir>/reports

dstatのCSVファイルサイズが大きい場合、PHPで大きなファイルを扱えるようにしておく必要があります。/etc/php.iniにおいてパラメータupload\_max\_filesizeをCSVファイルサイズよりも大きな値に調節してください。このときmemory\_limit &gt; post\_max\_size &gt; upload\_max\_filesizeという関係を満たす必要があります。

    memory_limit = 128M
    post_max_size = 8M
    upload_max_filesize = 2M

## ウェブ画面からの使い方

Webブラウザでhttp://&lt;server\_host&gt;/&lt;script\_dir&gt;/にアクセスすると、CSVファイルをアップロードする画面が表示されます。CSVファイルを指定してUploadボタンを押すと、グラフが描画されます。

- dstat CSV File
    - dstat CSV File … アップロードするCSVファイルを指定します。
- Graph Size
    - Width … グラフの横サイズを指定します。単位はピクセルです。
    - Height … グラフの縦サイズを指定します。単位はピクセルです。
- Graph Upper Limits
    - Disk I/O … Disk I/Oのグラフについて、Y軸の最大値を指定します。単位はバイト/秒です。0を指定すると自動調節します。
    - Disk IOPS … Disk IOPSのグラフについて、Y軸の最大値を指定します。単位は回/秒です。0を指定すると自動調節します。
    - Network I/O … Network I/Oのグラフについて、Y軸の最大値を指定します。単位はバイト/秒です。0を指定すると自動調節します。
- Other Settings
    - X-Axis … X軸に経過時間を表示するか実際の時刻を表示するかを選択します。
    - Offset … 指定した時間だけ、CSVファイルの先頭からカットして描画します。単位は秒です。
    - Duration … CSVファイルの先頭、あるいはOffset位置から指定した時間のみ描画します。単位は秒です。0を指定するとCSVファイルの末尾まで描画します。

## Perlスクリプト単体での使い方

Perlスクリプトdstat2graphs.plを単体で使用してグラフを描画することが可能です。作業ディレクトリ/dev/shm/dstat2graphsに対してスクリプト実行ユーザが書き込みを行える状態にしておいてください。コマンドラインオプションは以下の通りです。最後の二つを除きすべて指定する必要があります。

    $ perl dstat2graph.pl csv_file report_dir width height disk_limit net_limit offset duration [io_limit] [is_actual]

- report_dir グラフを出力するディレクトリを指定します。ディレクトリが存在しない場合は自動作成します。

report_dir以外のオプションは、ウェブ画面から指定できるものと同じです。
