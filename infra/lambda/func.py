import json
import os

import boto3


table = None


def _get_table():
    global table
    if table is None:
        dynamodb = boto3.resource("dynamodb")
        table = dynamodb.Table(
            os.environ.get("TABLE_NAME", "cloud-resume-counter")
        )
    return table


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
        },
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    method = (
        event.get("requestContext", {})
        .get("http", {})
        .get("method", "GET")
    )
    if method != "GET":
        return _response(405, {"error": "Method not allowed"})

    response = _get_table().update_item(
        Key={"id": "1"},
        UpdateExpression="ADD #views :increment",
        ExpressionAttributeNames={"#views": "views"},
        ExpressionAttributeValues={":increment": 1},
        ReturnValues="UPDATED_NEW",
    )
    views = int(response["Attributes"]["views"])

    return _response(200, {"views": views})
