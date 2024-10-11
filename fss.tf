# Copyright (c) 2022, 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  desired_fss_mt_throughput = 20
}

resource "oci_file_storage_file_system" "oke_file_system" {

    availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
    compartment_id      = var.compartment_id
    display_name        = "fss-oke-${local.state_id}"
}

resource "oci_file_storage_mount_target" "oke_mount_target" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id = var.compartment_id
  
  subnet_id = module.oke.fss_subnet_id
  nsg_ids = [module.oke.fss_nsg_id]

  display_name = "mt-oke-${local.state_id}"

  defined_tags = var.use_defined_tags ? lookup(var.defined_tags, "fss") : {}
  freeform_tags = lookup(var.freeform_tags, "fss")
  
  requested_throughput = 1

  lifecycle {
    ignore_changes = [ defined_tags, freeform_tags, requested_throughput]
  }
}

resource "oci_file_storage_export_set" "oke_export_set" {
  mount_target_id = oci_file_storage_mount_target.oke_mount_target.id
}

resource "oci_file_storage_export" "oke_export" {
  export_set_id = oci_file_storage_export_set.oke_export_set.id
  file_system_id = oci_file_storage_file_system.oke_file_system.id
  path = "/alphafold2"

  export_options {
    source = "0.0.0.0/0"
    access = "READ_WRITE"
    allowed_auth = ["SYS"]
    anonymous_gid = 65534
    anonymous_uid = 65534
    identity_squash = "NONE"
    is_anonymous_access_allowed = true
    require_privileged_source_port = false
  }
}


# # Policy to update FSS performance via the operator host is not yet implemented. This requires IAM policies to be added.
# resource "null_resource" "helm_deployment_via_operator" {
#   count = var.create_operator_and_bastion ? 1 : 0

#   triggers = {
#     desired_fss_mt_throughput = local.desired_fss_mt_throughput
#   }

#   connection {
#     bastion_host        = module.oke.bastion_public_ip
#     bastion_user        = var.bastion_user
#     bastion_private_key = tls_private_key.stack_key.private_key_openssh
#     host                = module.oke.operator_private_ip
#     user                = var.bastion_user
#     private_key         = tls_private_key.stack_key.private_key_openssh
#     timeout             = "40m"
#     type                = "ssh"
#   }

#   provisioner "remote-exec" {
#     inline = ["oci fs mount-target upgrade-shape --mount-target-id  ${oci_file_storage_mount_target.oke_mount_target.id} --requested-throughput ${self.triggers.desired_fss_mt_throughput} | jq"]
#   }

#   depends_on = [ time_sleep.wait_60_seconds, oci_file_storage_mount_target.oke_mount_target ]
# }

# resource "time_sleep" "wait_60_seconds" {
#   depends_on = [oci_identity_policy.operator_fss_policy]

#   create_duration = "60s"
# }

# resource "oci_identity_policy" "operator_fss_policy" {
#   count = var.create_cluster != null && var.create_operator_policy_to_manage_cluster && var.create_operator_and_bastion ? 1 : 0

#   provider = oci.home

#   compartment_id = var.compartment_id
#   description    = "Policies for OKE Operator host state ${local.state_id}"
#   name           = "oke-operator-manage-fss-${local.state_id}"
#   statements = [
#     "ALLOW any-user to manage mount-targets in compartment id ${var.compartment_id} where all {request.principal.type = 'instance', request.principal.id = '${module.oke.operator_id}', request.operation = 'UpgradeMountTarget'}"
#   ]
#   defined_tags = var.use_defined_tags ? lookup(var.defined_tags, "iam") : {}
#   freeform_tags = lookup(var.freeform_tags, "iam")
#   lifecycle {
#     ignore_changes = [defined_tags, freeform_tags]
#   }
# }

# resource "null_resource" "upgrade_mt_throughput_from_local" {
#   count = alltrue([!var.create_operator_and_bastion, var.control_plane_is_public]) ? 1 : 0

#   triggers = {
#     desired_fss_mt_throughput = local.desired_fss_mt_throughput
#   }

#   provisioner "local-exec" {
#     command     = <<-EOT
#       oci fs mount-target upgrade-shape --mount-target-id  ${oci_file_storage_mount_target.oke_mount_target.id} --requested-throughput ${self.triggers.desired_fss_mt_throughput} | jq
#       EOT
#   }

#   depends_on = [ oci_file_storage_mount_target.oke_mount_target ]
# }