# ===============================
# AWSプロバイダーの設定
# ===============================
# Terraformが操作対象とするクラウドプロバイダー（今回はAWS）を指定します。
# regionパラメータで、リソースを作成するAWSリージョンを指定します。
# 今回は変数 aws_region（デフォルト値: ap-northeast-1）を参照しています。
provider "aws" {
  region = var.aws_region # 使用するAWSリージョン（例: 東京リージョン）を変数から指定
}

# ===============================
# VPC（仮想プライベートクラウド）の作成
# ===============================
resource "aws_vpc" "main" {
  # 今回は小規模構成だが、学習用途で余裕を持ったCIDRに
  cidr_block = var.vpc_cidr

  # VPC内でDNSによる名前解決を可能にする設定
  enable_dns_support = true

  # 後でSSHやALBで名前解決する場面に役立つため、有効化
  enable_dns_hostnames = true

  # リソースに名前タグを付けて識別しやすく
  tags = {
    Name = "${var.project_name}-vpc" # プロジェクト名を含めたVPC名をタグ付け
  }
}

# ===============================
# パブリックサブネットの作成（AZ a）
# ===============================
# VPC内に配置するサブネット（10.0.1.0/24）を作成。
# Availability Zone（AZ）に a を指定して、マルチAZ構成を想定。
# map_public_ip_on_launch を true にすることで、
# 起動するEC2インスタンスに自動でパブリックIPが付与され、
# インターネット経由でアクセス可能。
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id         # 所属するVPCのIDを指定
  cidr_block              = "10.0.1.0/24"           # サブネットのCIDR。1つ目のAZ用に別のIP帯を分割
  availability_zone       = "${var.aws_region}a"    # 東京リージョンのaゾーンに配置
  map_public_ip_on_launch = true                    # EC2に自動でパブリックIPを割り当てる

  tags = {
    Name = "${var.project_name}-subnet-1"           # 管理しやすいように名前タグを付与
  }
}

# ===============================
# パブリックサブネットの作成（AZ c）
# ===============================
# 上記と同様の設定で、もう1つのAZ（c）にもサブネットを作成。
# 学習環境ながらもマルチAZ構成を意識することで、
# 高可用性構成の基礎を押さえる。
# CIDRを "10.0.2.0/24" にすることで、サブネットごとに明確にIP帯を分けています。
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id         # 同じVPCに所属
  cidr_block              = "10.0.2.0/24"           # 別AZ用のCIDR（分割設計）
  availability_zone       = "${var.aws_region}c"    # 東京リージョンのcゾーンに配置
  map_public_ip_on_launch = true                    # EC2へのアクセス性を考慮し、パブリックIPを付与

  tags = {
    Name = "${var.project_name}-subnet-2"
  }
}


# ===============================
# インターネットゲートウェイの作成
# ===============================
# Internet Gateway（IGW）は、VPCをインターネットに接続するための出入り口。
# 本構成では、EC2インスタンスがインターネットに出られるようにするため、
# IGWを作成し、VPCにアタッチ。
# これにより、パブリックサブネット内のEC2がHTTP/HTTPS通信を行えるようになります。
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id  # 作成したVPC（aws_vpc.main）に紐づけ

  tags = {
    Name = "${var.project_name}-igw"  # 識別しやすいように名前タグを付与
  }
}

# ===============================
# パブリックサブネット用のルートテーブル作成
# ===============================
# VPC内の通信ルートを制御するためのもの。
# "0.0.0.0/0" は全てのIPv4トラフィックを意味し、IGW にルーティングすることで、
# サブネット内のリソースがインターネットと通信できるようになります。
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id  # 作成済みのVPCと関連付け

  route {
    cidr_block = "0.0.0.0/0"                  # すべての外向きトラフィックが対象
    gateway_id = aws_internet_gateway.igw.id  # 送信先は作成済みのインターネットゲートウェイ
  }

  tags = {
    Name = "${var.project_name}-rt"  # リソース管理のための命名規則に沿ったタグ付け
  }
}

# ===============================
# ルートテーブルと各パブリックサブネットの関連付け
# ===============================
# public_1サブネットとルートテーブルを紐づけ。
# これにより、このサブネットに配置されたEC2インスタンスが
# インターネットと通信可能になる。
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# 同様に public_2 サブネットも IGW にルートされるように設定。
# マルチAZを想定した構成にしておくことで、実践的な拡張性も意識した構成になります。
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ===============================
# Security Group（セキュリティグループ）の作成
# ===============================
# EC2インスタンスなどに適用するファイアウォール設定を定義。
# このセキュリティグループでは、SSH・HTTPの受信を許可し、送信は全許可しています。

resource "aws_security_group" "web_sg" {
  name   = "${var.project_name}-web-sg"  # 管理しやすいように命名規則に基づいた名前を付与
  vpc_id = aws_vpc.main.id               # 作成済みのVPCに所属させる

  # ==========================
  # インバウンドルール（受信）
  # ==========================

  # ポート22 (SSH) を全世界に許可
  # 開発・学習環境用。実運用では特定IPに制限すべき。
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # すべてのIPアドレスからのアクセスを許可（注意）
  }

  # ポート80 (HTTP) を全世界に許可
  # Webサービスとして外部公開するため
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 全世界からのHTTPアクセスを受け入れる
  }

  # ==========================
  # アウトバウンドルール（送信）
  # ==========================

  # 全トラフィックを外部に許可（デフォルト動作だが明示）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"           # すべてのプロトコル
    cidr_blocks = ["0.0.0.0/0"]  # 送信先の制限なし
  }

  # ==========================
  # タグの付与
  # ==========================
  tags = {
    Name = "${var.project_name}-web-sg"  # 可視化・管理のためのタグ
  }
}


#------------------------
# EC2 Instance (1台目)
#------------------------
resource "aws_instance" "web" {
  # 利用するAMIのIDを指定。Amazon Linux 2（東京リージョン）を使用。
  # 軽量でTerraformや学習に適しているOS。
  ami           = "ami-0c3fd0f5d33134a76" # Amazon Linux 2

  # 無料利用枠に対応するt2.microを採用。
  # 検証・学習用途に最適な低スペックインスタンス。
  instance_type = "t2.micro"

  # 外部からアクセスできる環境に配置するため。
  subnet_id     = aws_subnet.public_1.id

  # SSH接続などに利用。
  key_name      = var.key_name

  # セキュリティグループを割り当て。HTTPやSSHの通信を許可するためのルールを定義。
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # インスタンスにパブリックIPを自動割り当て。
  # インターネットからアクセスできるようにするため。
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1 -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
  
}

#------------------------
# EC2 Instance (2台目)
#------------------------
resource "aws_instance" "web_2" {
  ami                         = "ami-0c3fd0f5d33134a76"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_2.id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1 -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "${var.project_name}-ec2-2"
  }
}

# -----------------------------------------
# Application Load Balancer（ALB）の作成
# -----------------------------------------
resource "aws_lb" "web_alb" {
  name               = "${var.project_name}-alb"
  internal           = false # パブリックALBとして作成（外部からアクセス可能）
  load_balancer_type = "application" # HTTP/HTTPSなどL7で動作するALB
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups    = [aws_security_group.web_sg.id] # HTTP許可などのセキュリティ設定

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# -----------------------------------------
# ターゲットグループの作成
# EC2インスタンスへのルーティング定義
# -----------------------------------------
resource "aws_lb_target_group" "web_tg" {
  name     = "${var.project_name}-tg"
  port     = 80 # Webサーバー用のポート
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # ヘルスチェックの設定（ALBが対象のEC2を監視）
  health_check {
    path     = "/"
    protocol = "HTTP"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# -----------------------------------------
# ALBのリスナー設定
# 80番ポートで受けたリクエストをターゲットグループに転送
# -----------------------------------------
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# -----------------------------------------
# ALBのリスナー設定
# 80番ポートで受けたリクエストをターゲットグループに転送
# -----------------------------------------
resource "aws_lb_target_group_attachment" "web_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web.id # 1台目のWebサーバー
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_2_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_2.id # 2台目のWebサーバー
  port             = 80
}
