# dstat2graphs

dstatのCSVファイルをもとにグラフを描画するWebアプリケーションです。以下のオプションで出力されたファイルを受け付けます。

    $ dstat -tfvn --output log.csv [delay]
    $ dstat -tfvnrl --output log.csv [delay]

## サンプル

以下のデモサイトで実際に使用できます。

- [dstat2graphs - dbstudy.info](http://dbstudy.info/dstat2graphs/)

出力結果のサンプルです。

- [k02c5 2012/05/04 20:03:53 - dstat2graphs](http://dbstudy.info/dstat2graphs/reports/20140309-132019_rbntbQci/)

デモサイトの使用に際しては、次の点に注意してください。

- アップロードできるCSVファイルサイズは、4MBytesまでです。
- アクセス制御機能はありませんので、機密性の高いデータはアップロードしないでください。

## セットアップ

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
