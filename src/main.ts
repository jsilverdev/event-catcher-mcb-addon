import { world } from "@minecraft/server";
import { variables } from "@minecraft/server-admin";
import { http, HttpHeader, HttpRequest, HttpRequestMethod } from "@minecraft/server-net";


const defaultUrl: String = "http://127.0.0.1:8080";
let url: String = (variables.get("chat_interact_url") as String | null) ?? defaultUrl;
if (url == "") {
    url = defaultUrl;
}

const headers = [
    new HttpHeader("Content-Type", "application/json")
];

world.afterEvents.chatSend.subscribe((e) => {
    const player = e.sender;
    const message = e.message;

    if (message.startsWith("!")) {
        return;
    }

    sendPlayerMessageEndpoint(player.nameTag, message);
});

const sendPlayerMessageEndpoint = (playerName: string, message: string) => {
    const body = {
        player: playerName,
        message: message,
    };
    sendPostRequest("message", JSON.stringify(body));
};

const sendPostRequest = (uri: string, body: string) => {
    const httpRequest = new HttpRequest(`${url}/${uri}/`);
    httpRequest.headers = headers;
    httpRequest.method = HttpRequestMethod.Post;
    httpRequest.body = body;
    http.request(httpRequest).then(
        (res) => {
            if (res.body.length > 0) {
                world.sendMessage(res.body);
            }
        }
    );
}