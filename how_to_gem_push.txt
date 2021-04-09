
* Egaliteを更新する方法

Egaliteを更新する方法を以下に書きます。

必要な修正を加えたら、まずlib/egalite/version.rbを書き換えてバージョン番号を上げます。Gemを差し替えるのにバージョンを上げる必要があるので。

gem build egalite.gemspec
を実行するとegalite-x.x.xx.gemが作成されます。

https://rubygems.org/api/v1/api_key.yaml
にアクセスしてgem push用のyamlキーを取得します。rubygemsのアカウント作成については新井に聞いてください。

取得したファイルをcredentialsという名前に変更し、~/.gem/credentialsにコピーします。

gem push egalite-x.x.xx.gem
を実行するとgemがpushされ、gem install / updateなどで取得できるようになります。

利用している側では、gem update, bundle updateなどをしてapacheをreloadすると新しいバージョンを利用することができます。

