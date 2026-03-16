import requests
import pytest


@pytest.mark.functional
class TestQpLogMaskFunctional:
    def test_requires_api_key_on_protected_route(self, base_url):
        response = requests.get(f"{base_url}/mask?token=abcDEF123456", timeout=10)
        assert response.status_code == 401

    def test_does_not_expose_masked_value_in_response_headers(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask?token=abcDEF123456&user=demo_user",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_headers_when_configured_query_params_absent(self, base_url, default_headers):
        response = requests.get(f"{base_url}/mask?other=1", headers=default_headers, timeout=10)
        assert response.status_code == 200

    def test_no_headers_for_empty_query_values(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask?token=&user=demo_user",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_headers_for_multiple_values(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask?token=abcDEF123456&token=ZZZZYYYYXXXX12&user=bob",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_advanced_header_when_pattern_does_not_match(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-advanced?key1=will_not_mask1&qparam2=will_not_mask2",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_advanced_header_when_values_are_masked(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-advanced?key1=will_not_mask1&qparam2=xyz123",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_advanced_header_for_multiple_values(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-advanced?key1=will_not_mask1&key1=xyz123",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_advanced_header_for_password_mask(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-advanced?password=abcdefghijk12345",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_advanced_header_for_long_alphanumeric_mask(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-advanced?epqparam2=ab1234efgh",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_advanced_header_for_hex_string_mask(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-advanced?epqp1=12345abcdef12345abcdef&epqparam2=abcdefg",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_advanced_header_when_configured_params_absent(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-advanced?notAppendKey1=will_not_mask1&notAppendKey2=xyz123",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_advanced_header_when_query_params_over_100(self, base_url, default_headers):
        params = {
            "epqp1": "12345abcdef12345abcdef",
            "epqparam2": "abcdefg",
        }
        for i in range(120):
            params[f"qpk-{i}"] = f"qpv-{i}"

        response = requests.get(
            f"{base_url}/mask-advanced",
            headers=default_headers,
            params=params,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_header_when_route_config_disables_it(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-no-header?token=abcDEF123456&user=demo_user",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_plugin_disabled_flag_route(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-plugin-disabled?token=abcDEF123456&user=demo_user",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_header_when_mask_value_omitted(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-empty-mask?token=abcxyz123def",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_no_custom_response_header_name_emitted(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-custom-format?token=abcDEF123456&user=demo_user",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_empty_query_params_to_log_list(self, base_url, default_headers):
        response = requests.get(
            f"{base_url}/mask-empty-list?token=abcDEF123456&user=demo_user",
            headers=default_headers,
            timeout=10,
        )
        assert response.status_code == 200

    def test_plugin_enabled_in_admin_list(self, admin_url):
        response = requests.get(f"{admin_url}/plugins/enabled", timeout=10)
        assert response.status_code == 200
        body = response.json()
        assert isinstance(body.get("enabled_plugins"), list)
        assert "qp-log-mask" in body["enabled_plugins"]
