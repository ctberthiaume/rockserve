#!/bin/bash
export TF_VAR_ssh_public_key=key-path.pub
export TF_VAR_ssh_private_key=key-path
export TF_VAR_prom_user=api-user
export TF_VAR_prom_password=api-secret
export TF_VAR_rockserve_binary=rockserve-binary
export TF_VAR_eip_id=elastic-ip-allocation-id