#!/usr/bin/env coffee

json = ->
    iam =
        Statement: [{
        ###
        # EC2 Permissions
        ###
            Action: [
                "ec2:DescribeImages",
                "ec2:RegisterImage",
                "ec2:BundleImage",
                "ec2:DescribeInstances",
                "ec2:CreateSecurityGroup"
                ]
            Effect: "Allow",
            Resource: [
                "*"
            ]
        },

        ###
        # CloudFormation Permissions
        ###
        {
            Effect: "Allow",
            Action: [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:UpdateStack",
                "cloudformation:DescribeStacks",
                "cloudformation:DescribeStackEvents"
            ],
            Resource: [
                "arn:aws:cloudformation:us-east-1:*:stack/sparkie-test/*"
            ]
        },

        ###
        # SNS Permissions
        ###
        {
            Effect: "Allow",
            Action: [
                "SNS:CreateTopic",
                "SNS:Subscribe"
          ],
            Resource: [
                "arn:aws:sns:us-east-1:*:sparkie-test-NotificationTopic*"
          ]
        },
        {
            Effect: "Allow",
            Action: [
                "SNS:ListTopics"
            ],
            Resource: [
                "arn:aws:sns:us-east-1:*:*"
            ]
        },

        ###
        # S3 Permissions
        ###
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
