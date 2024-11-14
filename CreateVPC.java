import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.regions.Regions;
import com.amazonaws.services.ec2.AmazonEC2;
import com.amazonaws.services.ec2.AmazonEC2ClientBuilder;
import com.amazonaws.services.ec2.model.*;

public class CreateVPCExample {
    public static void main(String[] args) {
        // Configuration des identifiants AWS (remplacez par vos clés)
        BasicAWSCredentials awsCreds = new BasicAWSCredentials("access_key", "secret_key");

        AmazonEC2 ec2 = AmazonEC2ClientBuilder.standard()
                .withRegion(Regions.EU_WEST_3)
                .withCredentials(new AWSStaticCredentialsProvider(awsCreds))
                .build();

        // Variables
        String vpcCidr = "192.168.0.0/16";
        String dmzCidr = "192.168.1.0/24";
        String lanCidr = "192.168.2.0/24";
        String region = "eu-west-3";
        String keyName = "ma_clef";
        String vpcName = "DefTech";
        String dmzSubnetName = "DMZ";
        String lanSubnetName = "LAN";
        String igwName = "InternetGateway";
        String publicRtName = "PublicRouteTable";
        String privateRtName = "PrivateRouteTable";
        String dmzInstanceName = "ApiInstance";
        String lanInstanceName = "RDMS";

        // Créer le VPC
        CreateVpcRequest createVpcRequest = new CreateVpcRequest().withCidrBlock(vpcCidr);
        Vpc vpc = ec2.createVpc(createVpcRequest).getVpc();
        String vpcId = vpc.getVpcId();
        System.out.println("VPC créé avec ID: " + vpcId);
        ec2.createTags(new CreateTagsRequest().withResources(vpcId)
                .withTags(new Tag("Name", vpcName)));

        // Créer le sous-réseau DMZ (public)
        CreateSubnetRequest createDmzSubnetRequest = new CreateSubnetRequest()
                .withVpcId(vpcId)
                .withCidrBlock(dmzCidr)
                .withAvailabilityZone(region + "a");
        Subnet dmzSubnet = ec2.createSubnet(createDmzSubnetRequest).getSubnet();
        String dmzSubnetId = dmzSubnet.getSubnetId();
        System.out.println("Sous-réseau DMZ créé avec ID: " + dmzSubnetId);
        ec2.createTags(new CreateTagsRequest().withResources(dmzSubnetId)
                .withTags(new Tag("Name", dmzSubnetName)));

        // Créer le sous-réseau LAN (privé)
        CreateSubnetRequest createLanSubnetRequest = new CreateSubnetRequest()
                .withVpcId(vpcId)
                .withCidrBlock(lanCidr)
                .withAvailabilityZone(region + "a");
        Subnet lanSubnet = ec2.createSubnet(createLanSubnetRequest).getSubnet();
        String lanSubnetId = lanSubnet.getSubnetId();
        System.out.println("Sous-réseau LAN créé avec ID: " + lanSubnetId);
        ec2.createTags(new CreateTagsRequest().withResources(lanSubnetId)
                .withTags(new Tag("Name", lanSubnetName)));

        // Créer une passerelle Internet
        CreateInternetGatewayRequest createIgwRequest = new CreateInternetGatewayRequest();
        InternetGateway igw = ec2.createInternetGateway(createIgwRequest).getInternetGateway();
        String igwId = igw.getInternetGatewayId();
        System.out.println("Passerelle Internet créée avec ID: " + igwId);
        ec2.createTags(new CreateTagsRequest().withResources(igwId)
                .withTags(new Tag("Name", igwName)));

        // Attacher la passerelle Internet au VPC
        AttachInternetGatewayRequest attachIgwRequest = new AttachInternetGatewayRequest()
                .withVpcId(vpcId)
                .withInternetGatewayId(igwId);
        ec2.attachInternetGateway(attachIgwRequest);
        System.out.println("Passerelle Internet attachée au VPC");

        // Créer une table de routage publique
        CreateRouteTableRequest createPublicRtRequest = new CreateRouteTableRequest()
                .withVpcId(vpcId);
        RouteTable publicRouteTable = ec2.createRouteTable(createPublicRtRequest).getRouteTable();
        String publicRouteTableId = publicRouteTable.getRouteTableId();
        System.out.println("Table de routage publique créée avec ID: " + publicRouteTableId);
        ec2.createTags(new CreateTagsRequest().withResources(publicRouteTableId)
                .withTags(new Tag("Name", publicRtName)));

        // Ajouter une route vers la passerelle Internet dans la table de routage publique
        CreateRouteRequest createRouteRequest = new CreateRouteRequest()
                .withRouteTableId(publicRouteTableId)
                .withDestinationCidrBlock("0.0.0.0/0")
                .withGatewayId(igwId);
        ec2.createRoute(createRouteRequest);
        System.out.println("Route vers la passerelle Internet créée dans la table de routage publique");

        // Associer la table de routage publique au sous-réseau DMZ
        AssociateRouteTableRequest associateDmzRtRequest = new AssociateRouteTableRequest()
                .withSubnetId(dmzSubnetId)
                .withRouteTableId(publicRouteTableId);
        ec2.associateRouteTable(associateDmzRtRequest);
        System.out.println("Table de routage publique associée au sous-réseau DMZ");

        // Modifier le sous-réseau DMZ pour qu'il soit public
        ModifySubnetAttributeRequest modifyDmzSubnetRequest = new ModifySubnetAttributeRequest()
                .withSubnetId(dmzSubnetId)
                .withMapPublicIpOnLaunch(true);
        ec2.modifySubnetAttribute(modifyDmzSubnetRequest);
        System.out.println("Le sous-réseau DMZ rendu public");

        // Créer une table de routage privée pour le LAN
        CreateRouteTableRequest createPrivateRtRequest = new CreateRouteTableRequest()
                .withVpcId(vpcId);
        RouteTable privateRouteTable = ec2.createRouteTable(createPrivateRtRequest).getRouteTable();
        String privateRouteTableId = privateRouteTable.getRouteTableId();
        System.out.println("Table de routage privée créée avec ID: " + privateRouteTableId);
        ec2.createTags(new CreateTagsRequest().withResources(privateRouteTableId)
                .withTags(new Tag("Name", privateRtName)));

        // Associer la table de routage privée au sous-réseau LAN
        AssociateRouteTableRequest associateLanRtRequest = new AssociateRouteTableRequest()
                .withSubnetId(lanSubnetId)
                .withRouteTableId(privateRouteTableId);
        ec2.associateRouteTable(associateLanRtRequest);
        System.out.println("Table de routage privée associée au sous-réseau LAN");

        // Créer une instance dans le sous-réseau DMZ
        RunInstancesRequest runDmzInstanceRequest = new RunInstancesRequest()
                .withImageId("ami-09d83d8d719da9808")
                .withInstanceType(InstanceType.T2Micro)
                .withMinCount(1)
                .withMaxCount(1)
                .withKeyName(keyName)
                .withSubnetId(dmzSubnetId)
                .withAssociatePublicIpAddress(true);
        Instance dmzInstance = ec2.runInstances(runDmzInstanceRequest).getReservation().getInstances().get(0);
        String dmzInstanceId = dmzInstance.getInstanceId();
        System.out.println("Instance créée dans le DMZ avec ID: " + dmzInstanceId);
        ec2.createTags(new CreateTagsRequest().withResources(dmzInstanceId)
                .withTags(new Tag("Name", dmzInstanceName)));

        // Créer une instance dans le sous-réseau LAN
        RunInstancesRequest runLanInstanceRequest = new RunInstancesRequest()
                .withImageId("ami-09d83d8d719da9808")
                .withInstanceType(InstanceType.T2Micro)
                .withMinCount(1)
                .withMaxCount(1)
                .withKeyName(keyName)
                .withSubnetId(lanSubnetId);
        Instance lanInstance = ec2.runInstances(runLanInstanceRequest).getReservation().getInstances().get(0);
        String lanInstanceId = lanInstance.getInstanceId();
        System.out.println("Instance créée dans le LAN avec ID: " + lanInstanceId);
        ec2.createTags(new CreateTagsRequest().withResources(lanInstanceId)
                .withTags(new Tag("Name", lanInstanceName)));
    }
}
