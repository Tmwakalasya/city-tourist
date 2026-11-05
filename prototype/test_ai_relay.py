import json
import threading
import unittest
import urllib.error
import urllib.request
from unittest.mock import patch

import ai_relay as relay


def payload():
    return {"query": "coffee and pastries", "city": "Lisbon", "candidates": [
        {"id": "known-place", "name": "Test Café", "category": "Food", "area": "Centre",
         "description": "Coffee shop", "tags": ["Cafe"], "rating": 4.5,
         "reviewCount": 150, "distanceMetresFromCentre": 500}]}


def reply():
    return {"summary": "One option to explore.", "picks": [
        {"id": "known-place", "reason": "A café near the centre.", "caveat": "Menu needs checking."}]}


class ContractTests(unittest.TestCase):
    def test_only_public_whitelisted_fields_are_forwarded(self):
        body = payload()
        body["key"] = "private"
        body["trip"] = "private"
        body["candidates"][0]["photoURL"] = "private"
        self.assertNotIn("private", json.dumps(relay.validate_request(body)))

    def test_invalid_requests_are_rejected(self):
        for replacement in ([], "not an object", {**payload(), "query": "x" * 301},
                            {**payload(), "candidates": []},
                            {**payload(), "candidates": payload()["candidates"] * 21}):
            with self.subTest(replacement=str(replacement)[:60]):
                with self.assertRaises(relay.RelayError):
                    relay.validate_request(replacement)

    def test_invented_and_duplicate_ids_are_rejected(self):
        invalid = reply()
        invalid["picks"][0]["id"] = "invented"
        duplicate = reply()
        duplicate["picks"] *= 2
        for body in (invalid, duplicate):
            with self.assertRaises(relay.RelayError) as failure:
                relay.validate_reply(body, payload()["candidates"])
            self.assertEqual(failure.exception.status, 502)

    def test_empty_and_valid_replies_are_supported(self):
        for body in (reply(), {"summary": "No suitable places.", "picks": []}):
            self.assertEqual(relay.validate_reply(body, payload()["candidates"]), body)

    def test_overlong_or_unreadable_replies_are_rejected(self):
        invalid = reply()
        invalid["picks"][0]["reason"] = "x" * 241
        for body in (invalid, [], {"summary": "Missing picks"}):
            with self.assertRaises(relay.RelayError):
                relay.validate_reply(body, payload()["candidates"])

    def test_unknown_ratings_are_not_fabricated(self):
        body = payload()
        del body["candidates"][0]["rating"]
        self.assertIsNone(relay.validate_request(body)["candidates"][0]["rating"])


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.server = relay.Relay(("127.0.0.1", 0), "fake-test-key")
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(self, body, extra_headers=None):
        headers = {"Content-Type": "application/json", "X-Prototype-Client": "city-tourist-simulator"}
        headers.update(extra_headers or {})
        request = urllib.request.Request(
            f"http://127.0.0.1:{self.server.server_port}/api/recommendations",
            data=json.dumps(body).encode(), headers=headers, method="POST")
        try:
            response = urllib.request.urlopen(request, timeout=2)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.status, json.load(response)

    @patch("ai_relay.recommend", return_value=reply())
    def test_a_valid_request_calls_model_once(self, model):
        self.assertEqual(self.request(payload()), (200, reply()))
        self.assertEqual(model.call_count, 1)
        self.assertEqual(self.server.calls, 1)

    @patch("ai_relay.recommend")
    def test_browser_and_wrong_host_requests_do_not_call_model(self, model):
        for headers in ({"Origin": "https://example.test"}, {"X-Prototype-Client": ""},
                        {"Host": "example.test"}):
            self.assertEqual(self.request(payload(), headers)[0], 403)
        model.assert_not_called()

    @patch("ai_relay.recommend")
    def test_budget_stops_calls_before_upstream(self, model):
        self.server.calls = relay.MAX_CALLS
        self.assertEqual(self.request(payload())[0], 429)
        model.assert_not_called()

    @patch("ai_relay.recommend", side_effect=relay.RelayError(504, "Claude didn’t respond in time."))
    def test_provider_failure_is_an_error_not_empty_recommendations(self, model):
        status, body = self.request(payload())
        self.assertEqual(status, 504)
        self.assertIn("message", body)
        self.assertNotIn("picks", body)


if __name__ == "__main__":
    unittest.main()
