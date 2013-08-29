
# Egalite メール送信ライブラリ

Egaliteにはシンプルなメール送信ライブラリが付属しています。

	require 'rubygems'
	require 'egalite'
	require 'egalite/sendmail'

多バイト文字によるメール送信に対応しており、簡単にメールを送ることができます。デフォルトではUTF8エンコーディングでメールを送信します。

HTMLメールや添付ファイルには現在は対応しておりません。

SMTPの凝った機能(認証や暗号化等)には対応しておりませんし、今後も対応するつもりはありません。必要であれば、ローカルのメールサーバー(Postfix等)の設定で対応してください。

## メールを送信する

	Sendmail.send(
		body, # メール本文
		{:from => "from@example.com",
		 :reply_to => "replyto@example.com", # 省略可
		 :to => { "James Dean" => "james@example.com", 
		          "新井太郎" => "foo@example.com" },
		 :cc => "",
		 :bcc => "",
		 :subject => "お打ち合わせについて"
		}, # その他、メールヘッダに入れたいものは何でも入れられます
		"localhost" # メールサーバのアドレス (省略可)
	)

メールの宛先や送信人などについては、メールアドレスだけを記載することもできますし、Hash形式で名前とメールアドレスの両方を指定することもできます。

## テンプレートを使ってメールを送信する

	Sendmail.send_with_template(
		"mailtext.txt", # メールテンプレート (HTMLテンプレートとほぼ同様)
		{
		 :from => "from@example.com",
		 :to => "to@example.com",
		 :name => "新井 太郎",
		 :price => "3,000円",
		}, # メールヘッダと、テンプレートに埋め込む内容を入れます
		"localhost"     # メールサーバのアドレス (省略可)
	)

## メール送信をテストする

	Sendmail.mock = true

とすると、メールを送信する代わりに内部に記録しておくようになります。影響はグローバルに及びます。

	(text, envelope_from, to, host) = Sendmail.lastmail

とすることで、送信したメールの取得ができます。これもグローバル変数です。
