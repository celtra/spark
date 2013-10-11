#!/usr/bin/env coffee
##
# Create template file for AWS CloudFormation.
#
##
# Main Template
##
template = ->
    stack =
        AWSTemplateFormatVersion: '2010-09-09'
        Description: 'Spark stack'
        # Limited to 32 params
        # Updating parameters might require to delete and create stack.
        Parameters:
            sshKey:
                Description: 'Name of an existing EC2 KeyPair for SSH access to the instances'
                Type: 'String'
                Default: "{{ sshKey }}"
                
            ami:
                Description: 'Common AMI id, which is used for all servers.'
                Type: 'String'
                
            notifyEmail:
                Description: 'Who to notify via Email with AutoScaling notifications'
                Type: 'String'
                
            promptColor:
                Description: 'Shell prompt color, red for production, green for test'
                Type: 'String'
            
            clusterName:
                Description: "AWS CloudFormation Stack name. Should be the same as the one in config."
                Type: 'String'
            
            availabilityZone:
                Description: "AWS Availability Zones"
                Type: 'String'
            
            sumoUsername:
                Description: "SumoLogic Collector Registration Username"
                Type: 'String'
                
            sumoPassword:
                Description: "SumoLogic Collector Registration Password"
                Type: 'String'

            slaveAutoScalingMin:
                Description: 'Min number of servers in Slave AutoScalingGroup.'
                Type: 'String'
                Default: '1'
                
            slaveAutoScalingMax:
                Description: 'Max number of servers in Slave AutoScalingGroup.'
                Type: 'String'
                Default: '1'
                
            slaveInstanceType:
                Description: "slave instance type"
                Type: 'String'
                Default: 'm1.small'
                AllowedValues: ['m1.small','m1.medium','m1.large','m1.xlarge',
                                'm2.xlarge','m2.2xlarge','m2.4xlarge','c1.medium',
                                'c1.xlarge','cc1.4xlarge','cc2.8xlarge','cg1.4xlarge']
                ConstraintDescription: 'Must be a valid EC2 instance type.'

            masterAutoScalingMin:
                Description: 'Min number of servers in Master AutoScalingGroup.'
                Type: 'String'
                Default: '1'
                
            masterAutoScalingMax:
                Description: 'Max number of servers in Master AutoScalingGroup.'
                Type: 'String'
                Default: '1'

            masterInstanceType:
                Description: "master instance type"
                Type: 'String'
                Default: 'm1.small'
                AllowedValues: ['m1.small','m1.medium','m1.large','m1.xlarge',
                                'm2.xlarge','m2.2xlarge','m2.4xlarge','c1.medium',
                                'c1.xlarge','cc1.4xlarge','cc2.8xlarge','cg1.4xlarge']
                ConstraintDescription: 'Must be a valid EC2 instance type.'
                
        Resources:
            SlaveWaitHandle:
                Type: 'AWS::CloudFormation::WaitConditionHandle'
                Properties: {}
                    
            SlaveWaitCondition:
                Type: 'AWS::CloudFormation::WaitCondition'
                DependsOn: 'MasterScalingGroup'
                Properties:
                    Handle: { Ref: 'SlaveWaitHandle' }
                    Timeout: '4500'

            NotificationTopic:
                Type: 'AWS::SNS::Topic'
                Properties:
                    Subscription: [
                        Endpoint: {Ref: "notifyEmail"}
                        Protocol: 'email']
            
            MasterSecurityGroup:
                Type: 'AWS::EC2::SecurityGroup'
                Properties:
                    GroupDescription: 'Enable HTTP access via port 80, locked down to requests from the load balancer only and SSH access'
                    SecurityGroupIngress: [{
                        IpProtocol: 'tcp'
                        FromPort: 8080
                        ToPort: 8080
                        CidrIp: '89.143.12.238/32'
                    },{
                        IpProtocol: 'tcp'
                        FromPort: 22
                        ToPort: 22
                        CidrIp: '0.0.0.0/0'
                    }]
            
            MasterSecurityGroupIngress:
                Type: 'AWS::EC2::SecurityGroupIngress'
                Properties:
                    GroupName: { Ref: 'MasterSecurityGroup' }
                    SourceSecurityGroupName: { Ref: 'SlaveSecurityGroup' }
                    IpProtocol: 'tcp'
                    FromPort: '7077'
                    ToPort: '7077'

            SlaveSecurityGroup:
                Type: 'AWS::EC2::SecurityGroup'
                Properties:
                    GroupDescription: 'Enable HTTP access via port 80, locked down to requests from the load balancer only and SSH access'
                    SecurityGroupIngress: [{
                        IpProtocol: 'tcp'
                        FromPort: 22
                        ToPort: 22
                        CidrIp: '0.0.0.0/0'
                    },{
                        IpProtocol: 'tcp'
                        FromPort: 8081
                        ToPort: 8081
                        CidrIp: '89.143.12.238/32'
                    }]
                    
            SlaveSecurityGroupIngress1:
                Type: 'AWS::EC2::SecurityGroupIngress'
                Properties:
                    GroupName: { Ref: 'SlaveSecurityGroup' }
                    SourceSecurityGroupName: { Ref: 'MasterSecurityGroup' }
                    IpProtocol: 'tcp'
                    FromPort: 7077
                    ToPort: 7077
                    
            SlaveSecurityGroupIngress2:
                Type: 'AWS::EC2::SecurityGroupIngress'
                Properties:
                    GroupName: { Ref: 'SlaveSecurityGroup' }
                    SourceSecurityGroupName: { Ref: 'SlaveSecurityGroup' }
                    IpProtocol: 'tcp'
                    FromPort: 0
                    ToPort: 65535

            MasterScalingGroup:
                Type: 'AWS::AutoScaling::AutoScalingGroup'
                UpdatePolicy:
                    AutoScalingRollingUpdate:
                        MinInstancesInService : "0",
                        MaxBatchSize : "32",
                        PauseTime : "PT0M"
                Properties:
                    AvailabilityZones:  [ {Ref: 'availabilityZone'} ]
                    LaunchConfigurationName: {Ref: "MasterLaunchConfig"}
                    MinSize: {Ref: "masterAutoScalingMin"}
                    MaxSize: {Ref: "masterAutoScalingMax"}
                    NotificationConfiguration:
                        TopicARN: {Ref: "NotificationTopic"}
                        NotificationTypes: [
                            'autoscaling:EC2_INSTANCE_LAUNCH'
                            'autoscaling:EC2_INSTANCE_LAUNCH_ERROR'
                            'autoscaling:EC2_INSTANCE_TERMINATE'
                            'autoscaling:EC2_INSTANCE_TERMINATE_ERROR']

            MasterLaunchConfig:
                Type: 'AWS::AutoScaling::LaunchConfiguration'
                Properties:
                    ImageId: {Ref: 'ami'}
                    SecurityGroups: ['default', {Ref: 'MasterSecurityGroup'}]
                    InstanceType: {Ref: "masterInstanceType"}
                    KeyName: {Ref: 'sshKey'}
                    UserData: {'Fn::Base64': {'Fn::Join': [ "", [
                        "CLUSTER_NAME=\"", {Ref: "clusterName"}, "\"\n",
                        "SERVER_ROLE='master'\n",
                        "PROMPT_COLOR=\"", {Ref: "promptColor"}, "\"\n"
                        "SUMO_USERNAME=\"", {Ref: "sumoUsername"}, "\"\n"
                        "SUMO_PASSWORD=\"", {Ref: "sumoPassword"}, "\"\n"
                        "SIGNAL_URL=\"", { Ref: "SlaveWaitHandle" }, "\"\n"
                    ]]}}

            SlaveLaunchConfig:
                Type: 'AWS::AutoScaling::LaunchConfiguration'
                Properties:
                    ImageId: {Ref: 'ami'}
                    SecurityGroups: ['default', {Ref: 'SlaveSecurityGroup'}]
                    InstanceType: {Ref: "slaveInstanceType"}
                    KeyName: {Ref: 'sshKey'}
                    UserData: {'Fn::Base64': {'Fn::Join': [ "", [
                        "CLUSTER_NAME=\"", {Ref: "clusterName"}, "\"\n",
                        "SERVER_ROLE='slave'\n",
                        "PROMPT_COLOR=\"", {Ref: "promptColor"}, "\"\n",
                        "SUMO_USERNAME=\"", {Ref: "sumoUsername"}, "\"\n"
                        "SUMO_PASSWORD=\"", {Ref: "sumoPassword"}, "\"\n"
                        "SIGNAL_URL=\"", { Ref: "SlaveWaitHandle" }, "\"\n",
                        "MASTER_IP=\"", { 'Fn::GetAtt' : [ "SlaveWaitCondition", "Data" ]}, "\"\n"
                    ]]}}
            
            SlaveScalingGroup:
                Type: 'AWS::AutoScaling::AutoScalingGroup'
                UpdatePolicy:
                    AutoScalingRollingUpdate:
                        MinInstancesInService : "0",
                        MaxBatchSize : "32",
                        PauseTime : "PT0M"
                Properties:
                    AvailabilityZones:  [ {Ref: 'availabilityZone'} ]
                    LaunchConfigurationName: {Ref: "SlaveLaunchConfig"}
                    MinSize: {Ref: "slaveAutoScalingMin"}
                    MaxSize: {Ref: "slaveAutoScalingMax"}
                    NotificationConfiguration:
                        TopicARN: {Ref: "NotificationTopic"}
                        NotificationTypes: [
                            'autoscaling:EC2_INSTANCE_LAUNCH'
                            'autoscaling:EC2_INSTANCE_LAUNCH_ERROR'
                            'autoscaling:EC2_INSTANCE_TERMINATE'
                            'autoscaling:EC2_INSTANCE_TERMINATE_ERROR']
            
            SystemCheck:
                Type: 'AWS::CloudWatch::Alarm'
                Properties:
                    AlarmDescription: 'SystemCheck'
                    MetricName: 'StatusCheckFailed_System'
                    Namespace: 'AWS/EC2'
                    Statistic: 'Maximum'
                    Period: 60
                    EvaluationPeriods: 1
                    Threshold: 1
                    AlarmActions: [{Ref: 'NotificationTopic'}]
                    Dimensions: [
                        Name: 'AutoScalingGroupName',
                        Value: {Ref: "SlaveScalingGroup"}]
                    ComparisonOperator: 'GreaterThanOrEqualToThreshold'
                    
            InstanceCheck:
                Type: 'AWS::CloudWatch::Alarm'
                Properties:
                    AlarmDescription: 'SystemCheck'
                    MetricName: 'StatusCheckFailed_Instance'
                    Namespace: 'AWS/EC2'
                    Statistic: 'Maximum'
                    Period: 60
                    EvaluationPeriods: 1
                    Threshold: 1
                    AlarmActions: [{Ref: 'NotificationTopic'}]
                    Dimensions: [
                        Name: 'AutoScalingGroupName',
                        Value: {Ref: "SlaveScalingGroup"}]
                    ComparisonOperator: 'GreaterThanOrEqualToThreshold'
                    
    stack

console.log JSON.stringify template()
