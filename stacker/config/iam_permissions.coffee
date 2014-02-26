#!/usr/bin/env coffee
##
# Policy can be max 2048 bytes.

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
                "ec2:RegisterImage"
                ],
            Effect: "Allow",
            Resource: "*"
        },
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
                    "ec2:ResourceTag/stack-name": "sparkie-test"
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
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeScalingActivities",
                "autoscaling:DescribeScheduledActions",
                "autoscaling:DeleteAutoScalingGroup",
                "autoscaling:DeleteLaunchConfiguration",
                "autoscaling:PutNotificationConfiguration",
                "autoscaling:UpdateAutoScalingGroup"
                ],
            Effect: "Allow",
            Resource: "*"
        },
###############################################################################
#                          CloudWatch Permissions                             #
###############################################################################
        {
            Action: [
                "cloudwatch:PutMetricAlarm"
                ],
            Effect: "Allow",
            Resource: "*"
        },
        ## Cannot specify how to delete just our alarms
        ## Might change in the future:
        ## http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/UsingIAM.html
        ## Does not support tagging
        {
            Action: [
                "cloudwatch:DeleteAlarms"
                ],
            Effect: "Allow",
            Resource: "*"
        },
###############################################################################
#                        CloudFormation Permissions                           #
###############################################################################
        {
            Effect: "Allow",
            Action: [
                "cloudformation:ListStacks"
                ],
            Resource: "arn:aws:cloudformation:*:*:stack/*"
        },
        {
            Effect: "Allow",
            Action: [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:UpdateStack",
                "cloudformation:DescribeStacks",
                "cloudformation:DescribeStackEvents"
                ],
            Resource: "arn:aws:cloudformation:*:*:stack/sparkie-test/*"
        },
###############################################################################
#                                SNS Permissions                              #
###############################################################################
        {
            Effect: "Allow",
            Action: [
                "SNS:CreateTopic",
                "SNS:Subscribe"
                ],
            Resource: "arn:aws:sns:*:*:sparkie-test-NotificationTopic-*"
        },
        {
            Effect: "Allow",
            Action: [
                "SNS:ListTopics"
                ],
            Resource: "arn:aws:sns:*:*:*"
        },
        {
            Effect: "Allow",
            Action: [
                "SNS:DeleteTopic"
                ],
            Resource: "arn:aws:sns:*:*:sparkie-test-NotificationTopic-*"
        },
###############################################################################
#                                 S3 Permissions                              #
###############################################################################
        {
            Effect: "Allow",
            Action: [
                "s3:PutObject",
                "s3:GetBucketLocation",
                "s3:PutObjectAcl"
                ],
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
