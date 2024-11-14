#!/bin/bash

# Variables
VPC_CIDR="192.168.0.0/16"
DMZ_CIDR="192.168.1.0/24"
LAN_CIDR="192.168.2.0/24"
REGION="eu-west-3"
KEY_NAME="ma_clef"
VPC_NAME="DefTech"
DMZ_SUBNET_NAME="DMZ"
LAN_SUBNET_NAME="LAN"
IGW_NAME="InternetGateway"
PUBLIC_RT_NAME="PublicRouteTable"
PRIVATE_RT_NAME="PrivateRouteTable"
DMZ_INSTANCE_NAME="ApiInstance"
LAN_INSTANCE_NAME="RDMS"

# Créer le VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --query 'Vpc.VpcId' --output text)
echo "VPC créé avec ID: $VPC_ID"
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME

# Créer le sous-réseau DMZ (public)
DMZ_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $DMZ_CIDR --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
echo "Sous-réseau DMZ créé avec ID: $DMZ_SUBNET_ID"
aws ec2 create-tags --resources $DMZ_SUBNET_ID --tags Key=Name,Value=$DMZ_SUBNET_NAME

# Créer le sous-réseau LAN (privé)
LAN_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $LAN_CIDR --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
echo "Sous-réseau LAN créé avec ID: $LAN_SUBNET_ID"
aws ec2 create-tags --resources $LAN_SUBNET_ID --tags Key=Name,Value=$LAN_SUBNET_NAME

# Créer une passerelle Internet
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
echo "Passerelle Internet créée avec ID: $IGW_ID"
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=$IGW_NAME

# Attacher la passerelle Internet au VPC
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
echo "Passerelle Internet attachée au VPC"

# Créer une table de routage publique
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
echo "Table de routage publique créée avec ID: $PUBLIC_ROUTE_TABLE_ID"
aws ec2 create-tags --resources $PUBLIC_ROUTE_TABLE_ID --tags Key=Name,Value=$PUBLIC_RT_NAME

# Ajouter une route vers la passerelle Internet dans la table de routage publique
aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
echo "Route vers la passerelle Internet créée dans la table de routage publique"

# Associer la table de routage publique au sous-réseau DMZ
aws ec2 associate-route-table --subnet-id $DMZ_SUBNET_ID --route-table-id $PUBLIC_ROUTE_TABLE_ID
echo "Table de routage publique associée au sous-réseau DMZ"

# Modifier le sous-réseau DMZ pour qu'il soit public
aws ec2 modify-subnet-attribute --subnet-id $DMZ_SUBNET_ID --map-public-ip-on-launch
echo "Le sous-réseau DMZ rendu public"

# Créer une table de routage privée pour le LAN
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
echo "Table de routage privée créée avec ID: $PRIVATE_ROUTE_TABLE_ID"
aws ec2 create-tags --resources $PRIVATE_ROUTE_TABLE_ID --tags Key=Name,Value=$PRIVATE_RT_NAME

# Associer la table de routage privée au sous-réseau LAN
aws ec2 associate-route-table --subnet-id $LAN_SUBNET_ID --route-table-id $PRIVATE_ROUTE_TABLE_ID
echo "Table de routage privée associée au sous-réseau LAN"

# Créer une instance dans le sous-réseau DMZ
DMZ_INSTANCE_ID=$(aws ec2 run-instances --image-id ami-09d83d8d719da9808 --count 1 --instance-type t2.micro --key-name $KEY_NAME --subnet-id $DMZ_SUBNET_ID --associate-public-ip-address --query 'Instances[0].InstanceId' --output text)
echo "Instance créée dans le DMZ avec ID: $DMZ_INSTANCE_ID"
aws ec2 create-tags --resources $DMZ_INSTANCE_ID --tags Key=Name,Value=$DMZ_INSTANCE_NAME

# Créer une instance dans le sous-réseau LAN
LAN_INSTANCE_ID=$(aws ec2 run-instances --image-id ami-09d83d8d719da9808 --count 1 --instance-type t2.micro --key-name $KEY_NAME --subnet-id $LAN_SUBNET_ID --query 'Instances[0].InstanceId' --output text)
echo "Instance créée dans le LAN avec ID: $LAN_INSTANCE_ID"
aws ec2 create-tags --resources $LAN_INSTANCE_ID --tags Key=Name,Value=$LAN_INSTANCE_NAME
