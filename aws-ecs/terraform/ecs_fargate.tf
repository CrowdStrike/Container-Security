terraform {
    required_version = ">= 0.15"
    required_providers {
    aws = {
        source  = "hashicorp/aws"
        version = ">= 4.45"
    }
    }
}

provider "aws" {
    profile = ""
    region  = ""
}

variable "region" {
  type        = string
  description = "AWS Region to deploy Task Definition"
  default     = ""
}

variable "ExecutionRole" {
  type        = string
  description = "AWS IAM Execution Role for ECS"
  default     = "arn:aws:iam::123456789123:role/ecsTaskExecutionRole"
}

variable "AppName" {
  type        = string
  description = "Logical name for application / container"
  default     = "sample-app"
}
variable "AppImagePath" {
  type        = string
  description = "The full container image path including tag value for the application container image"
  default     = "httpd:2.4"
}
variable "AppEntrypoint" {
  type        = string
  description = "The entrypoint override to use within the application container image."
  default = "sh -c"
}
variable "AppCmd" {
  type        = string
  description = "The command override to use within the application container image. (Optional)"
  default     = "/bin/sh -c \\\"echo '<html> <head> <title>Amazon ECS Sample App</title> <style>body {margin-top: 40px; background-color: #333;} </style> </head><body> <div style=color:white;text-align:center> <h1>Amazon ECS Sample App</h1> <h2>Congratulations!</h2> <p>Your application is now running on a container in Amazon ECS.</p> </div></body></html>' >  /usr/local/apache2/htdocs/index.html && httpd-foreground\\\""
}
variable "AppContainerPort" {
  type        = string
  description = "Container port to expose"
  default = "80"
}
variable "TaskCPU" {
  type        = string
  description = "Amount of CPU to allocate to the task definition"
  default = "256"
}
# AllowedValues:
# 256
# 512
# 1024
# 2048
# 4096
variable "TaskMemory" {
  type        = string
  description = "Amount of Memory to allocate to task definition"
  default = "512"
}
# AllowedValues:
# 512
# 1024
# 2048
# 3072
# 4096
# 5120
# 6144
# 7168
# 8192
# 9216
# 10240
# 11264
# 12288
# 13312
# 14336
# 15360
# 16384
# 17408
# 18432
# 19456
# 20480
# 21504
# 22528
# 23552
# 24576
# 25600
# 26624
# 27648
# 28672
# 29696
# 30720
variable "FalconImagePath" {
  type        = string
  description = "The full ECR container image path including tag value for the Falcon Container sensor image"
  default     = "123456789123.dkr.ecr.<region>.amazonaws.com/falcon-sensor/falcon-container:latest"
}
variable "FalconCID" {
  type        = string
  description = "CrowdStrike Customer ID (CID) value"
  default     = ""
}
variable "LogGroup" {
  type        = string
  description = "Log group name"
  default     = "/path/to-log-group"
}

resource "aws_ecs_task_definition" "sample_app" {
  family = "sample_app"
  container_definitions = <<TASK_DEFINITION
[
   {
      "command": [
        "${var.AppCmd}"
      ],
      "dependsOn": [
         {
            "condition": "COMPLETE",
            "containerName": "crowdstrike-falcon-init-container"
         }
      ],
      "entryPoint": [
         "/tmp/CrowdStrike/rootfs/lib64/ld-linux-x86-64.so.2",
         "--library-path",
         "/tmp/CrowdStrike/rootfs/lib64",
         "/tmp/CrowdStrike/rootfs/bin/bash",
         "/tmp/CrowdStrike/rootfs/entrypoint-ecs.sh",
         "${var.AppEntrypoint}"
      ],
      "environment": [
         {
            "name": "FALCONCTL_OPTS",
            "value": "--cid=${var.FalconCID}"
         }
      ],
      "essential": true,
      "image": "${var.AppImagePath}",
      "linuxParameters": {
         "capabilities": {
            "add": [
               "SYS_PTRACE"
            ]
         }
      },
      "logConfiguration": {
         "logDriver": "awslogs",
         "options": {
            "awslogs-group": "${var.LogGroup}",
            "awslogs-region": "${var.region}",
            "awslogs-stream-prefix": "${var.AppName}"
         }
      },
      "mountPoints": [
         {
            "containerPath": "/tmp/CrowdStrike",
            "readOnly": true,
            "sourceVolume": "crowdstrike-falcon-volume"
         },
         {
            "containerPath": "/tmp/CrowdStrike-private",
            "readOnly": false,
            "sourceVolume": "crowdstrike-private-${var.AppName}"
         }
      ],
      "name": "${var.AppName}",
      "portMappings": [
         {
            "containerPort": ${var.AppContainerPort},
            "protocol": "tcp"
         }
      ]
   },
   {
      "entryPoint": [
         "/bin/bash",
         "-c",
         "chmod u+rwx /tmp/CrowdStrike && mkdir /tmp/CrowdStrike/rootfs && cp -r /bin /etc /lib64 /usr /entrypoint-ecs.sh /tmp/CrowdStrike/rootfs && chmod -R a=rX /tmp/CrowdStrike && chmod -R a=rwX /tmp/CrowdStrike-private-${var.AppName}"
      ],
      "essential": false,
      "image": "${var.FalconImagePath}",
      "mountPoints": [
         {
            "containerPath": "/tmp/CrowdStrike",
            "readOnly": false,
            "sourceVolume": "crowdstrike-falcon-volume"
         },
         {
            "containerPath": "/tmp/CrowdStrike-private-${var.AppName}",
            "readOnly": false,
            "sourceVolume": "crowdstrike-private-${var.AppName}"
         }
      ],
      "user": "0:0",
      "name": "crowdstrike-falcon-init-container"
    }
]
TASK_DEFINITION
  cpu = var.TaskCPU
  execution_role_arn = var.ExecutionRole
  memory = var.TaskMemory
  network_mode = "awsvpc"
  requires_compatibilities = [
   "FARGATE"
  ]
  volume {
    name = "crowdstrike-falcon-volume"
  }
  volume {
    name = "crowdstrike-private-${var.AppName}"
  }
  runtime_platform {
    operating_system_family = "LINUX"
  }
}
