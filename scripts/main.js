import { world } from "@minecraft/server";

world.beforeEvents.chatSend.subscribe((e) => {
  const player = e.sender;
  const message = e.message;

  if (["!"].includes(message.charAt(0))) return;

  world.sendMessage("You: " + player.nameTag + " say: " + message);

});
