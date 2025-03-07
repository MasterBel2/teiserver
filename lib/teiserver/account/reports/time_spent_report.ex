defmodule Teiserver.Account.TimeSpentReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.{Telemetry}
  alias Central.Helpers.TimexHelper
  import Central.Helpers.StringHelper, only: [get_hash_id: 1]

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-watch"

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    data = get_data(params)

    assigns = %{
      params: params,
      presets: DatePresets.presets()
    }

    {data, assigns}
  end

  defp get_data(%{"account_user" => "---"}) do
    []
  end

  defp get_data(params) do
    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    userid = get_hash_id(params["account_user"]) |> to_string

    columns = Telemetry.list_server_day_logs(
      search: [
        start_date: start_date,
        end_date: end_date
      ],
      order: "Oldest first",
      limit: :infinity
    )
      |> Enum.map(fn log ->
        %{
          "key" => log.date,
          "Total" => Map.get(log.data["minutes_per_user"]["total"], userid, 0),
          "Player" => Map.get(log.data["minutes_per_user"]["player"], userid, 0),
          "Spectator" => Map.get(log.data["minutes_per_user"]["spectator"], userid, 0),
          "Lobby" => Map.get(log.data["minutes_per_user"]["lobby"], userid, 0),
          "Menu" => Map.get(log.data["minutes_per_user"]["menu"], userid, 0),
        }
      end)

    lines = ~w(Total Player Spectator Lobby Menu)
      |> Enum.map(fn name -> [name | build_line(columns, name)] end)

    keys = columns
      |> Enum.map(fn %{"key" => key} -> key |> TimexHelper.date_to_str(format: :ymd) end)

    %{
      lines: lines,
      keys: keys
    }
  end

  @spec build_line(list, String.t()) :: list()
  defp build_line(logs, field_name) do
    logs
      |> Enum.map(fn log -> log[field_name] end)
      # |> Enum.map(mapper_function)
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "date_preset" => "This month",
      "start_date" => "",
      "end_date" => "",
      "account_user" => ""
    }, Map.get(params, "report", %{}))
  end
end
