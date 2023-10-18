# Event Catcher Addon

A server addon for listen certain events an send to an url.

- For this addon is necessary enable the Experimental API.

## Features

- Can configure the default url
- Listen Player Messages
- Listen !home command to return the spawnpoint
- Listen Player enter/leave

## Variables

Define the required variables in the config/default/variables.json

- `chat_interact_url`: The url where the events were send. (If no set then the events no run)

## Urls

1. `/message/`

   - Sends a POST with the json:
   ```json
    {
        "player": "playerName",
        "message": "message",
    }
   ```
   - If receives any content then show in chat

2. `/player/enter/`

   - Sends  a POST with the json:
   ```json
    {
        "player": "playerName",
    }
   ```

3. `/player/leave/`

   - Sends a POST with the json:
   ```json
    {
        "player": "playerName",
    }
   ```
