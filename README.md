# AWS Infrastructure with Terraform

## 概要
このリポジトリは、Terraformを用いてAWS上にNginx Webサーバーを構築するポートフォリオです。IaCスキルとAWSの基本構成に関する理解をアピールする目的で作成しました。

- **目的**: IaCスキルとAWSネットワーク構成の理解を示すためのポートフォリオ  
- **対象者**: SRE・インフラエンジニア職志望
---
## 使用技術
- Terraform v1.x
- AWS（EC2,VPC,ALB,SGなど）
- Amazon Linux 2
- Nginx
---
## 構成図
![terraform init](./images/terraform-plan-images.png)

## インフラ構成
| リソース           | 概要                                                       |
|--------------------|------------------------------------------------------------|
| VPC                | CIDR `10.0.0.0/16` のカスタムVPCを作成                      |
| Subnet             | パブリックサブネットを2つ作成（AZ: a, c）でマルチAZ構成を意識   |
| Internet Gateway   | VPCをインターネットに接続するためのIGW                      |
| Route Table        | IGWへのルート（0.0.0.0/0）を設定し、各サブネットに紐付け        |
| Security Group     | HTTP(80), HTTPS(443), SSH(22) のインバウンドを許可            |
| Key Pair           | EC2へSSH接続するための鍵を作成し利用                         |
| EC2                | Amazon Linux 2（Nginxインストール済み）のWebサーバー         |
| ALB                | パブリックALBを構成し、リクエストをEC2へ転送                 |
| Target Group       | EC2インスタンスを登録してALBからのトラフィックを受信         |
| Listener           | HTTPリクエストをTarget Groupにルーティング                   |
| Output             | ALBのDNS名、EC2のパブリックIPなどを出力                      |
| Variables          | リージョンやCIDRなど、変更しやすいように変数として定義         |
---
## デプロイ手順
# 1. terraform init
以下は `terraform init` を実行した際のスクリーンショットです。初期化が正常に完了したことが確認できます。
![terraform init](./images/terraform-init-output.png)


# 2. terraform plan
以下は `terraform plan` を実行した際の出力結果です。キーペア名（`var.key_name`）を入力するプロンプトが表示されました。
ここで、使用したい EC2 キーペア名を入力すると、Terraform はリソース作成の計画を出力します。
その後、表示される計画の一部です（`+ create` は作成予定のリソース）

![terraform init](./images/terraform-init-output02.png)

## Terraform plan実行結果について
本リポジトリに含まれるTerraformの実行計画（plan）の主要な出力結果は、こちらのREADMEにて必要な部分のみ抜粋して記載しています。  
より詳細な出力内容につきましては、同梱の「plan-result.txt」ファイルに保存しておりますので、そちらをご参照ください。:
[plan-result.txt](./plan-result.txt)

# 3. 出力されたALBのDNS名にアクセス
以下は、デプロイが完了後、Nginxが正常に稼働していることを確認できました。
![terraform init](./images/terraform-apply-dns-nginx.png)

