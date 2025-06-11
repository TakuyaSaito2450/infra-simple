output "alb_dns_name" {
  description = "ALBのDNS名（ブラウザでアクセスできるURL）"
  value       = aws_lb.web_alb.dns_name
}
