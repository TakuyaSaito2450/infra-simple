# プロジェクト名
AWS Infrastructure with Terraform

## 概要
このリポジトリは、Terraformを用いてAWS環境を自動構築するポートフォリオです。  
主に以下の構成で、シンプルなWebサーバー環境（Nginx）をデプロイしています。

-**目的**: IaCスキルとAWSネットワーク構成の理解を示すためのポートフォリオ
-**対象者**: SRE・インフラエンジニア職志望（障がい者雇用枠含む）

---

## 構成図

![Architecture](./images/architecture.png) <!-- 構成図ファイルへのパス -->

---

## インフラ構成

| リソース | 内容 |
|----------|------|
| VPC | カスタムVPC（CIDR: `10.0.0.0/16`） |
| Subnet | Public Subnet × 2（AZ: `a`, `c`） |
| Internet Gateway | パブリックサブネットに接続 |
| Route Table | 0.0.0.0/0 向けにIGWルート設定 |
| Security Group | HTTP(80), SSH(22) を許可 |
| EC2 | Amazon Linux 2 / Nginx 起動スクリプト付 |
| ALB | Public Subnet ×2 に配置。EC2をターゲット登録 |

---

## 使用技術

- Terraform v1.x
- AWS EC2 / VPC / ALB / SG など
- Amazon Linux 2
- Nginx

---

## デプロイ手順
# 1. terraform init
以下は `terraform init` を実行した際のスクリーンショットです。初期化が正常に完了したことが確認できます。
![terraform init](./images/terraform-init-output.png)


# 2. terraform plan
以下は `terraform plan` を実行した際の出力結果です。キーペア名（`var.key_name`）を入力するプロンプトが表示されました。
ここで、使用したい EC2 キーペア名を入力すると、Terraform はリソース作成の計画を出力します。
その後、表示される計画の一部です（`+ create` は作成予定のリソース）

![terraform init](./images/terraform-init-output-02.png)

※全出力は以下のファイルに記載しています。

[plan-result.txt](./plan-result.txt)


# 3. 出力されたALBのDNS名にアクセス
