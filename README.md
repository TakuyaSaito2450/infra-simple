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
terraform init 実行結果
以下は `terraform init` を実行した際のスクリーンショットです。初期化が正常に完了したことが確認できます。
![terraform init](./images/terraform-init-output.png)

# 2. terraform plan
terraform plan

# 3. terraform apply
terraform apply

# 4. 出力されたALBのDNS名にアクセス


# 2. terraform plan
terraform plan

# 3. terraform apply
terraform apply

# 4. 出力されたALBのDNS名にアクセス
