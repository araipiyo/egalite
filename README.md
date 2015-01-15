# Egalite

Egaliteは、Ruby用のウェブアプリケーションフレームワークです。自社用に使っているフレームワークですが、使う人の利便性などを考えてオープンソースにしてgemで公開しています。

添付ライブラリ等の説明:
* [メール送信ライブラリ](sendmail.md)
* [管理画面作成ツール](htmlbuilder.md)

## 概要

いわゆるMVC構造のフレームワークです。O/RマッパーとしてはSequelを使うことを想定しています。モデルはSequelをそのまま使いますので、本ドキュメントでは言及しません。

ビューは、独自のテンプレートエンジンを使用しており、HTMLからコードをなるべく廃するという思想で作っています。

コントローラは、メソッドの戻り値のみによって結果を返すようになっており、HTTPに対する処理の流れとして違和感がない作りになっています。

自動でXSSやCSRFを防ぐための機構を持っています。

## コントローラーの基本

	class FooController < Egalite::Controller
	  def bar(id)
	    "#{id}ですよ"
	  end
	end

このようなアクションは/foo/bar/<id>のURLで呼び出され、引数としてidが引き渡されます。出力としては文字列がそのままtext/htmlのcontent-typeで出力されます。

### デフォルトコントローラーとデフォルトアクション

	class DefaultController < Egalite::Controller
	  def get
	  end
	end

このアクションは他のコントローラーで引っかけられなかったすべてのアクセスを引き取ります。実際のURLパスはreq.pathというメソッドで取得できます。

### コントローラーの戻り値

コントローラーは戻り値として、Hash, Array, Stringを返すことができます。

Stringを返した場合は、通常のHTMLとして出力します。

Arrayを返した場合は、Rackの標準的な出力形式として扱います。すなわち``[200, {"Content-Type" => "text/html"}, "hoge"]``のように、HTTPステータスコード、レスポンスヘッダ、出力文字列の格納された配列とみなします。

Hashを返した場合は、テンプレートエンジンにHashが引き渡され、テンプレートにある対応するプレースホルダにHashの内容が埋め込まれます。Hashの代わりにSequelのモデルインスタンスを渡すこともできます。

### params

URL以外で引き渡されるパラメーター(クエリパラメータやPOSTパラメータ)はparamsというメソッド経由で参照することができます。paramsというメソッドはパラメーターの格納されたHashを返します。

	class FooController < Egalite::Controller
	  def post(id)
	    "#{params[:hoge]}: #{id}"
	  end
	end

このコントローラーが定義されている場合、/foo/524にhoge=piyoというパラメータでPOSTでアクセスした場合、出力として"piyo: 524"という文字列が出力されます。

## コントローラーのより複雑な使い方

### フック (filter)

	class MainPages < Egalite::Controller
	  def before_filter
	  end
	end

### アクセス制御イディオム

## ビューの基本

	<html>
	<body>
	プレースホルダ: &=placeholder;
	
	配列の展開:
	<group name='foo'>
	</group>
	
	if文:
	<if name='bar'>
	</if>
	
	unless文:
	<unless name='bar'>
	</unless>
	
	ネストしたHashもしくはメソッドへのアクセス: &=.hoge.piyo;
	
	include文:
	<include >
	
	</body>
	</html>

### フォームへの自動埋め込み


## セキュリティ対応

### 自動XSS対策機能

テンプレートエンジンは、与えられた文字列を自動でエスケープします。もしエスケープして欲しくないときは、文字列をNonEscapeStringという型にキャストしてからテンプレートエンジンに渡します。

コントローラ内では、このキャストはraw(string)というメソッドで行えます。

### 自動CSRF対策機能

egaliteには自動でCSRF対策のチェック値を埋め込む機能が付いています。この機能を有効にすると自動でCSRF対策を行うことができます。

テンプレートエンジンが勝手にformタグを見つけて、勝手にcsrf情報を埋め込むhiddenタグが付与されます。

【注意】外部のサイトにフォームを送信するときにセッション情報が送られてしまいますので、外部のサイトにフォームを送るときは、&lt;form>タグを&lt;form :nocsrf action='hoge' method='POST'>のように記述してください。

有効にする方法は以下の通りです。

	egalite = Egalite::Handler.new(
	  :db => db,
	  :template_engine => Egalite::CSRFTemplate
	)
	
	class Pages < Egalite::CSRFController
	end

## エラー処理

例外が発生した場合、:error_templateに設定されたHTMLテンプレートを表示します。

このテンプレートには:exception_log_tableが指定されている場合は、記録されたエラーログ番号がlogidとして埋め込まれます。これによりシステムエラー時のユーザからの問い合わせに迅速に対応することができるようになります。

Egalite::UserErrorまたはEgalite::SystemErrorという例外が送出された場合には、その中のmessageがテンプレートにmessageとして埋め込まれます。これにより簡易的にユーザーにエラーメッセージを表示することができます。

UserError例外はエラーログに記録されません。

UserError例外発生時には、テンプレートにusererror => trueが引き渡されます。

## モジュール

### キャッシュモジュール

バージョン1.1.0よりキャッシュモジュールが追加されました。以下のようにして、コントローラーの出力結果をキャッシュすることができます。

	class HogeController < Egalite::Controller
	  include Egalite::ControllerCache
	  
	  # キャッシュするアクションを指定
	  #   expireは秒単位
	  cache_action :cache, :expire => 1 
	end

現時点ではキャッシュデータの格納先はRDBMSに限られます。将来的にはmemcachedなどにも対応する予定です。

RDBMSでのテーブル定義は以下の通り。

	CREATE TABLE controller_cache (
	  id SERIAL PRIMARY KEY,
	  inner_path TEXT NOT NULL,
	  language TEXT,
	  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	  content TEXT NOT NULL
	);

### 多言語化モジュール

多言語化モジュールを利用することにより、ウェブサイトを多言語化することができます。

多言語化を利用するさいは、アプリケーションの起動時に以下のようにして多言語化の設定を行います。

	Egalite::M17N::Translation.load(File.join(File.dirname(__FILE__),'m17n.txt'))
	Egalite::M17N::Translation.allow_content_negotiation = true
	Egalite::M17N::Translation.user_default_lang = 'en'

コントローラーでは、以下のようにして多言語化フィルタを導入します。フィルタのチェーンを保つために継承して使用すると良いでしょう。

	include Egalite::M17N::Filters

翻訳文章はm17n.txtに記載します。

HTMLテンプレートに記載された文章や画像はm17n.txtに記述するだけで、コントローラーには一切手を加えることなく多言語化が可能です。

## リリースノート

### 1.5

UserErrorとSystemError例外が追加されました。これによりユーザにエラーメッセージを容易に表示できます。

:error_template_fileが追加されました。ファイル名を指定するだけでエラーテンプレートが読み込まれるようになります。

### 1.5.1

Egalite::ErrorLogger.catch_exception(sendmail) {}が追加されました。これを使うと、任意のブロックで発生した例外をキャッチして、管理者へのメール送信やログの出力を行います。重要なエラーが発生する可能性がある場所への利用に適しています。
