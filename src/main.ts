import { world } from "@minecraft/server";
import { http, HttpHeader, HttpRequest, HttpRequestMethod } from "@minecraft/server-net";

world.afterEvents.chatSend.subscribe(async (e) => {
    const player = e.sender;
    const message = e.message;

    if (message.startsWith("!")) {
        commandInteract();
        return;
    }

    await sendPlayerMessageEndpoint(player.nameTag, message);
});

const commandInteract = () => { };

const sendPlayerMessageEndpoint = async (playerName: string, message: string) => {

    const body = {
        player: playerName,
        message: message,
    };
    const headers = [
        new HttpHeader("Content-Type", "application/json")
    ];
    const httpRequest = new HttpRequest("http://10.5.0.10:8080/message-chat");
    httpRequest.setMethod(HttpRequestMethod.POST);
    httpRequest.setHeaders(headers);
    httpRequest.setBody(JSON.stringify(body));

    const res = await http.request(httpRequest);
    world.sendMessage("Message sended to endpoint");
};
