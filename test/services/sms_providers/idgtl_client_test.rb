require "test_helper"
require "minitest/mock"

class IdgtlClientTest < ActiveSupport::TestCase
  test "send_sms returns messageUuid on success" do
    client = SmsProviders::IdgtlClient.new(token_1: "token")

    fake_http = Minitest::Mock.new
    fake_response =
      Struct.new(:code, :body).new(
        "200",
        {
          "errors" => false,
          "items" => [
            { "messageUuid" => "uuid-1", "externalMessageId" => "ext-1", "code" => 201 }
          ]
        }.to_json
      )
    fake_http.expect(:request, fake_response, [Net::HTTP::Post])

    client.stub(:http_for, fake_http) do
      result = client.send_sms!(
        sender_name: "sms_promo",
        destination: "+79991234567",
        content: "hello",
        external_message_id: "ext-1"
      )
      assert_equal true, result[:ok]
      assert_equal "uuid-1", result[:message_uuid]
      assert_equal "ext-1", result[:external_message_id]
    end

    fake_http.verify
  end

  test "get_message returns ok false on 404" do
    client = SmsProviders::IdgtlClient.new(token_1: "token")

    fake_http = Minitest::Mock.new
    fake_response = Struct.new(:code, :body).new("404", { "error" => { "code" => 404, "msg" => "Msg not found" } }.to_json)
    fake_http.expect(:request, fake_response, [Net::HTTP::Get])

    client.stub(:http_for, fake_http) do
      result = client.get_message!(id: "missing")
      assert_equal false, result[:ok]
      assert_equal 404, result[:http_status]
    end

    fake_http.verify
  end
end

