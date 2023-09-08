import json
import boto3

def lambda_handler(event, context):
    # Initialize an S3 client
    s3_client = boto3.client('s3')

    # Extract the details of the S3 bucket creation event
    event_detail = event['detail']
    event_name = event_detail['eventName']
    request_parameters = event_detail['requestParameters']

    # Check if the event is a CreateBucket event
    if event_name == 'CreateBucket':
        bucket_name = request_parameters['bucketName']
        location_constraint = request_parameters.get('createBucketConfiguration', {}).get('locationConstraint', 'us-east-1')
        # Get the bucket's ACL (Access Control List)
        acl_response = s3_client.get_bucket_acl(Bucket=bucket_name)
        acl = acl_response['Grants']

        # Get the bucket's versioning status
        versioning_response = s3_client.get_bucket_versioning(Bucket=bucket_name)
        versioning_status = versioning_response.get('Status', 'NotEnabled')

        # Get the bucket's logging configuration
        logging_response = s3_client.get_bucket_logging(Bucket=bucket_name)
        logging_enabled = logging_response.get('LoggingEnabled', False)

        # Construct the result
        result = {
            'BucketName': bucket_name,
            'LocationConstraint': location_constraint,
            'ACL': acl,
            'VersioningStatus': versioning_status,
            'LoggingEnabled': logging_enabled
        }
        # Print the result to CloudWatch Logs
        print(json.dumps(result, indent=2))

        # You can further process or store the 'result' as needed

        return {
            'statusCode': 200,
            'body': json.dumps('S3 bucket configuration information extracted successfully!')
        }
    else:
        # This Lambda function is only interested in CreateBucket events
        return {
            'statusCode': 200,
            'body': json.dumps('Not a CreateBucket event, ignoring.')
        }
