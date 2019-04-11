import boto3

def lambda_handler(event, context):
    client = boto3.client('route53')
    hosted_zone_id = client.get_hosted_zone(Id='Z33OB2FVC6P1M9')
    client.change_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        ChangeBatch = {
            'Comment': "Will this work?",
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': event['queryStringParameters']['subdomain'],
                        'Type': 'A',
                        'TTL': 300,
                        'ResourceRecords': [
                            {
                                'Value': event['queryStringParameters']['ip']
                            }
                        ]
                    }
                }
            ]
        }
    )
