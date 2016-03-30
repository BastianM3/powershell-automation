import boto3
import logging
import datetime
import uuid
import json
import sys

#from boto3.dynamodb.table import Table

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def logCostSavings(event, context):
    data = event
    print "[LOG] :: Input data from event = {}".format(str(data))

    #    logger.info('JSON appears to be ok.')
    
    now = datetime.datetime.now().isoformat()
    
    # Declare variables using all of the json members sent via web request
    sourceApplication = event['SourceApplication']
    manualHoursSaved = event['ManualHoursSaved']
    nameOfOperation = event['OperationName']
    automationType = event['AutomationType']
    operationName = event['OperationName']
    resultsOfOperation = event['ResultsOfOperation']
    successFlag = event['SuccessFlag']
    psErrors = event['PSErrors']
    cdKey = event['CDKey']
    
    newGuid = uuid.uuid4()
    
    client = boto3.resource('dynamodb')
    tableName = client.Table('automation-roi-logs')
    
    dbresponse  = tableName.put_item(
      Item={
                'OperationUid': str(newGuid),
                'SourceApplication' : str(sourceApplication),
                'EventDate' : str(now),
                'ManualHoursSaved' : int(manualHoursSaved),
                'OperationName' : str(nameOfOperation),
                'AutomationType' : str(automationType),
                'OperationName': str(operationName),
                'WasSuccessful': str(successFlag),
                'CDKey': str(cdKey),
                'PSErrors':str(psErrors),
                'ResultsOfOperation' : str(resultsOfOperation)
            }
    )
    
    message = '\r\n' \
              'Source Application: \t {} \r\n' \
              'Name of Operation: \t {} \r\n' \
              'Event Date: \t {} \r\n ' \
              'Manual Hours Saved: \t {} \r\n ' \
              'Type of Automation: \t {} \r\n '.format(str(sourceApplication),str(nameOfOperation),str(now),int(manualHoursSaved),automationType)
              
    logger.info('[Event] :: '.format(message))
    return message