variable "aws_lb_resources" {
  description = "AWS LB controller resources variables"
  type = object({
    create                        = optional(bool, true)
    role_name                     = optional(string, "AmazonEKSLoadBalancerControllerRoleFor")
    role_permissions_boundary_arn = optional(string, null)
    namespace_service_accounts    = optional(list(string), ["infra-tools:aws-load-balancer-controller"])
    bucket_suffix                 = optional(string, "elb-access-logs")
    tags                          = optional(map(string), {})
  })
  default = ({
  })
}
