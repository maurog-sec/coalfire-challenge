# Coalfire Challenge - AWS & Terraform

## Solution Overview

This exercise proposed by Coalfire deploys a secure, scalable, and modular AWS infrastructure using Terraform. Below the components involved:
- **VPC**: A Virtual Private Cloud with CIDR block 10.1.0.0/16, with two public and two private subnets in two availability zones for high availability. A NAT Gateway is included for internet access from private subnets.
- **EC2 Instances**:
- A standalone EC2 instance in a public subnet, possibly for testing or specific services.
- An Auto Scaling Group (ASG) in private subnets to manage EC2 instances, ensuring scalability and availability.
- **Application Load Balancer (ALB)**: A load balancer in public subnets that distributes traffic to the ASG instances. It listens on port 80 (HTTP) and forwards traffic to the instances on port 443 (HTTPS).
- **S3 Buckets**:
- An image bucket with a lifecycle rule that transitions objects with the "memes/" prefix to GLACIER after 90 days.
- A log bucket with lifecycle rules that transition the "active/" prefix to GLACIER after 90 days and expire the "inactive/" prefix after 90 days.
- **Security Groups**:
- Public group: Allows SSH (port 22) from user-defined IPs, and HTTP (port 80) from any IP address.
- ALB group: Allows HTTP from any IP address, but it forwards to HTTPS.
- Private group: Allows HTTPS only from the ALB security group.

This architecture ensures that the web application is accessible through the ALB, with protected instances in private subnets, accessible only through the load balancer.

## Deployment Instructions

To deploy this infrastructure, follow these steps:

1. **Prerequisites**:
- Install Terraform (version compatible with the modules).
- Set up an AWS account with permissions to create VPC, EC2, ALB, S3, and other resources.
- Set up AWS credentials on your machine or use an IAM role with appropriate permissions.

2. **Clone the Repository**:
- Clone this GitHub repository to your local machine.
```hcl
git clone github.com/maurog-sec/coalfire-challenge.git
```
3. **Configure Variables**:
- If you want to define specific values for the variables by default, you would have to create the `terraform.tfvars` file and define the necessary variables, such as:
```hcl
allowed_ips = "1.2.3.4"
redhat_ami = "ami-xxxxxxxxxxx"
images_bucket_name = "coalfire-images"
logs_bucket_name = "coalfire-logs"
```

4. **Initialize Terraform**:
- Run `terraform init` in the project root directory to download the required providers and modules.

5. **Plan the Deployment**:
- Run `terraform plan` to review the changes that will be applied.

6. **Apply the Configuration**:
- Run `terraform apply` to deploy the infrastructure.

7. **Verify the Deployment**:
- Verify the created resources in the AWS console or using the AWS CLI.

- Access the ALB's DNS name (to be defined) to confirm that the application is running.

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
  - The public security group allows HTTP from any IP, which is a potential risk. It is recommended to restrict it to specific IP ranges.
  - The ALB security group allows HTTP from any IP, standard for public load balancers.
  - The private security group allows HTTPS only from the ALB, ensuring that the instances are not directly accessible.

### Assumptions
- The AWS account provided doesn't exist, so the user will have to provide a valid account-id.
- The user knows the AMI ID for `var.redhat_ami`.
- The `user_data` script configures Apache on the EC2 instances.
- The application on the EC2 instances is public-facing, and it's configured to listen on port 443 (HTTPS).
- The S3 bucket names will be unique and comply with AWS naming conventions.
- The Terraform version used is compatible with all modules.
- There is a few errors in the `terraform plan` due to I don't have an AWS account.

## References to Resources Used
  - VPC: [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
  - Autoscaling: [terraform-aws-modules/autoscaling/aws](https://registry.terraform.io/modules/terraform-aws-modules/autoscaling/aws/latest)
  - ALB: [terraform-aws-modules/alb/aws](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/latest)
  - S3 Bucket: [terraform-aws-modules/s3-bucket/aws](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws/latest)

## Prioritized Enhancement Plan

| Priority | Enhancement | Description |
|-----------|--------|-------------|
| High | Security | Apply KMS encryption for all resources. |
| Medium | Monitoring and Logging | Configure CloudWatch alarms for the ASG and ALB. Enable logging for the ALB and EC2 instances to track requests and errors. |
| Medium | Scalability | Define scaling policies for the ASG based on metrics such as CPU usage or network traffic. |
| Low | Cost Optimization | Review instance types and sizes to optimize performance and cost. Consider Spot instances for outage-tolerant workloads. |
| Low | Backups and Recovery | Implement regular backups for S3 buckets and EC2 volumes. Configure cross-region replication for S3 buckets if necessary. |
| Low | Automation | Automate deployment with CI/CD tools such as Jenkins or GitHub Actions. Use Terraform workspaces for environments (dev, staging, prod). |

## Operational Gap Analysis

- **Security**:
- No mention of encryption for data at rest or in transit beyond the HTTPS listener on the instances.
- **Monitoring**:
- There is no monitoring or alerting configuration in the provided code, which could lead to undetected issues.
- **Backups**:
- Although S3 buckets have lifecycle policies, there is no mention of backups for EC2 instances or other resources.
- **Scalability**:
- The ASG is configured, but no scaling policies were defined, which could require manual interventions.
- **Documentation**:
- The README should include more detailed instructions, such as how to access the application or manage S3 buckets.

## Evidence of Successful Deployment
! [Running TF Init](evidences/tf-init.JPG)
! [Running TF Plan](evidences/tf-plan.JPG)


## Solution Diagram
TODO
