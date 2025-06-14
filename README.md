# AWS Infrastructure with Terraform

## 概要
このリポジトリは、Terraformを用いてAWS上にNginx Webサーバーを構築するポートフォリオです。IaCスキルとAWSの基本構成に関する理解をアピールする目的で作成しました。

- **目的**: IaCスキルとAWSネットワーク構成の理解を示すためのポートフォリオ  
- **対象者**: SRE・インフラエンジニア職志望（障がい者雇用枠含む）

---

## インフラ構成

| リソース         | 内容                                       |
|------------------|--------------------------------------------|
| VPC              | カスタムVPC（CIDR: `10.0.0.0/16`）          |
| Subnet           | パブリックサブネット ×2（AZ: `a`, `c`）     |
| Internet Gateway | パブリックサブネットに接続                |
| Route Table      | 0.0.0.0/0 向けのIGWルート設定              |
| Security Group   | HTTP(80), SSH(22) を許可                   |
| EC2              | Amazon Linux 2（Nginxインストール済み）    |
| ALB              | パブリックサブネットに配置し、EC2を登録   |

---

## 使用技術

- Terraform v1.x
- AWS（EC2 / VPC / ALB / SG など）
- Amazon Linux 2
- Nginx

---

## 図（構成図）
※ ここに構成図があるとさらにわかりやすくなります（draw.ioやExcalidrawで作成可）


## デプロイ手順
# 1. terraform init
以下は `terraform init` を実行した際のスクリーンショットです。初期化が正常に完了したことが確認できます。
![terraform init](./images/terraform-init-output.png)


# 2. terraform plan
以下は `terraform plan` を実行した際の出力結果です。キーペア名（`var.key_name`）を入力するプロンプトが表示されました。
ここで、使用したい EC2 キーペア名を入力すると、Terraform はリソース作成の計画を出力します。
その後、表示される計画の一部です（`+ create` は作成予定のリソース）

![terraform init](./images/terraform-init-output-02.png)


## EC2インスタンス（aws_instance.web）
以下の EC2 インスタンスが作成されます。

| 項目 | 内容 |
|------|------|
| AMI | ami-0c3fd0f5d33134a76（Amazon Linux 系） |
| インスタンスタイプ | t2.micro（無料利用枠相当） |
| キーペア名 | your-key-name（変数として外部から指定） |
| パブリック IP | 自動割り当て（`associate_public_ip_address = true`） |
| セキュリティグループ | 別リソースにて定義し、アタッチ済み |
| タグ | `Name = sre-demo-ec2` |
| ユーザーデータ | 初期構成スクリプトを使用（Base64 形式でエンコード） |

##  EC2インスタンス（aws_instance.web_2）
以下の2台目の EC2 インスタンス（Webサーバ）が構築されます。

| 項目 | 内容 |
|------|------|
| AMI | ami-0c3fd0f5d33134a76（Amazon Linux系） |
| インスタンスタイプ | t2.micro（無料枠対象） |
| キーペア名 | your-key-name（外部から `.tfvars` または `-var` で指定） |
| パブリックIP | 自動割当（`associate_public_ip_address = true`） |
| タグ | Name = sre-demo-ec2-2 |
| ユーザーデータ | 起動時に自動実行される初期化スクリプト（Base64形式） |
| セキュリティグループ | VPCの設定により適用（詳細は `vpc_security_group_ids` で指定） |
| サブネット | 指定のVPCサブネットにアタッチされる（`subnet_id`） |

## インターネットゲートウェイ（aws_internet_gateway.igw）
以下のインターネットゲートウェイ（IGW）が作成されます。

| 項目 | 内容 |
|------|------|
| リソース名 | aws_internet_gateway.igw |
| 用途 | パブリックサブネット内のEC2インスタンスがインターネットと通信できるようにするためのゲートウェイ |
| 紐づくVPC | VPC IDは apply 後に自動設定されます |
| タグ | Name = sre-demo-igw |

※より詳細な出力内容はこちらのファイルに保存しています：
[plan-result.txt](./plan-result.txt)

# 3. 出力されたALBのDNS名にアクセス
