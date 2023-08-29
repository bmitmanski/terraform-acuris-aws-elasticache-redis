data "aws_vpc" "vpc" {
  count = var.is_test ? 0 : 1
  id = "${var.vpc_id}"
}

locals {
  vpc_tags    = var.is_test ? "" : data.aws_vpc.vpc[0].tags["Name"]
  vpc_id      = var.vpc_id
}

resource "aws_cloudwatch_log_group" "slow_log_group" {
  name              = "${var.name}-slow-log"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "engine_log_group" {
  name              = "${var.name}-engine-log"
  retention_in_days = 7
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = replace(format("%.20s", "${var.name}-${var.env}"), "/\\W+$/", "")
  description                   = "Terraform-managed ElastiCache replication group for ${var.name}-${local.vpc_tags}"
  num_cache_clusters            = var.redis_clusters
  node_type                     = var.redis_node_type
  automatic_failover_enabled    = var.redis_failover
  engine_version                = var.redis_version
  port                          = var.redis_port
  parameter_group_name          = aws_elasticache_parameter_group.redis_parameter_group.id
  subnet_group_name             = aws_elasticache_subnet_group.redis_subnet_group.id
  security_group_ids            = [aws_security_group.redis_security_group.id]
  apply_immediately             = var.apply_immediately
  tags                          = var.tags
  multi_az_enabled              = var.multi_az_enabled

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.slow_log_group.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.engine_log_group.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }
}

resource "aws_elasticache_parameter_group" "redis_parameter_group" {
  name = replace(
    format(
      "%.255s",
      lower(
        replace(
          "tf-redis-${var.name}-${local.vpc_tags}",
          "_",
          "-",
        ),
      ),
    ),
    "/\\s/",
    "-",
  )
  description = "Terraform-managed ElastiCache parameter group for ${var.name}-${local.vpc_tags}"
  family      = "redis${replace(var.redis_version, "/\\.[\\d]+$/", "")}" # Strip the patch version from redis_version var
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name = replace(
    format(
      "%.255s",
      lower(
        replace(
          "tf-redis-${var.name}-${local.vpc_tags}",
          "_",
          "-",
        ),
      ),
    ),
    "/\\s/",
    "-",
  )
  subnet_ids = var.subnets
}

