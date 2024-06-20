import json

def lambda_handler(event, context):
    # TODO implement
    
    print('--- The Event: ---')
    print(event)
    print('--- The Event: ---')
    
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
