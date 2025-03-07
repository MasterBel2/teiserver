defmodule Teiserver.Data.Types do
  # alias Teiserver.Data.Types, as: T
  @type userid() :: non_neg_integer()
  @type lobby_id() :: non_neg_integer()
  @type lobby_guid() :: String.t()
  @type clan_id() :: non_neg_integer
  @type queue_id() :: non_neg_integer

  @type lobby() :: map()
  @type client() :: map()
  @type user() :: map()

  @type spring_tcp_state() :: map()
  @type tachyon_tcp_state() :: map()

  # Central stuff
  @type report() :: Central.Account.Report.t()
end
