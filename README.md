### 概要
- cronみたいなもの
- 実行時間はインターバル指定のみ
- インタラクティブに操作可能

### 設定ファイル(toml)
```toml
[foo]
i = "32minutes 1second"
d = "~/aaa/"
c = "myscript.sh"
o = "--op something"
```

32分1秒ごとに ~/aaa/ というディレクトリに移動して myscript.sh を --op something オプションをつけて実行する。
ディレクトリに移動してから実行するのでコマンド／オプションは全てそのディレクトリからの相対パスということになる。

```toml
[bar]
i = "1day"
d = "~/bbb/"
c = "sample.rb"

[bar.a]
o = "-x 123"

[bar.b]
o = "-x 456"
```

ドット区切りでツリー構造を形成できる。この例は次のように解釈される。
（拡張子なしのファイル名が先頭に付く。）

```
filename
└─ bar
   ├─ a
   └─ b
```

子要素を持つノードはジョブとして解釈されずその要素は下流ノードのデフォルト値となる。
子要素に同要素があれば上書きされる。
末端ノードのみがジョブとして登録される。
先の例は次のように書いたのと同じ。

```toml
[bar.a]
i = "1day"
d = "~/bbb/"
c = "sample.rb"
o = "-x 123"

[bar.b]
i = "1day"
d = "~/bbb/"
c = "sample.rb"
o = "-x 456"
```

m（mutexの略）を指定すると同じ文字列を持つジョブ同士は同時に実行されない。
たまたまタイミングが一致した場合順番に実行される。

```toml
[baz]
i = "1h30m"
d = "/tmp"
m = "aiueo"

[baz.x]
c = "/usr/local/bin/aaa"

[baz.y]
c = "/usr/local/bin/bbb"

[baz.z]
c = "/usr/local/bin/ccc"
```

### コンソール
stim.rb 起動時に指定したポート番号を指定して console.rb を起動する。
ジョブの停止／再開、一度きりの手動実行などが可能。
