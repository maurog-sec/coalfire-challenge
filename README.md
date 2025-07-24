# Coalfire Challenge - AWS & Terraform

## Solution Overview

This exercise proposed by Coalfire deploys a secure, modular AWS environment using Terraform. It includes:

- A single VPC (10.1.0.0/16) with 4 subnets across two Availability Zones  
  - **Public**: 10.1.0.0/24, 10.1.1.0/24  
  - **Private**: 10.1.2.0/24, 10.1.3.0/24  
- One standalone EC2 (Red Hat, t2.micro, 20 GB) in a public subnet.  
- An Auto Scaling Group (2–6 Red Hat t2.micro instances, 20 GB) in the private subnets, auto‑installing Apache.  
- An Internet‑facing Application Load Balancer (HTTP → HTTPS)  
- IAM Roles:  
  - EC2s can write logs to the **logs** bucket  
  - ASG hosts can read from the **images** bucket  
- Two S3 buckets with lifecycle rules:  
  - **images/**: `memes/` → transition to Glacier after 90 days; `archive/` for long‑term storage  
  - **logs/**: `active/` → transition to Glacier after 90 days; `inactive/` → expire after 90 days  

This project deploys a scalable infrastructure for a web application on AWS using Terraform. The main components include:

- **VPC**: A Virtual Private Cloud with CIDR block 10.1.0.0/16, with two public and two private subnets in two availability zones for high availability. A NAT Gateway is included for internet access from private subnets.
- **EC2 Instances**:
- A standalone EC2 instance in a public subnet, possibly for testing or specific services.
- An Auto Scaling Group (ASG) in private subnets to manage EC2 instances, ensuring scalability and availability.
- **Application Load Balancer (ALB)**: A load balancer in public subnets that distributes traffic to the ASG instances. It listens on port 80 (HTTP) and forwards traffic to the instances on port 443 (HTTPS).
- **S3 Buckets**:
- An image bucket with a lifecycle rule that transitions objects with the "memes/" prefix to GLACIER after 90 days.
- A log bucket with lifecycle rules that transition the "active/" prefix to GLACIER after 90 days and expire the "inactive/" prefix after 90 days.
- **Security Groups**:
- Public group: Allows SSH (port 22) and HTTP (port 80) from any IP address.
- ALB group: Allows HTTP from any IP address.
- Private group: Allows HTTPS only from the ALB security group.

This architecture ensures that the web application is accessible through the ALB, with protected instances in private subnets, accessible only through the load balancer.

## Deployment Instructions

To deploy this infrastructure, follow these steps:

1. **Prerequisites**:
- Install Terraform (version compatible with the modules, e.g., Terraform v1.0.0 or higher).
- Set up an AWS account with permissions to create VPC, EC2, ALB, S3, and other resources.
- Set up AWS credentials on your machine or use an IAM role with appropriate permissions.

2. **Clone the Repository**:
- Clone this GitHub repository to your local machine.
```hcl
git clone github.com/maurog-sec/coalfire-challenge.git
```
3. **Configure Variables**:
- Create a `terraform.tfvars` file and define the necessary variables, such as:
```hcl
aws_region = "us-west-2"
redhat_ami = "ami-xxxxxxxxxxxxxxxxxx"
images_bucket_name = "single-images-bucket-name"
logs_bucket_name = "single-logs-bucket-name"
```

4. **Initialize Terraform**:
- Run `terraform init` in the project root directory to download the required providers and modules.

5. **Plan the Deployment**:
- Run `terraform plan` to review the changes that will be applied.

6. **Apply the Configuration**:
- Run `terraform apply` to deploy the infrastructure.

7. **Verify the Deployment**:
- Verify the created resources in the AWS console or using the AWS CLI.

- Access the ALB's DNS name to confirm that the application is running.

## Design Decisions and Assumptions

### Design Decisions
- **VPC**:
  - A 10.1.0.0/16 CIDR block was used for the VPC.
  - Two public and two private subnets were created in two availability zones for high availability.
- A NAT Gateway was enabled to allow internet access from private subnets.
- **EC2 Instances**:
  - A Red Hat AMI (specified by `var.redhat_ami`) was used.
  - A separate instance in a public subnet for possible services such as a bastion host.
  - The ASG instances are in private subnets for the main application, ensuring they are not directly accessible from the internet.
- **Load Balancer**:
  - An ALB was chosen for its ability to handle application-level traffic and support for route-based routing.
  - The listener is configured for HTTP on port 80, forwarding to HTTPS on port 443 on the instances. This means that the instances expect HTTPS traffic, but the ALB accepts HTTP, which is a security consideration.
- **S3 Buckets**:
  - Lifecycle policies have been implemented to move rarely accessed data to GLACIER and expire old logs, optimizing costs.
- **Security**:
  - The public security group allows SSH and HTTP from any IP, which is a potential risk. It is recommended to restrict it to specific IP ranges.
  - The ALB security group allows HTTP from any IP, standard for public load balancers.
  - The private security group allows HTTPS only from the ALB, ensuring that the instances are not directly accessible.

### Assumptions
- The AMI specified by `var.redhat_ami` is correct and available in the selected region.
- The `user_data` script correctly configures the EC2 instances for the application.
- The application on the EC2 instances is configured to listen on port 443 (HTTPS).
- The S3 bucket names are unique and comply with AWS naming conventions.
- The Terraform version used is compatible with all modules.

## References to Resources Used
  - VPC: [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/5.0.0)
  - Autoscaling: [terraform-aws-modules/autoscaling/aws](https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws/9.0.0)
  - ALB: [terraform-aws-modules/alb/aws](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/8.0.0)
  - S3 Bucket: [terraform-aws-modules/s3-bucket/aws](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws/3.0.0)

- **Documentación de AWS**:
 
- **AWS Terraform Modules**:
