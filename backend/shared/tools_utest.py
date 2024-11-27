from django.contrib.auth import get_user_model
from rest_framework.test import APIClient

User = get_user_model()

APIBASE = "/api/v1/"

DEFAULT_USERNAME = "testuser"
DEFAULT_PASSWORD = "(UAS(Dduuu3282879*)8y2"


def create_test_user(username=DEFAULT_USERNAME, password=DEFAULT_PASSWORD):
    try:
        return User.objects.get(username=username)
    except User.DoesNotExist:
        return User.objects.create_user(username=username, password=password)


def get_api_client(username: str = None, password: str = None) -> APIClient:
    if (username and not password) or (not username and password):
        raise ValueError(
            "If username or password is given, then also the other needs to be set"
        )

    create_test_user(
        username if username is not None else DEFAULT_USERNAME,
        password if password is not None else DEFAULT_PASSWORD,
    )

    client = APIClient()

    resp = client.post(
        APIBASE + "auth/login/",
        {
            "username": username if username else DEFAULT_USERNAME,
            "password": password if password else DEFAULT_PASSWORD,
        },
        format="json",
    )
    print(resp.data)
    client.credentials(HTTP_AUTHORIZATION="Bearer " + resp.data["access"])
    return client


def post(client: APIClient, url: str, data: dict):
    return client.post(APIBASE + url, data=data, format="json")


def get(client: APIClient, url: str):
    return client.get(APIBASE + url)


def delete(client: APIClient, url: str, resource: str = None):
    if resource is not None and resource:
        url = url + f"/{resource}"
    return client.delete(APIBASE + url)


def basic_response_validation(unittest, response, model_name: str):
    # should check its a dict on the outside
    # contains two keys: {pagination, $MODEL_NAME}
    # checks the pagination is correct
    # checks the model part is a list of dict
    unittest.assertEqual(response.status_code, 200)

    data = response.data
    unittest.assertIn("pagination", data)
    unittest.assertIn("next", data["pagination"])
    unittest.assertIn("previous", data["pagination"])
    unittest.assertIn("total_results", data["pagination"])
    unittest.assertIn("current_page", data["pagination"])
    unittest.assertIn("total_pages", data["pagination"])
    unittest.assertIn(model_name, data)
