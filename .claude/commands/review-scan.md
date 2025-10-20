---
description: "docs/REVIEW.md に従ってレビューを行います"
---

# タスク

- レビュー観点は @docs/REVIEW.md にあります。これを参考にして、絶対に抜け漏れがないように ultrathink して考えてください。
- 常に日本語で返信してください。

# レビュー内容

``bash
# mainブランチとの差分を取得
git diff main...HEAD

# コミットログも確認
git log --oneline main..HEAD
``

上記のgit diffの結果を基に、 @docs/REVIEW.md のガイドラインに従ってレビューを実施してください。
