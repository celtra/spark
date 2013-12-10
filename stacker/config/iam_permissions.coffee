#!/usr/bin/env coffee

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
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeSecurityGroups",
                "ec2:RegisterImage",
                ]
            Effect: "Allow",
            Resource: "*"
        },
        ## This can delete all security groups but I'm not sure how to limit
        ## it.
        {
            Action: [
                "ec2:DeleteSecurityGroup",
                "ec2:RevokeSecurityGroupIngress"
                ]
            Effect: "Allow",
            Resource: "*"
        },
###############################################################################
#                          AutoScaling Permissions                            #
###############################################################################
        {
            Action: [
                "autoscaling:CreateAutoScalingGroup",
                "autoscaling:CreateLaunchConfiguration",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeScalingActivities"
                ]
            Effect: "Allow",
            Resource: "*"
        },
        ## This can delete all scaling groups and configs.
        {
            Action: [
                "autoscaling:DeleteAutoScalingGroup",
                "autoscaling:DeleteLaunchConfiguration",
                "autoscaling:DeleteLaunchConfiguration",
                "autoscaling:PutNotificationConfiguration",
                "autoscaling:UpdateAutoScalingGroup",
                ]
            Effect: "Allow",
            Resource: "*",
        },
###############################################################################
#                          CloudWatch Permissions                             #
###############################################################################
        {
            Action: [
                "cloudwatch:PutMetricAlarm"
                ]
            Effect: "Allow",
            Resource: "*"
            Condition: {
                ArnLike: {
                    "aws:SourceArn": "arn:aws:cloudwatch:*:*:sparkie-test-*"
                }
            }
        },
        ## Cannot specify how to delete just our alarms
        ## Might change in the future:
        ## http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/UsingIAM.html
        {
            Action: [
                "cloudwatch:DeleteAlarms"
                ]
            Effect: "Allow",
            Resource: "*"
        },
###############################################################################
#                        CloudFormation Permissions                           #
###############################################################################
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
