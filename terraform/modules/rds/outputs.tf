output "rds_endpoint" {
  value = split(":", aws_db_instance.postgres.endpoint)[0]
}

output "rds_sg_id" {
  value = aws_security_group.rds_sg.id
}