import { Player, world } from "@minecraft/server";
import { sendPostRequest, url } from "./request";

export const chatSubscribe = () => {
    world.afterEvents.chatSend.subscribe((e) => {
        const player = e.sender;
        const message = e.message;

        if (message.startsWith("!")) {
            handleCommands(player, message);
            return;
        }

        if (url == "") return;

        const body = {
            player: player.nameTag,
            message: message,
        };
        sendPostRequest("message", JSON.stringify(body));
    });
}

const handleCommands = (player: Player, command: string) => {
    if (command == "!home") {
        return goHomeCommand(player);
    }

    player.sendMessage("Invalid Command");
}

const goHomeCommand = (player: Player) => {

    const spawn = player.getSpawnPoint();
    if (spawn) {
        const { dimension, ...user_location } = spawn;
        player.teleport(user_location, { "dimension": dimension });
        player.sendMessage(`§eYou have been teleported to your spawn point.`);
        return
    }

    const overworld = world.getDimension("overworld")
    const { x, z } = world.getDefaultSpawnLocation()
    const location = overworld.getBlockFromRay(
        { x, y: 400, z },
        { x: 0, y: -1, z: 0 },
        { maxDistance: 500 }
    )?.block.location

    if (location) {
        player.teleport(location, { "dimension": overworld });
        player.sendMessage("§eYou have been teleported to your spawn point.");
        return;
    }
    
    player.sendMessage("§cTeleport to spawnpoint wasn't possible. Try again later.");
}

export const playerEnterToWorldSubscribe = () => {
    if (url == "") return;
    world.afterEvents.playerJoin.subscribe((e) => {
        const body = {
            player: e.playerName
        };
        sendPostRequest("player/enter", JSON.stringify(body));
    });
}

export const playerLeaveToWorldSubscribe = () => {
    if (url == "") return;
    world.afterEvents.playerLeave.subscribe((e) => {
        const body = {
            player: e.playerName
        };
        sendPostRequest("player/leave", JSON.stringify(body));
    });
}