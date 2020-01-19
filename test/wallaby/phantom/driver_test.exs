defmodule Wallaby.Phantom.DriverTest do
  use Wallaby.HttpClientCase, async: true

  alias Wallaby.{Element, Phantom, Query, Session, StaleReferenceError}
  alias Wallaby.Phantom.Driver

  @window_handle_id "bdc333b0-1989-11e7-a2c3-d1d2d92b0e58"

  describe "create/2" do
    test "sends the the correct request", %{bypass: bypass} do
      base_url = bypass_url(bypass, "/")
      new_session_id = "abc123"
      sample_pid = self()

      Bypass.expect_once(bypass, "POST", "/session", fn conn ->
        conn = parse_body(conn)
        assert %{"desiredCapabilities" => %{"browserName" => "phantomjs"}} = conn.body_params

        send_json_resp(conn, 200, %{
          "sessionId" => new_session_id,
          "status" => 0,
          "value" => %{
            "acceptSslCerts" => false,
            "browserName" => "phantomjs"
          }
        })
      end)

      expected_session_url = base_url |> URI.merge("/session/#{new_session_id}") |> to_string()

      assert {:ok,
              %Session{
                driver: Wallaby.Phantom,
                id: ^new_session_id,
                server: ^sample_pid,
                session_url: ^expected_session_url,
                url: ^expected_session_url
              }} = Driver.create(sample_pid, base_url: base_url)
    end

    test "raises when the server is down", %{bypass: bypass} do
      base_url = bypass_url(bypass, "/")
      sample_pid = self()

      Bypass.down(bypass)

      assert_raise RuntimeError, ~r/internal issue/i, fn ->
        Driver.create(sample_pid, base_url: base_url)
      end
    end
  end

  describe "delete/1" do
    test "sends a delete request to Session.session_url", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)

      Bypass.expect(bypass, "DELETE", "/session/#{session.id}", fn conn ->
        send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": {}
          }>)
      end)

      assert {:ok, response} = Driver.delete(session)

      assert response == %{
               "sessionId" => session.id,
               "status" => 0,
               "value" => %{}
             }
    end
  end

  describe "find_elements/2" do
    test "with a Session as the parent", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element_id = ":wdc:1491326583887"
      query = ".blue" |> Query.css() |> Query.compile()

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("POST", "/session/#{session.id}/elements", fn conn ->
        conn = parse_body(conn)
        assert conn.body_params == %{"using" => "css selector", "value" => ".blue"}

        send_json_resp(conn, 200, ~s<{
              "sessionId": "#{session.id}",
              "status": 0,
              "value": [{"ELEMENT": "#{element_id}"}]
            }>)
      end)

      assert {:ok, [element]} = Driver.find_elements(session, query)

      assert element == %Element{
               driver: Phantom,
               id: element_id,
               parent: session,
               session_url: session.url,
               url: "#{session.url}/element/#{element_id}"
             }
    end

    test "with an Element as the parent", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      parent_element = build_element_for_session(session)
      element_id = ":wdc:1491326583887"
      query = ".blue" |> Query.css() |> Query.compile()

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "POST",
        "/session/#{session.id}/element/#{parent_element.id}/elements",
        fn conn ->
          conn = parse_body(conn)

          assert conn.body_params == %{"using" => "css selector", "value" => ".blue"}

          send_json_resp(conn, 200, ~s<{
          "sessionId": "#{session.id}",
          "status": 0,
          "value": [{"ELEMENT": "#{element_id}"}]
      }>)
        end
      )

      assert {:ok, [element]} = Driver.find_elements(parent_element, query)

      assert element == %Element{
               driver: Phantom,
               id: element_id,
               parent: parent_element,
               session_url: session.url,
               url: "#{session.url}/element/#{element_id}"
             }
    end
  end

  describe "set_value/2" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)
      value = "hello world"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "POST",
        "/session/#{session.id}/element/#{element.id}/value",
        fn conn ->
          conn = parse_body(conn)
          assert conn.body_params == %{"value" => [value]}

          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": null
          }>)
        end
      )

      assert {:ok, nil} = Driver.set_value(element, value)
    end
  end

  describe "clear/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "POST",
        "/session/#{session.id}/element/#{element.id}/clear",
        fn conn ->
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": null
          }>)
        end
      )

      assert {:ok, nil} = Driver.clear(element)
    end
  end

  describe "click/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "POST",
        "/session/#{session.id}/element/#{element.id}/click",
        fn conn ->
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": {}
          }>)
        end
      )

      assert {:ok, %{}} = Driver.click(element)
    end
  end

  describe "text/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "GET",
        "/session/#{session.id}/element/#{element.id}/text",
        fn conn ->
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": ""
          }>)
        end
      )

      assert {:ok, ""} = Driver.text(element)
    end
  end

  describe "page_title/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      page_title = "Wallaby rocks"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "GET",
        "/session/#{session.id}/title",
        fn conn ->
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": "#{page_title}"
          }>)
        end
      )

      assert {:ok, ^page_title} = Driver.page_title(session)
    end
  end

  describe "attribute/2" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)
      attribute_name = "name"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "GET",
        "/session/#{session.id}/element/#{element.id}/attribute/#{attribute_name}",
        fn conn ->
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": "password"
          }>)
        end
      )

      assert {:ok, "password"} = Driver.attribute(element, "name")
    end
  end

  describe "visit/2" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      url = "http://www.google.com"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "POST",
        "/session/#{session.id}/url",
        fn conn ->
          conn = parse_body(conn)
          assert conn.body_params == %{"url" => url}

          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": {}
          }>)
        end
      )

      assert :ok = Driver.visit(session, url)
    end

    test "when browser sends back a 204 response", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      url = "http://www.google.com"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "POST",
        "/session/#{session.id}/url",
        fn conn ->
          conn = parse_body(conn)
          assert conn.body_params == %{"url" => url}

          send_resp(conn, 204, "")
        end
      )

      assert :ok = Driver.visit(session, url)
    end
  end

  describe "current_url/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      url = "http://www.google.com"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "GET",
        "/session/#{session.id}/url",
        fn conn ->
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": "#{url}"
          }>)
        end
      )

      assert {:ok, ^url} = Driver.current_url(session)
    end
  end

  describe "current_path/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      url = "http://www.google.com/search"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "GET",
        "/session/#{session.id}/url",
        fn conn ->
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": "#{url}"
          }>)
        end
      )

      assert {:ok, "/search"} = Driver.current_path(session)
    end
  end

  describe "selected/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "GET",
        "/session/#{session.id}/element/#{element.id}/selected",
        fn conn ->
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": true
          }>)
        end
      )

      assert {:ok, true} = Driver.selected(element)
    end
  end

  describe "displayed/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "GET",
        "/session/#{session.id}/element/#{element.id}/displayed",
        fn conn ->
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": true
          }>)
        end
      )

      assert {:ok, true} = Driver.displayed(element)
    end

    test "with a stale reference exception", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("GET", "/session/#{session.id}/element/#{element.id}/displayed", fn conn ->
        send_json_resp(conn, 500, ~s<{
            "sessionId": "#{session.id}",
            "status": 10,
            "value": {
              "class": "org.openqa.selenium.StaleElementReferenceException"
            }
          }>)
      end)

      assert {:error, :stale_reference} = Driver.displayed(element)
    end
  end

  describe "displayed!/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("GET", "/session/#{session.id}/element/#{element.id}/displayed", fn conn ->
        send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": true
          }>)
      end)

      assert true = Driver.displayed!(element)
    end

    test "with a stale reference exception", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("GET", "/session/#{session.id}/element/#{element.id}/displayed", fn conn ->
        send_json_resp(conn, 500, ~s<{
            "sessionId": "#{session.id}",
            "status": 10,
            "value": {
              "class": "org.openqa.selenium.StaleElementReferenceException"
            }
          }>)
      end)

      assert_raise StaleReferenceError, fn ->
        Driver.displayed!(element)
      end
    end
  end

  describe "size/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("GET", "/session/#{session.id}/element/#{element.id}/size", fn conn ->
        send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": "not quite sure"
          }>)
      end)

      assert {:ok, "not quite sure"} = Driver.size(element)
    end
  end

  describe "rect/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("GET", "/session/#{session.id}/element/#{element.id}/rect", fn conn ->
        send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": "not quite sure"
          }>)
      end)

      assert {:ok, "not quite sure"} = Driver.rect(element)
    end
  end

  describe "take_screenshot/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      screenshot_data = ":)"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("GET", "/session/#{session.id}/screenshot", fn conn ->
        send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": "#{Base.encode64(screenshot_data)}"
          }>)
      end)

      assert ^screenshot_data = Driver.take_screenshot(session)
    end
  end

  describe "cookies/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("GET", "/session/#{session.id}/cookie", fn conn ->
        send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": [{"domain": "localhost"}]
          }>)
      end)

      assert {:ok, [%{"domain" => "localhost"}]} = Driver.cookies(session)
    end
  end

  describe "set_cookie/3" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      key = "tester"
      value = "McTestington"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("POST", "/session/#{session.id}/cookie", fn conn ->
        conn = parse_body(conn)
        assert conn.body_params == %{"cookie" => %{"name" => key, "value" => value}}

        send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": []
          }>)
      end)

      assert {:ok, []} = Driver.set_cookie(session, key, value)
    end
  end

  describe "set_window_size/3" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      height = 600
      width = 400

      bypass
      |> expect_fetch_logs_request(session)
      |> expect_get_window_handle_request(session)
      |> Bypass.expect(
        "POST",
        "/session/#{session.id}/window/#{@window_handle_id}/size",
        fn conn ->
          conn = parse_body(conn)
          assert conn.body_params == %{"height" => height, "width" => width}

          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": {}
          }>)
        end
      )

      assert {:ok, %{}} = Driver.set_window_size(session, width, height)
    end
  end

  describe "get_window_size/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)

      bypass
      |> expect_fetch_logs_request(session)
      |> expect_get_window_handle_request(session)
      |> Bypass.expect(
        "GET",
        "/session/#{session.id}/window/#{@window_handle_id}/size",
        fn conn ->
          conn = parse_body(conn)
          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": {
              "height": 600,
              "width": 400
            }
          }>)
        end
      )

      assert {:ok, %{}} = Driver.get_window_size(session)
    end
  end

  describe "execute_script/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "POST",
        "/session/#{session.id}/execute",
        fn conn ->
          conn = parse_body(conn)
          assert conn.body_params == %{"script" => "localStorage.clear()", "args" => [2, "a"]}

          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": null
          }>)
        end
      )

      assert {:ok, nil} = Driver.execute_script(session, "localStorage.clear()", [2, "a"])
    end
  end

  describe "send_keys/2" do
    test "with a Session", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      keys = ["abc", :tab]

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect(
        "POST",
        "/session/#{session.id}/keys",
        fn conn ->
          conn = parse_body(conn)
          assert conn.body_params == Wallaby.Helpers.KeyCodes.json(keys) |> Jason.decode!()

          send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": null
          }>)
        end
      )

      assert {:ok, nil} = Driver.send_keys(session, keys)
    end

    test "with an Element", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      element = build_element_for_session(session)
      keys = ["abc", :tab]

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("POST", "/session/#{session.id}/element/#{element.id}/value", fn conn ->
        conn = parse_body(conn)
        assert conn.body_params == Wallaby.Helpers.KeyCodes.json(keys) |> Jason.decode!()

        send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": null
          }>)
      end)

      assert {:ok, nil} = Driver.send_keys(element, keys)
    end
  end

  describe "log/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)

      Bypass.expect(bypass, "POST", "/session/#{session.id}/log", fn conn ->
        conn = parse_body(conn)
        assert conn.body_params == %{"type" => "browser"}

        send_json_resp(conn, 200, ~s<{
          "sessionId": "#{session.id}",
          "status": 0,
          "value": []
        }>)
      end)

      assert {:ok, []} = Driver.log(session)
    end
  end

  describe "page_source/1" do
    test "sends the correct request to the server", %{bypass: bypass} do
      session = build_session_for_bypass(bypass)
      page_source = "<html></html>"

      bypass
      |> expect_fetch_logs_request(session)
      |> Bypass.expect("GET", "/session/#{session.id}/source", fn conn ->
        send_json_resp(conn, 200, ~s<{
            "sessionId": "#{session.id}",
            "status": 0,
            "value": "#{page_source}"
          }>)
      end)

      assert {:ok, ^page_source} = Driver.page_source(session)
    end
  end

  defp build_session_for_bypass(bypass, session_id \\ "my-sample-session") do
    session_url = bypass_url(bypass, "/session/#{session_id}")

    %Session{driver: Phantom, id: session_id, session_url: session_url, url: session_url}
  end

  defp build_element_for_session(session, element_id \\ ":wdc:abc123") do
    %Element{
      driver: Phantom,
      id: element_id,
      parent: session,
      session_url: session.url,
      url: "#{session.url}/element/#{element_id}"
    }
  end

  defp expect_get_window_handle_request(bypass, session) do
    Bypass.expect(bypass, "GET", "/session/#{session.id}/window_handle", fn conn ->
      send_json_resp(conn, 200, ~s<{
        "sessionId": "#{session.id}",
        "status": 0,
        "value": "#{@window_handle_id}"
    }>)
    end)

    bypass
  end

  defp expect_fetch_logs_request(bypass, session) do
    Bypass.expect(bypass, "POST", "/session/#{session.id}/log", fn conn ->
      send_json_resp(conn, 200, ~s<{
        "sessionId": "#{session.id}",
        "status": 0,
        "value": []
    }>)
    end)

    bypass
  end
end
