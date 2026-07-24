#!/usr/bin/python3

import json
import os
import sys


pid_path = os.environ.get("ACP_TEST_PID_PATH")
if pid_path:
    with open(pid_path, "w", encoding="utf-8") as pid_file:
        pid_file.write(str(os.getpid()))


def send(message):
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


initialize_id = None
echo_requests = []
advanced_client = False
malformed_client_request = os.environ.get("ACP_TEST_MALFORMED_CLIENT_REQUEST") == "1"
restricted_capabilities = os.environ.get("ACP_TEST_RESTRICTED_CAPABILITIES") == "1"
permission_during_prompt = os.environ.get("ACP_TEST_PERMISSION_DURING_PROMPT") == "1"
missing_write_handler_path = os.environ.get("ACP_TEST_MISSING_WRITE_HANDLER_PATH")
full_duplex_initialize = os.environ.get("ACP_TEST_FULL_DUPLEX_INITIALIZE") == "1"
initialize_error = os.environ.get("ACP_TEST_INITIALIZE_ERROR") == "1"
pending_prompt_id = None
session_modes = {
    "currentModeId": "code",
    "availableModes": [
        {"id": "code", "name": "Code"},
        {"id": "review", "name": "Review"},
    ],
}
session_config_options = [{
    "id": "model",
    "name": "Model",
    "category": "model",
    "type": "select",
    "currentValue": "model-1",
    "options": [
        {"value": "model-1", "name": "Model One"},
        {"value": "model-2", "name": "Model Two"},
    ],
}]
client_requests = [
    ("fs/read_text_file", {"sessionId": "session-1", "path": "/tmp/input"}),
    ("fs/write_text_file", {"sessionId": "session-1", "path": "/tmp/output", "content": "done"}),
    ("terminal/create", {"sessionId": "session-1", "command": "/bin/echo", "args": ["hello"], "outputByteLimit": 5}),
    ("terminal/output", {"sessionId": "session-1", "terminalId": "terminal-1"}),
    ("terminal/wait_for_exit", {"sessionId": "session-1", "terminalId": "terminal-1"}),
    ("terminal/kill", {"sessionId": "session-1", "terminalId": "terminal-1"}),
    ("terminal/release", {"sessionId": "session-1", "terminalId": "terminal-1"}),
]


def send_initialize():
    agent_capabilities = {} if restricted_capabilities else {
        "loadSession": True,
        "sessionCapabilities": {
            "list": {},
            "delete": {},
            "resume": {},
            "close": {},
        },
        "auth": {"logout": {}},
    }
    auth_methods = [] if restricted_capabilities else [{"id": "test", "name": "Test"}]
    send({
        "jsonrpc": "2.0",
        "id": initialize_id,
        "result": {
            "protocolVersion": int(os.environ.get("ACP_TEST_PROTOCOL_VERSION", "1")),
            "agentCapabilities": agent_capabilities,
            "authMethods": auth_methods,
        },
    })
    sys.stderr.write("initialized\n")
    sys.stderr.flush()


def send_client_request(index):
    method, params = client_requests[index]
    send({
        "jsonrpc": "2.0",
        "id": f"client-{index}",
        "method": method,
        "params": params,
    })


def send_advanced_prompt_response():
    send({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
            "sessionId": "session-1",
            "update": {
                "sessionUpdate": "plan",
                "entries": [{"content": "replacement", "priority": "high", "status": "completed"}],
            },
        },
    })
    send({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
            "sessionId": "session-1",
            "update": {
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": "Hello from ACP"},
            },
        },
    })
    send({"jsonrpc": "2.0", "id": pending_prompt_id, "result": {"stopReason": "end_turn"}})

for line in sys.stdin:
    message = json.loads(line)
    method = message.get("method")

    if method == "initialize":
        initialize_id = message["id"]
        advanced_client = message["params"].get("clientInfo", {}).get("name") == "swift-acp-tests"
        if initialize_error:
            send({
                "jsonrpc": "2.0",
                "id": initialize_id,
                "error": {"code": -32603, "message": "Initialization failed"},
            })
            continue
        if permission_during_prompt:
            send_initialize()
            continue
        if missing_write_handler_path:
            send({
                "jsonrpc": "2.0",
                "id": "default-write",
                "method": "fs/write_text_file",
                "params": {
                    "sessionId": "session-1",
                    "path": missing_write_handler_path,
                    "content": "created by default callback",
                },
            })
            continue
        if malformed_client_request:
            send({
                "jsonrpc": "2.0",
                "id": "malformed-1",
                "method": "fs/read_text_file",
                "params": {"sessionId": "session-1", "path": 7},
            })
            continue
        if full_duplex_initialize:
            send({
                "jsonrpc": "2.0",
                "method": "session/update",
                "params": {
                    "sessionId": "session-1",
                    "update": {
                        "sessionUpdate": "agent_message_chunk",
                        "content": {"type": "text", "text": "ready"},
                    },
                },
            })
            send({
                "jsonrpc": "2.0",
                "id": "permission-1",
                "method": "session/request_permission",
                "params": {
                    "sessionId": "session-1",
                    "toolCall": {"toolCallId": "tool-1"},
                    "options": [{
                        "optionId": "allow-once",
                        "name": "Allow once",
                        "kind": "allow_once",
                    }],
                },
            })
            continue
        send_initialize()
    elif message.get("id") == "malformed-1":
        error = message.get("error", {})
        if error.get("code") != -32602:
            os.environ["ACP_TEST_PROTOCOL_VERSION"] = "99"
        send_initialize()
    elif message.get("id") == "default-write":
        send_initialize()
    elif message.get("id") == "permission-1":
        if full_duplex_initialize:
            send_initialize()
        else:
            send_client_request(0)
    elif message.get("id") == "prompt-permission":
        outcome = message.get("result", {}).get("outcome", {}).get("outcome")
        send({
            "jsonrpc": "2.0",
            "id": pending_prompt_id,
            "result": {"stopReason": "cancelled" if outcome == "cancelled" else "end_turn"},
        })
    elif str(message.get("id", "")).startswith("client-"):
        if message.get("id") == "client-3":
            result = message.get("result", {})
            if result.get("output") != "bcdef" or result.get("truncated") is not True:
                os.environ["ACP_TEST_PROTOCOL_VERSION"] = "99"
        index = int(message["id"].split("-")[1]) + 1
        if index < len(client_requests):
            send_client_request(index)
        else:
            send_advanced_prompt_response()
    elif method == "echo":
        echo_requests.append(message)
        if len(echo_requests) == 2:
            for request in reversed(echo_requests):
                send({
                    "jsonrpc": "2.0",
                    "id": request["id"],
                    "result": request["params"],
                })
            echo_requests.clear()
    elif method == "session/new":
        send({
            "jsonrpc": "2.0",
            "id": message["id"],
            "result": {
                "sessionId": "session-1",
                "modes": session_modes,
                "configOptions": session_config_options,
            },
        })
    elif method == "authenticate" or method == "logout":
        send({"jsonrpc": "2.0", "id": message["id"], "result": {}})
    elif method == "session/set_config_option":
        selected = message["params"]["value"]
        send({
            "jsonrpc": "2.0",
            "id": message["id"],
            "result": {
                "configOptions": [{
                    "id": "model",
                    "name": "Model",
                    "category": "model",
                    "type": "select",
                    "currentValue": selected,
                    "options": [
                        {"value": "model-1", "name": "Model One"},
                        {"value": "model-2", "name": "Model Two"},
                    ],
                }],
            },
        })
    elif method == "session/prompt":
        if permission_during_prompt:
            pending_prompt_id = message["id"]
            send({
                "jsonrpc": "2.0",
                "id": "prompt-permission",
                "method": "session/request_permission",
                "params": {
                    "sessionId": message["params"]["sessionId"],
                    "toolCall": {"toolCallId": "prompt-tool"},
                    "options": [{
                        "optionId": "allow-once",
                        "name": "Allow once",
                        "kind": "allow_once",
                    }],
                },
            })
            continue
        if advanced_client:
            pending_prompt_id = message["id"]
            send({
                "jsonrpc": "2.0",
                "id": "permission-1",
                "method": "session/request_permission",
                "params": {
                    "sessionId": message["params"]["sessionId"],
                    "toolCall": {"toolCallId": "tool-1"},
                    "options": [{
                        "optionId": "allow-once",
                        "name": "Allow once",
                        "kind": "allow_once",
                    }],
                },
            })
            continue
        send({
            "jsonrpc": "2.0",
            "method": "session/update",
            "params": {
                "sessionId": message["params"]["sessionId"],
                "update": {
                    "sessionUpdate": "plan",
                    "entries": [{"content": "first", "priority": "medium", "status": "pending"}],
                },
            },
        })
        send({
            "jsonrpc": "2.0",
            "method": "session/update",
            "params": {
                "sessionId": message["params"]["sessionId"],
                "update": {
                    "sessionUpdate": "plan",
                    "entries": [{"content": "replacement", "priority": "high", "status": "completed"}],
                },
            },
        })
        send({
            "jsonrpc": "2.0",
            "method": "session/update",
            "params": {
                "sessionId": message["params"]["sessionId"],
                "update": {
                    "sessionUpdate": "agent_message_chunk",
                    "messageId": "message-1",
                    "content": {"type": "text", "text": "Hello from ACP"},
                },
            },
        })
        send({
            "jsonrpc": "2.0",
            "id": message["id"],
            "result": {"stopReason": "end_turn"},
        })
    elif method == "session/load":
        send({
            "jsonrpc": "2.0",
            "method": "session/update",
            "params": {
                "sessionId": message["params"]["sessionId"],
                "update": {
                    "sessionUpdate": "user_message_chunk",
                    "messageId": "history-1",
                    "content": {"type": "text", "text": "Previous prompt"},
                },
            },
        })
        send({
            "jsonrpc": "2.0",
            "id": message["id"],
            "result": {
                "modes": session_modes,
                "configOptions": session_config_options,
            },
        })
    elif method == "session/resume":
        send({
            "jsonrpc": "2.0",
            "id": message["id"],
            "result": {
                "modes": session_modes,
                "configOptions": session_config_options,
            },
        })
    elif method == "session/list":
        send({
            "jsonrpc": "2.0",
            "id": message["id"],
            "result": {
                "sessions": [{"sessionId": "session-1", "cwd": "/tmp"}],
                "nextCursor": "next",
            },
        })
    elif method == "session/set_mode" or method == "session/delete" or method == "session/close":
        send({"jsonrpc": "2.0", "id": message["id"], "result": {}})
    elif method == "exit":
        sys.exit(7)
    elif method == "blank_line":
        sys.stdout.write("\n")
        sys.stdout.flush()
        send({"jsonrpc": "2.0", "id": message["id"], "result": {}})
