import { Player, world } from "@minecraft/server";
import { sendPostRequest, url } from "./request";

export const chatSubscribe = () => {
    if (url == "") return;
    world.afterEvents.chatSend.subscribe((e) => {
        const player = e.sender;
        const message = e.message;

        if (message.startsWith("!")) {
            handleCommands(player, message);
            return;
        }

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
    try {
        const isTeleported = player.tryTeleport(
            world.getDefaultSpawnLocation(),
            {
                dimension: world.getDimension("overworld"),
                keepVelocity: false
            }
        );
        if (!isTeleported) {
            player.sendMessage(`Cant go home try again`);
        }
    } catch (error) {
        player.sendMessage(`Cant go home because: ${error}`);
    }
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