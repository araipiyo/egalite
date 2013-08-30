
# 管理画面作成ツール

Egaliteでは、HTMLを書かずとも、簡単な管理画面のためのテーブルやフォームを作成するためのライブラリを備えています。

この機能を使えば、いちいちページごとにHTMLを書かずとも、20行程度のコードで簡単な管理画面を作成することができますので、生産性・メンテナンス性が大きく改善されます。

ただし、あまり複雑なページにこれを使うと、コードがぐちゃぐちゃになりますので、どっかのタイミングで諦めてHTMLに移行するほうが無難です。

## テーブル作成ツール

	recs = User.map { |rec| [rec.id, rec.name, rec.email] }
	table_by_array(["番号","氏名","メールアドレス"],recs)

とするだけで、ユーザ一覧のテーブルが生成できます。これをひな形となるテンプレートの一部分に投入すれば、それだけで一覧画面が完成します。

## フォーム作成ツール

	rec = User[id]
	fm = form(rec) # FormHelperインスタンスを取得します
	fm.text(:name) # => "<input type='text' name='name' value='#{rec.user}'/>"
	fm.password(:password) # => "<input type='password' name='password'/>"
	fm.hidden(:foo) # => "<input type='hidden' name='foo' value='#{rec.foo}'/>"
	fm.checkbox(:cb) # => "<input type='checkbox' name='cb' value='true' #{rec.cb ? 'checked' : ''}/>"
	fm.radio(:rd, "foo") # => "<input type='checkbox' name='rd' value='foo' #{rec.rd == 'foo' ? 'selected' : ''}/>"
	fm.textarea(:ta) # => <textarea name='ta'>#{rec.ta}</textarea>
	fm.file(:file) # => <input type='file' name='file'/>
	fm.submit("登録") # => <input type='submit' value='登録'/>

これで作成したフォームを以下のように組むことで、フォームのテーブルが作れます。

	left = ["名前","メールアドレス"]
	right = [fm.text(:name), fm.text(:email)]
	table_by_array(nil, left.zip(right))

## タグ作成ツール

### 単独タグ作成

	tags.br # => <br/>

brとhrが使えます。

### 囲みタグ作成

	tags.p("ほげ") # => "<p>ほげ</p>"

h1 h2 h3 h4 b i p html bodyなどがこのように作れます。

### リンク

	tags.a("http://example.com","ほげ") # => <a href="http://example.com">ほげ</a>

### liタグ

	tags.li(["foo","bar"]) # => <li>foo</li><li>bar</li>

### リストタグ作成

	tags.ul(["foo","bar"]) # => <ul><li>foo</li><li>bar</li></ul>

ulとolが使えます。
