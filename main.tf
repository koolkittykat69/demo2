data "aws_ami" "ubuntu" {
  owners      = ["099720109477"] # Canonical
  most_recent = true

  filter {
    name    = "name"
    values  = ["ubuntu/images/hvm-ssd/ubuntu-*"]
  }

  filter {
    name    = "architecture"
    values  = ["x86_64"]
  }
}

resource "aws_key_pair" "alpine" {
  key_name = "alpine"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "nginx" {
  for_each                    = toset(var.avail_zones)
  depends_on                  = [aws_nat_gateway.nat]
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.priv[each.key].id
  vpc_security_group_ids      = [aws_security_group.demo.id]
  key_name                    = aws_key_pair.alpine.key_name
  user_data                   = templatefile("ubuntu-config.tpl", {
                                  ssh_key=file("~/.ssh/id_rsa.pub"),
                                  index=templatefile("index.tpl", { avail_zone=each.key })
                                })

  tags = {
    Name = each.key
  }

  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
}

resource "aws_lb" "main" {
  depends_on          = [aws_instance.nginx]
  name                = "demo2"
  load_balancer_type  = "application"
  subnets             = [for subnet in aws_subnet.pub : subnet.id]
  enable_http2        = false
  ip_address_type     = "ipv4"
  security_groups     = [aws_security_group.demo.id]
}

resource "aws_lb_target_group" "main" {
  name        = "demo2"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "main" {
  for_each          = toset(var.avail_zones)
  target_group_arn  = aws_lb_target_group.main.arn
  target_id         = aws_instance.nginx[each.key].id
  port              = 80
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type              = "forward"
    target_group_arn  = aws_lb_target_group.main.arn
  }
}
