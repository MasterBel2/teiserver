Teiserver makes use of the Phoenix pubsub. This document is designed to list the different channels and how they are used.

Anything prefixed with "legacy" is something only present because of the nature of the spring protocol and is going to be removed as soon as we're able to.
Anything prefixed with "teiserver" is something added after the spring protocol was implemented and follows better practices with clearer documentation.

### Server
#### teiserver_server
Used for sending out global messages about server events
```elixir
  {:server_event, :stop, node}
```

#### teiserver_telemetry
Used for broadcasting internal telemetry for consumers (such as admin dashboard)
```elixir
  {:teiserver_telemetry, data}
```

#### teiserver_telemetry_client_events
Used for broadcasting specific client telemetry events as defined in Teiserver.Telemetry. Does not broadcast anonymous events.
```elixir
  {:teiserver_telemetry_client_events, userid, event_type_name, event_value}
```

#### teiserver_telemetry_client_properties
Used for broadcasting specific client telemetry property updates as defined in Teiserver.Telemetry. Does not broadcast anonymous property updates.
```elixir
  {:teiserver_telemetry_client_properties, userid, event_type_name, event_value}
```

### Battles
#### legacy_all_battle_updates
Information affecting all those not in a battle, such as a battle being created.

#### legacy_battle_updates:#{battle_lobby_id}
Information affecting only those in this given battle, such as a player joining.

#### teiserver_global_battle_lobby_updates
Limited information pertaining to the creation/deletion of battle lobbies.
```elixir
  {:global_battle_lobby, :opened, lobby_id}
  {:global_battle_lobby, :closed, lobby_id}
  {:global_battle_lobby, :rename, lobby_id}
```

### teiserver_global_match_updates

```elixir
  {:global_match_updates, :match_completed, match_id}
```

### Lobbies
#### teiserver_lobby_host_message:#{battle_lobby_id}
Messages intended for the host of a given lobby. This saves a call for the client pid and also allows debugging tools to hook into the messages if needed.
Valid events:
```elixir
  # Structure
  {:lobby_host_message, _action, lobby_id, _data}

  # Examples
  {:lobby_host_message, :user_requests_to_join, lobby_id, {userid, script_password}}
```

#### teiserver_lobby_updates:#{battle_lobby_id}
Information affecting only those in this given lobby. Chat is not sent via this channel.
Valid events:
```elixir
  # Structure
  {:lobby_update, _action, lobby_id, _data}

  # BattleLobby
  {:lobby_update, :updated, lobby_id, update_reason}
  {:lobby_update, :closed, lobby_id, reason}
  {:lobby_update, :add_bot, lobby_id, botname}
  {:lobby_update, :update_bot, lobby_id, botname}
  {:lobby_update, :remove_bot, lobby_id, botname}
  {:lobby_update, :add_user, lobby_id, userid}
  {:lobby_update, :remove_user, lobby_id, userid}
  {:lobby_update, :kick_user, lobby_id, userid}

  # Client
  {:lobby_update, :updated_client_battlestatus, lobby_id, {Client, reason}}
```

#### teiserver_lobby_chat:#{battle_lobby_id}
Information specific to the chat in a battle lobby, state changes to the battle are not sent via this channel.
Valid events:
```elixir
  # Structure
  {:lobby_chat, _action, lobby_id, userid, _data}

  # Chatting
  {:lobby_chat, :say, lobby_id, userid, msg}
  {:lobby_chat, :announce, lobby_id, userid, msg}
```

#### teiserver_liveview_lobby_updates:#{battle_lobby_id}
These are updates sent from the LiveBattle genservers (used to throttle/batch messages sent to the liveviews).
```elixir
  # Coordinator
  {:liveview_lobby_update, :consul_server_updated, lobby_id, reason}
```

#### teiserver_liveview_lobby_chat:#{battle_lobby_id}
Updates specifically for liveview chat interfaces, due to the way messages are persisted from matchmonitor server.
```elixir
  # Coordinator
  {:liveview_lobby_chat, :say, lobby_id, reason}
```

### User/Client
#### legacy_all_user_updates
Information about all users, such as a user logging on/off

#### legacy_user_updates:#{userid}
Information about a specific user such as friend related stuff.

#### legacy_all_client_updates
Overlaps with `legacy_all_user_updates` due to blurring of user vs client domain.

#### teiserver_client_inout
A message every time a user logs in or logs out. Unlike legacy all_user_updates it does not give any status updates.
```elixir
  {:client_inout, :login, userid}
  {:client_inout, :disconnect, userid, reason}
```


### teiserver_client_messages:#{userid}
This is the channel for sending messages to the client. It allows the client on the web and lobby application to receive messages.
```elixir
  # Structure
  {:client_message, topic, userid, data}
  
  # Matchmaking
  {:client_message, :matchmaking, userid, {:match_ready, queue_id}}
  {:client_message, :matchmaking, userid, {:join_lobby, queue_id}}

  # Messaging
  {:client_message, :received_direct_message, userid, {from_id, message_content}}
  {:client_message, :lobby_direct_say, userid, {from_id, message_content}}
  {:client_message, :lobby_direct_announce, userid, {from_id, message_content}}

  # Server initiated actions related to the lobby
  {:client_message, :join_lobby_request_response, userid, {lobby_id, response, reason}}
  {:client_message, :force_join_lobby, userid, {lobby_id, script_password}}
```

### teiserver_client_action_updates:#{userid}
Informs about actions performed by a specific client
Aside from connect/disconnect there should always be the structure of `{:client_action, :join_queue, userid, data}`
```elixir
  {:client_action, :client_connect, userid}
  {:client_action, :client_disconnect, userid}

  {:client_action, :join_queue, userid, queue_id}
  {:client_action, :leave_queue, userid, queue_id}

  {:client_action, :join_lobby, userid, lobby_id}
  {:client_action, :leave_lobby, userid, lobby_id}
```

### teiserver_client_application:#{userid}
Designed for lobby applications to display/perform various actions as opposed to internal agent clients or any web interfaces
```elixir
  {:teiserver_client_application, :ring, userid, ringer_id}
```

### teiserver_user_updates:#{userid}
Information pertinent to a specific user
```elixir
  # {:user_update, ?update_type?, userid, ?data?}

  {:user_update, :update_report, user.id, report.id}
```


### Chat
#### room:#{room_name}
All updates about the room and content for the room. Likely to be kept as is and renamed as a teiserver channel due to its nature.

### Matchmaking
#### teiserver_queue_wait:#{queue_id}
Sent from the queue wait server to update regarding it's status
Valid events
```elixir
  {:queue_wait, :queue_add_player, queue_id, userid}
  {:queue_wait, :queue_remove_player, queue_id, userid}
```

#### teiserver_queue_match:#{queue_id}
Sent from the queue match servers
Valid events
```elixir
  {:queue_match, :match_attempt, queue_id, match_id}
  {:queue_match, :match_made, queue_id, lobby_id}
```

#### teiserver_queue_all_queues
Data for those watching all queues at the same time
Valid events
```elixir
  {:queue_periodic_update, queue_id, queue_size, last_wait_time}
```


### Central
#### account_hooks
Used for hooking into account related activities such as updating users.

Valid events
```elixir
  {:account_hooks, :create_user, user, :create}
  {:account_hooks, :update_user, user, :update}

  {:account_hooks, :create_report, report}
  {:account_hooks, :update_report, report, :create | :respond | :update}
```

### Dev mode
agent_updates