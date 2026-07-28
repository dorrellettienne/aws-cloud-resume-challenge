import importlib.util
import json
from decimal import Decimal
from pathlib import Path
from unittest.mock import Mock


MODULE_PATH = Path(__file__).parents[1] / "infra" / "lambda" / "func.py"
SPEC = importlib.util.spec_from_file_location("visitor_counter", MODULE_PATH)
visitor_counter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(visitor_counter)


def test_lambda_handler_increments_counter_atomically(monkeypatch):
    table = Mock()
    table.update_item.return_value = {"Attributes": {"views": Decimal("42")}}
    monkeypatch.setattr(visitor_counter, "table", table)

    response = visitor_counter.lambda_handler(
        {"requestContext": {"http": {"method": "GET"}}},
        None,
    )

    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == {"views": 42}
    table.update_item.assert_called_once_with(
        Key={"id": "1"},
        UpdateExpression="ADD #views :increment",
        ExpressionAttributeNames={"#views": "views"},
        ExpressionAttributeValues={":increment": 1},
        ReturnValues="UPDATED_NEW",
    )


def test_lambda_handler_rejects_unsupported_methods(monkeypatch):
    table = Mock()
    monkeypatch.setattr(visitor_counter, "table", table)

    response = visitor_counter.lambda_handler(
        {"requestContext": {"http": {"method": "POST"}}},
        None,
    )

    assert response["statusCode"] == 405
    assert json.loads(response["body"]) == {"error": "Method not allowed"}
    table.update_item.assert_not_called()
