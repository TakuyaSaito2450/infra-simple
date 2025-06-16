# ===============================
# AWSプロバイダーの設定
# ===============================
# Terraformが操作対象とするクラウドプロバイダー（今回はAWS）を指定します。
# regionパラメータで、リソースを作成するAWSリージョンを指定します。
# 今回は変数 aws_region（デフォルト値: ap-northeast-1）を参照しています。
provider "aws" {
  region = var.aws_region # 使用するAWSリージョン（例: 東京リージョン）を変数から指定
}

# AWS上にVPCを作成
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr # vpc_cidr 数の値を参照
  enable_dns_support   = true # VPC内でDNS解決を有効にする
  enable_dns_hostnames = true # EC2にDNS名を自動付与できるようにする

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

#Subnet
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id # main VPC（aws_vpc.main）のIDを参照し、このサブネットを所属させる
  cidr_block        = "10.0.1.0/24" # 別のIP範囲でサブネットを定義
  availability_zone = "${var.aws_region}a" # 東京リージョンのaゾーンに配置。将来的にマルチAZ構成を意識してa/cを分ける。
  map_public_ip_on_launch = true # パブリックIP自動割当（インターネットアクセス可能）

  tags = {
    Name = "${var.project_name}-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id # 同じmain VPCに所属
  cidr_block        = "10.0.2.0/24" # 別のIP範囲でサブネットを定義。# 学習用のため、各サブネットは /24 でシンプルに管理。
  availability_zone = "${var.aws_region}c"  # 東京リージョンのcゾーンに配置（マルチAZ構成）
  map_public_ip_on_launch = true # 学習環境用に、EC2に自動でパブリックIPを割り当ててSSHアクセスしやすくする。
  tags = {
    Name = "${var.project_name}-subnet-2"
  }
}

#------------------------
# Internet Gateway
#
# VPCにインターネット接続の出入り口を追加
# EC2インスタンスなどがHTTP/HTTPSアクセスを受けられるようにするため。
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id # 同じmain VPCに所属

  tags = {
    Name = "${var.project_name}-igw"
  }
}

#------------------------
# Route table
#------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # すべての通信（0.0.0.0/0）をInternet Gateway経由でルーティング
  # → EC2がインターネットアクセスできるようにするため
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-rt"
  }
}

# サブネット public_1 に対して、パブリックルートテーブルを関連付け
# → public_1 にあるEC2などがインターネットにアクセスできるようにするため
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# サブネット public_2 に対して、パブリックルートテーブルを関連付け
# → public_2 にあるEC2などがインターネットにアクセスできるようにするため
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

#------------------------
# Security group
#------------------------
# Webサーバー用のセキュリティグループを作成
# name: セキュリティグループの名前を `${var.project_name}` 変数を使って動的に設定
# vpc_id: このセキュリティグループを作成済みの VPC に紐付け）
resource "aws_security_group" "web_sg" {
  name   = "${var.project_name}-web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22               # SSHで使われるポート番号（22番）から
    to_port     = 22               # 同じく22番ポートへの通信を許可する
    protocol    = "tcp"            # 通信プロトコルはTCP
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    from_port   = 80 # 通信の開始ポート（HTTP用）
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # アウトバウンド通信（送信）はすべて許可
  # → どのポート・プロトコルでも、どこへでも出ていける設定
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
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
