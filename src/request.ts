import { world } from "@minecraft/server";
import { variables } from "@minecraft/server-admin";
import { HttpHeader, HttpRequest, HttpRequestMethod, http } from "@minecraft/server-net";

export const url: String = (variables.get("chat_interact_url") as String | null) ?? "";

const headers = [
    new HttpHeader("Content-Type", "application/json")
];

export const sendPostRequest = (uri: string, body: string) => {
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