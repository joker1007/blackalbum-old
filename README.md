
BlackAlbum
=============

動画ファイル、JPG in Zipファイルを管理するためのローカルウェブアプリ。

今のところMac専用。

Depends
-----------

* node >= 0.4.9
* mongodb >= 1.8.2
* ffmpegthumbnailer

* express >= 2.4.0
* mongoose >= 1.7.0
* sass >= 0.5.0
* jade >= 0.12.4
* coffee-script >= 1.1.1
* opts >= 1.2.1
* iconv >= 1.1.2
  [Macでiconvを使う場合](http://d.hatena.ne.jp/joker1007/20110723/1311406670)
* paginate-js >= 0.0.2
* socket.io >= 0.7.6
* seq >= 0.3.3
* hashish >= 0.0.4
* [zipfile](https://github.com/joker1007/node-zipfile) (fork)

Install
-----------------

前提

* nodeがインストールされていること
* localhostにmongodbがインストールされていること

````sh
$ git clone git://github.com/joker1007/blackalbum.git
$ cd blackalbum

$ npm install -g coffee-script
$ npm link coffee-script
$ npm install express mongoose sass jade opts iconv paginate-js socket.io seq hashish

$ cd node_modules
$ git clone git://github.com/joker1007/node-zipfile.git zipfile
$ cd zipfile
$ node-waf configuire
$ node-waf build

# Launch (Default Port 4000)
$ coffee app.coffee

# Launch (Change Port)
$ coffee app.coffee -p 4567

# Background Launch
$ nohup coffee app.coffee &
````


Usage
-----------

1. 監視ディレクトリ設定ページから、監視対象ディレクトリを登録
2. データベース更新のリンクをクリックする。
3. ムービーあるいはブックページから、Playerの追加を行う。
4. Playerは表示名と、再生用アプリケーションまでのフルパスを指定する。
5. 再生したいファイルのサムネイル、もしくはタイトルをクリックすると、現在選択中のプレーヤーにファイルパスが渡されて起動する


Known Issues
------------------

* ファイル更新が不安定(特にZip読み込み時)、エラー処理が甘いためしばしば落ちる。
* プレーヤー起動がMac決め打ち


ToDo
-------------

いつかやりたい

* linux対応
* 更新処理の安定化
* タグによる管理機能
* プレーヤーの分離(ムービーとブック)
* pdfファイルに対応


License
---------------

The MIT License

Copyright (c) 2011 Tomohiro Hashidate

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
