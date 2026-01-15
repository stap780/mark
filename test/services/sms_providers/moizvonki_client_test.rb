require "test_helper"
require "minitest/mock"

class MoizvonkiClientTest < ActiveSupport::TestCase
  test "send_sms posts request_data wrapper" do
    client = SmsProviders::MoizvonkiClient.new(domain: "test", user_name: "u@test", api_key: "k")

    fake_http = Minitest::Mock.new
    fake_response = Struct.new(:code, :body).new("200", { "ok" => true }.to_json)
    fake_http.expect(:request, fake_response) do |req|
      assert_kind_of Net::HTTP::Post, req
      assert_equal "application/json", req["Content-Type"]
      body = JSON.parse(req.body)
      assert body["request_data"].is_a?(String)
      inner = JSON.parse(body["request_data"])
      assert_equal "u@test", inner["user_name"]
      assert_equal "k", inner["api_key"]
      assert_equal "calls.send_sms", inner["action"]
      assert_equal "+79991234567", inner["to"]
      assert_equal "hello", inner["text"]
      true
    end

    client.stub(:http_for, fake_http) do
      res = client.send_sms!(to: "+79991234567", text: "hello")
      assert_equal true, res[:ok]
    end

    fake_http.verify
  end
end

