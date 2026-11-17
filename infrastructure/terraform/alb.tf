resource "aws_lb" "main" {
  name               = "${var.application_name}-alb"
  internal           = false
  load_balancer_type = "application"

  subnets = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "main" {
  name        = "${var.application_name}-tg"
  port        = 32423
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    interval            = 30
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = "172.31.0.3"
  port             = 32423
}