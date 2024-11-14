#!/bin/bash

# Variables
VPC_NAME="DefTech"

# Retrieve VPC ID using tag
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --query 'Vpcs[0].VpcId' --output text)
echo "VPC ID: $VPC_ID"

# Terminate instances
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" --query 'Reservations[*].Instances[*].InstanceId' --output text | tr '\t' '\n')
echo "Instance IDs: $INSTANCE_IDS"

if [ -n "$INSTANCE_IDS" ]; then
  for INSTANCE_ID in $INSTANCE_IDS; do
    if [ "$INSTANCE_ID" != "None" ]; then
      echo "Terminating instance: $INSTANCE_ID"
      aws ec2 terminate-instances --instance-ids $INSTANCE_ID
    fi
  done

  # Wait for all instances to terminate
  for INSTANCE_ID in $INSTANCE_IDS; do
    if [ "$INSTANCE_ID" != "None" ]; then
      echo "Waiting for instance to terminate: $INSTANCE_ID"
      aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
    fi
  done
fi

# Delete network interfaces
NETWORK_INTERFACE_IDS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text | tr '\t' '\n')
echo "Network Interface IDs: $NETWORK_INTERFACE_IDS"

for NETWORK_INTERFACE_ID in $NETWORK_INTERFACE_IDS; do
  if [ "$NETWORK_INTERFACE_ID" != "None" ]; then
    echo "Deleting network interface: $NETWORK_INTERFACE_ID"
    aws ec2 delete-network-interface --network-interface-id $NETWORK_INTERFACE_ID
  fi
done

# Delete subnets
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text | tr '\t' '\n')
echo "Subnet IDs: $SUBNET_IDS"
for SUBNET_ID in $SUBNET_IDS; do
  if [ "$SUBNET_ID" != "None" ]; then
    echo "Deleting subnet: $SUBNET_ID"
    aws ec2 delete-subnet --subnet-id $SUBNET_ID
  fi
done

# Release Elastic IPs
ALLOC_IDS=$(aws ec2 describe-addresses --filters "Name=instance-id,Values=$INSTANCE_IDS" --query 'Addresses[*].AllocationId' --output text | tr '\t' '\n')
echo "Allocation IDs: $ALLOC_IDS"
if [ -n "$ALLOC_IDS" ]; then
  for ALLOC_ID in $ALLOC_IDS; do
    if [ "$ALLOC_ID" != "None" ]; then
      echo "Releasing Elastic IP: $ALLOC_ID"
      aws ec2 release-address --allocation-id $ALLOC_ID
    fi
  done
fi

# Disassociate and delete route tables, skipping the main route table
RTB_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[*].RouteTableId' --output text | tr '\t' '\n')
echo "Route Table IDs: $RTB_IDS"

MAIN_RTB_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[?Main==true]].RouteTableId' --output text)
echo "Main Route Table ID: $MAIN_RTB_ID"

for RTB_ID in $RTB_IDS; do
  if [ "$RTB_ID" != "None" ] && [ "$RTB_ID" != "$MAIN_RTB_ID" ]; then
    ASSOCIATION_IDS=$(aws ec2 describe-route-tables --route-table-ids $RTB_ID --query 'RouteTables[*].Associations[*].RouteTableAssociationId' --output text | tr '\t' '\n')
    for ASSOC_ID in $ASSOCIATION_IDS; do
      if [ "$ASSOC_ID" != "None" ]; then
        echo "Disassociating route table association: $ASSOC_ID"
        aws ec2 disassociate-route-table --association-id $ASSOC_ID
      fi
    done
    echo "Deleting route table: $RTB_ID"
    aws ec2 delete-route-table --route-table-id $RTB_ID
  fi
done

# Detach and delete Internet Gateway
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)
echo "Internet Gateway ID: $IGW_ID"
if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
  echo "Detaching and deleting Internet Gateway: $IGW_ID"
  aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
  aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
fi

# Delete VPC
echo "Deleting VPC: $VPC_ID"
aws ec2 delete-vpc --vpc-id $VPC_ID
echo "VPC $VPC_ID supprimé"
