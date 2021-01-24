provider "aws" {
  region = "ap-south-1"
  profile = "gaurav"
}

resource "aws_security_group" "allow_http_ssh_nfs" {
  name        = "allow_http_ssh_nfs"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    description = "Allow Traffic from port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow Traffic for port 2049"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow Traffic from port 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_80_n_22_n_2049"
  }
}

resource "aws_s3_bucket" "mys3-task2" {
  bucket = "gaurav-test-bucket-task2"
  tags = {
    Name = "s3_cloudfront"
    Env = "Dev"
  }
  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_object" "my-s3-object" {
  depends_on = [ aws_s3_bucket.mys3-task2 ]
    source = "C:/Users/gaura/Desktop/TerraForm WS/task_HMC/task2/screenshots/photo.gif"
    key = "photo.gif"
    acl = "public-read"
    content_type = "image/gif"
    bucket = aws_s3_bucket.mys3-task2.id
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [ aws_s3_bucket_object.my-s3-object ]
  origin {
    domain_name = "${aws_s3_bucket.mys3-task2.bucket_domain_name}"
    origin_id   = "${aws_s3_bucket.mys3-task2.id}"
  }

  enabled             = true
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.mys3-task2.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "dev"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_instance" "myinstance" {
  ami = "ami-0a9d27a9f4f5c0efc"
  instance_type = "t2.micro"
  count = 1
  tags = {
    Name = "Task2_instance"
  }
  security_groups = [ aws_security_group.allow_http_ssh_nfs.name,]
  key_name = "NewAWS_CommonKey"
}

resource "aws_efs_file_system" "my_efs" {
    creation_token = "testing"
    encrypted = false
    lifecycle_policy {
        transition_to_ia = "AFTER_30_DAYS"
    }
    tags = {
      "Name" = "EFS-Task2"
    }
}

resource "aws_efs_mount_target" "target" {
    subnet_id = "${aws_instance.myinstance[0].subnet_id}"
    security_groups = [ aws_security_group.allow_http_ssh_nfs.id, ]  
    file_system_id = "${aws_efs_file_system.my_efs.id}"
}

resource "null_resource" "remote-command" {
   // depends_on = [ aws_cloudfront_distribution.s3_distribution, aws_volume_attachment.ebs_attach, ]
    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = file("C:/Users/gaura/Downloads/NewAWS_CommonKey.pem")
        host = aws_instance.myinstance[0].public_ip
    }  
    provisioner "remote-exec" {
        inline = [
            "sudo setenforce 0",
            "sudo yum install nfs-utils git php httpd net-tools -y",
            "sudo rm -rf /var/www/html/*",
            "sudo mount ${aws_efs_mount_target.target.dns_name}:/ /var/www/html/",
            "sudo git clone https://github.com/Gaurav-2001/testing_repo.git /var/www/html/",
            "echo '<img src = https://${aws_cloudfront_distribution.s3_distribution.domain_name}/photo.gif />' | sudo tee -a /var/www/html/index.html",
            "sudo systemctl start httpd",
            "sudo systemctl enable httpd",
        ]    
    }
}
