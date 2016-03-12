#!/usr/bin/env bash

set -e

# environment

: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}
: ${AWS_STACK_PREFIX:?}
: ${BAT_VCAP_PASSWORD:?}
: ${PUBLIC_KEY_NAME:?}
: ${STEMCELL_NAME:?}

source this/shared/utils.sh
source this/aws/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

: ${AWS_ACCESS_KEY_ID:=${AWS_ACCESS_KEY}}
: ${AWS_SECRET_ACCESS_KEY:=${AWS_SECRET_KEY}}
: ${AWS_DEFAULT_REGION:=${AWS_REGION_NAME}}

# configuration
: ${SECURITY_GROUP:=$(         aws ec2 describe-security-groups --group-ids $(stack_info "SecurityGroupID") | jq -r '.SecurityGroups[] .GroupName' ) }
: ${DIRECTOR_EIP:=$(           stack_info "DirectorEIP" )}
: ${BATS_EIP:=$(               stack_info "BATsEIP" )}
: ${SUBNET_ID:=$(              stack_info "SubnetID" )}
: ${AVAILABILITY_ZONE:=$(      stack_info "AvailabilityZone" )}
: ${NETWORK_CIDR:=$(           stack_info "CIDR" )}
: ${NETWORK_GATEWAY:=$(        stack_info "Gateway" )}
: ${NETWORK_RESERVED_RANGE:=$( stack_info "ReservedRange" )}
: ${NETWORK_STATIC_RANGE:=$(   stack_info "StaticRange" )}
: ${NETWORK_STATIC_IP_1:=$(    stack_info "StaticIP1" )}
: ${NETWORK_STATIC_IP_2:=$(    stack_info "StaticIP2" )}

# preparation
cp ./director-state/shared.key ./bats-config

# env file generation
cat > "./bats-config/bats.env" <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=${DIRECTOR_EIP}
export BAT_DNS_HOST=${DIRECTOR_EIP}
export BAT_STEMCELL="${PWD}/stemcell/stemcell.tgz"
export BAT_DEPLOYMENT_SPEC="${PWD}/bats-config/bats.yml"
export BAT_INFRASTRUCTURE=aws
export BAT_NETWORKING=manual
export BAT_VIP=${BATS_EIP}
export BAT_SUBNET_ID=${SUBNET_ID}
export BAT_SECURITY_GROUP_NAME=${SECURITY_GROUP}
export BAT_VCAP_PASSWORD=${BAT_VCAP_PASSWORD}
export BAT_VCAP_PRIVATE_KEY=shared.pem
EOF

# manifest generation
cat > "./bats-config/bats.yml" <<EOF
---
cpi: aws
properties:
  vip: ${BATS_EIP}
  second_static_ip: ${NETWORK_STATIC_IP_2}
  uuid: $(bosh status --uuid)
  pool_size: 1
  stemcell:
    name: ${STEMCELL_NAME}
    version: latest
  instances: 1
  key_name:  ${PUBLIC_KEY_NAME}
  networks:
    - name: default
      static_ip: ${NETWORK_STATIC_IP_1}
      type: manual
      cidr: ${NETWORK_CIDR}
      reserved: [${NETWORK_RESERVED_RANGE}]
      static: [${NETWORK_STATIC_RANGE}]
      gateway: ${NETWORK_GATEWAY}
      subnet: ${SUBNET_ID}
      security_groups: [${SECURITY_GROUP}]
EOF