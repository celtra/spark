#!/usr/bin/env coffee
##
# Policy can be max 2048 bytes.

stack_name = process.argv[2]

json = ->
    iam =
        Statement: [{
###############################################################################
#                              EC2 Permissions                                #
###############################################################################
            Action: [
                "ec2:AuthorizeSecurityGroupIngress"
                "ec2:BundleImage",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:Describe*",
                "ec2:RegisterImage",
                "ec2:RunInstances",
                "ec2:allocateAddress",
                "ec2:associateAddress",
                "route53:ListHostedZones",
                "route53:ChangeResourceRecordSets",
                "route53:Get*"
                ],
            Effect: "Allow",
            Resource: "*"
        },
        #{
        #    Action: [
        #        "route53:ChangeResourceRecordSets"
        #        ],
        #    Effect: "Allow",
        #    Resource: ""
        #},
        {
            Action: [
                "ec2:TerminateInstance",
                "ec2:DeleteSecurityGroup"
                ],
            Effect: "Allow",
            Resource: "*",
            ## This will fail for autoscaling:DeleteAutoScalingGroup
            Condition: {
                StringEquals: {
                    "ec2:ResourceTag/stack-name": "#{stack_name}"
                }
            }
        },
        {
            Action: [
                "ec2:RevokeSecurityGroupIngress"
                ],
            Effect: "Allow",
            Resource: "*"
        }
###############################################################################
#                          AutoScaling Permissions                            #
###############################################################################
        {
            ## This can delete all scaling groups and configs.
            Action: [
                "autoscaling:CreateAutoScalingGroup",
                "autoscaling:CreateLaunchConfiguration",
                "autoscaling:CreateOrUpdateTags",
                "autoscaling:Describe*",
                "autoscaling:DeleteAutoScalingGroup",
                "autoscaling:DeleteLaunchConfiguration",
                "autoscaling:PutNotificationConfiguration",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:UpdateAutoScalingGroup",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
                ],
            Effect: "Allow",
            Resource: "*"
        },
###############################################################################
#                          CloudWatch Permissions                             #
###############################################################################
        ## Cannot specify how to delete just our alarms
        ## Might change in the future:
        ## http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/UsingIAM.html
        ## Does not support tagging
        {
            Action: [
                "cloudwatch:DeleteAlarms",
                "cloudwatch:PutMetricAlarm"
                ],
            Effect: "Allow",
            Resource: "*"
        },
###############################################################################
#                        CloudFormation Permissions                           #
###############################################################################
        {
            Action: [
                "cloudformation:ListStacks"
                ],
            Effect: "Allow",
            Resource: "*"
        },
        {
            Action: [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:UpdateStack",
                "cloudformation:Describe*"
                ],
            Resource: "arn:aws:cloudformation:*:*:stack/#{stack_name}/*"
            Effect: "Allow",
        },
###############################################################################
#                                SNS Permissions                              #
###############################################################################
        {
            Action: [
                "SNS:CreateTopic",
                "SNS:DeleteTopic",
                "SNS:Subscribe"
                ],
            Effect: "Allow",
            Resource: "arn:aws:sns:*:*:#{stack_name}-NotificationTopic-*"
        },
        {
            Action: [
                "SNS:ListTopics"
                ],
            Effect: "Allow",
            Resource: "arn:aws:sns:*:*:*"
        },
###############################################################################
#                                 S3 Permissions                              #
###############################################################################
        {
            Action: [
                "s3:PutObject",
                "s3:GetBucketLocation",
                "s3:PutObjectAcl"
                ],
            Effect: "Allow",
            Resource: [
                "arn:aws:s3:::celtra-test-ami",
                "arn:aws:s3:::celtra-test-ami/*"
                ]
        },
        {
            Action: [
                "s3:ListAllMyBuckets"
                ],
            Effect: "Allow",
            Resource: "arn:aws:s3:::*"
        }]

console.log JSON.stringify json(), null, 4
