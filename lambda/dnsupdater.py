def dnsupdater(event, context):
    client = boto3.client(
        aws_access_key_id = aws_key_id,
        aws_secret_access_key = aws_key_secret,
        service_name = "route53"
    )

    hosted_zone = client.get_hosted_zone(Id='Z33OB2FVC6P1M9')

    client.change_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        ChangeBatch = {
            'Comment': "Will this work?",
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': event['subdomain'],
                        'Type': 'A',
                        'TTL': 300,
                        'ResourceRecords': [
                            {
                                'Value': event['source_ip']
                            }
                        ]
                    }
                }
            ]
        }
    )
