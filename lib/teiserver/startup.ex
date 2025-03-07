defmodule Teiserver.Startup do
  use CentralWeb, :startup
  require Logger

  @spec startup :: :ok
  def startup do
    start_time = System.system_time(:millisecond)

    Teiserver.TeiserverConfigs.teiserver_configs()

    Teiserver.LobbyIdServer.start_lobby_id_server()
    Teiserver.SpringIdServer.start_spring_id_server()

    # Chat stuff
    Central.Account.UserLib.add_report_restriction_types("Chat", [
      "Bridging",
      "Room chat",
      "Direct chat",
      "Lobby chat",
      "Battle chat",
    ])

    # Lobby interaction
    Central.Account.UserLib.add_report_restriction_types("Lobby", [
      "Host commands",
      "Voting",

      "Hosting games",
      "Joining existing lobbies",
      "Low priority",
      "Game queue",
    ])

    Central.Account.UserLib.add_report_restriction_types("Community", [
      "Accolades",
      "Reporting",
      "Renaming"
    ])

    Central.Account.UserLib.add_report_restriction_types("Reminders", [
      "Warning reminder",
    ])

    # Global overrides
    Central.Account.UserLib.add_report_restriction_types("Global", [
      "All chat",
      "All lobbies",
      "Site",
      "Matchmaking",
      "Community",
      "Login"
    ])

    add_audit_types([
      "Teiserver:Updated automod action",
      "Teiserver:Automod action enacted",
      "Teiserver:De-bridged user",
    ])

    add_permission_set("teiserver", "admin", ~w(account battle clan queue))
    add_permission_set("teiserver", "moderator", ~w(account battle clan queue telemetry))
    add_permission_set("teiserver", "api", ~w(battle))
    add_permission_set("teiserver", "player", ~w(account tester contributor dev streamer donor verified bot moderator))

    add_group_type("Teiserver clan", %{fields: []})

    umbrella_group =
      case Central.Account.get_group(nil, search: [name: "Teiserver umbrella group"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "Teiserver umbrella group",
              "active" => true,
              "icon" => "fa-duotone fa-umbrella",
              "colour" => "#00AA66",
              "data" => %{},
              "see_group" => false,
              "see_members" => false,
              "invite_members" => false,
              "self_add_members" => false
            })

          group

        group ->
          group
      end

    player_group =
      case Central.Account.get_group(nil, search: [name: "Teiserver Users"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "Teiserver Users",
              "active" => true,
              "icon" => "fa-duotone fa-robot",
              "colour" => "#00AA00",
              "data" => %{},
              "super_group_id" => umbrella_group.id,
              "see_group" => false,
              "see_members" => false,
              "invite_members" => false,
              "self_add_members" => false
            })

          group

        group ->
          group
      end

    internal_group =
      case Central.Account.get_group(nil, search: [name: "Teiserver Internal Processes"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "Teiserver Internal Processes",
              "active" => true,
              "icon" => "fa-duotone fa-microchip",
              "colour" => "#660066",
              "data" => %{},
              "super_group_id" => umbrella_group.id,
              "see_group" => false,
              "see_members" => false,
              "invite_members" => false,
              "self_add_members" => false
            })

          group

        group ->
          group
      end

    Central.cache_put(:application_metadata_cache, "teiserver_umbrella_group", umbrella_group.id)
    Central.cache_put(:application_metadata_cache, "teiserver_user_group", player_group.id)
    Central.cache_put(:application_metadata_cache, "teiserver_internal_group", internal_group.id)

    Central.Account.GroupCacheLib.update_caches(player_group)
    Central.Account.GroupCacheLib.update_caches(internal_group)
    Central.Account.GroupCacheLib.update_caches(umbrella_group)

    # Quick actions
    QuickAction.add_items([
      # General pages
      %{
        label: "Friends/Mutes/Invites",
        icons: [Teiserver.icon(:relationship), :list],
        url: "/teiserver/account/relationships",
        permissions: "teiserver"
      },
      %{
        label: "Teiserver live metrics",
        icons: ["fa-regular fa-tachometer-alt", :list],
        url: "/teiserver/admin/metrics",
        permissions: "logging.live"
      },
      %{
        label: "Clans",
        icons: [Teiserver.Clans.ClanLib.icon(), :list],
        url: "/teiserver/account/clans",
        permissions: "teiserver"
      },
      %{
        label: "Battles",
        icons: [Teiserver.Battle.LobbyLib.icon(), :list],
        url: "/teiserver/battle/lobbies",
        permissions: "teiserver"
      },

      # Mod pages
      %{
        label: "Clients",
        icons: [Teiserver.ClientLib.icon(), :list],
        url: "/teiserver/admin/client",
        permissions: "teiserver.moderator"
      },
      %{
        label: "Live queues",
        icons: [Teiserver.Game.QueueLib.icon(), :list],
        url: "/teiserver/admin_live/queues",
        permissions: "teiserver.moderator"
      },
      %{
        label: "Teiserver users",
        icons: [Teiserver.ClientLib.icon(), :list],
        input: "s",
        method: "get",
        placeholder: "Search username",
        url: "/teiserver/admin/users/search",
        permissions: "teiserver.moderator"
      },

      # %{label: "Parties", icons: [Teiserver.ClientLib.icon(), :list], url: "/teiserver/admin/parties", permissions: "teiserver.moderator"},
      %{
        label: "Clan admin",
        icons: [Teiserver.Clans.ClanLib.icon(), :list],
        url: "/teiserver/admin/clans",
        permissions: "teiserver.moderator"
      },

      # Admin pages
      %{
        label: "Teiserver dashboard",
        icons: ["fa-regular fa-tachometer-alt", :list],
        url: "/logging/live/dashboard/metrics?nav=teiserver",
        permissions: "logging.live.show"
      },
      %{
        label: "Teiserver client events",
        icons: ["fa-regular #{Teiserver.Telemetry.ClientEventLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      },
      %{
        label: "Teiserver server metrics",
        icons: ["fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      },
      %{
        label: "Teiserver match metrics",
        icons: ["fa-regular #{Teiserver.Battle.MatchLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      },
      %{
        label: "Teiserver infologs",
        icons: ["fa-regular #{Teiserver.Telemetry.InfologLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.moderator.telemetry"
      },
      %{
        label: "Teiserver reports",
        icons: ["fa-regular #{Central.Helpers.StylingHelper.icon(:report)}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      }
    ])

    # User configs
    add_user_config_type(%{
      key: "teiserver.Show flag",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["teiserver"],
      description:
        "When checked the flag associated with your IP will be displayed. If unchecked your flag will be blank. This will take effect next time you login with your client.",
      opts: [],
      default: true
    })

    Central.cache_put(:lists, :clients, [])
    Central.cache_put(:lists, :rooms, [])
    Central.cache_insert_new(:lists, :lobbies, [])

    Teiserver.Data.Matchmaking.pre_cache_queues()

    # Add in achievements
    Teiserver.Game.GenerateAchievementTypes.perform()

    if Application.get_env(:central, Teiserver)[:enable_match_monitor] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Battle.start_match_monitor()
      end)
    end

    if Application.get_env(:central, Teiserver)[:enable_coordinator_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Coordinator.start_coordinator()
        Teiserver.Coordinator.AutomodServer.start_automod_server()
      end)
    end

    if Application.get_env(:central, Teiserver)[:enable_accolade_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Account.AccoladeLib.start_accolade_server()
      end)
    end

    # We want this to start up later than the coordinator
    if Application.get_env(:central, Teiserver)[:enable_agent_mode] do
      spawn(fn ->
        :timer.sleep(650)
        Teiserver.agent_mode()
      end)
    end

    Central.cache_put(:application_metadata_cache, "teiserver_partial_startup_completed", true)
    Central.cache_put(:application_metadata_cache, "teiserver_full_startup_completed", true)

    time_taken = System.system_time(:millisecond) - start_time
    Logger.info("Teiserver startup complete, took #{time_taken}ms")
  end
end
