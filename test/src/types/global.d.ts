import { Howl } from "howler";
import { MessageApi, DialogApi, NotificationApi, LoadingBarApi, ModalApi } from "naive-ui";

type Player = typeof import("@/utils/player").default;

declare global {
  interface Window {
    player?: null | Howl;
    $player?: null | Player;
    // naiveui
    $message: MessageApi;
    $dialog: DialogApi;
    $notification: NotificationApi;
    $loadingBar: LoadingBarApi;
    $modal: ModalApi;
  }
}
