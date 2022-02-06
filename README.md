# スマートホーム非対応の加湿器をなんとかしてスマートホーム化する

## 使ったもの

- Meross MSS425FJP [link](https://www.amazon.co.jp/dp/B07Q9S2629/ref=cm_sw_r_tw_dp_dl_2B8D1PNQ640HJX44NW40)
- Yokizu 加湿器 [link](https://www.amazon.co.jp/dp/B08BYB3W2V/ref=cm_sw_r_tw_dp_4F828RAJKB3JHNBPWBME)
- SwitchBot 温湿度計 [link](https://www.amazon.co.jp/dp/B07L4QNZVF/ref=cm_sw_r_tw_dp_dl_6PKVKJET86GHZMY4HR1S?_encoding=UTF8&psc=1)
- SwitchBot Hub mini [link](https://www.amazon.co.jp/dp/B07TTH5TMW/ref=cm_sw_r_tw_dp_dl_PZ84H0G5ZV1ECBMBAJN0)

- IFTTT

---

## 準備

### .env ファイルの作成

```env
SWITCHBOT_KEY="YOUR SWITCH BOT API KEY"
DEVICE_ID="YOUR SWITCH BOT METER DEVICE ID"
IFTTT_API_KEY="YOUR IFTTT WEBHOOK TOKEN"
```


## 仕様

実行すると `.env` で指定した `SWITCHBOT_KEY` を使って Switch Bot 社の API を実行します。 `DEVICE_ID` を持つ温湿度計の湿度を取得します。

湿度が しきい値を超えている場合、 上限を超えた、下限を下回った場合に対応したアクションで IFTTT Web Hook を実行します。

定期実行する場合はこのスクリプトを cron 等スケジュール実行サービスで起動してください。

### IFTTT Web Hook で 受け付けるイベント名

- `turn_off_humidifer` ... 加湿器が接続されている電源プラグを OFF にする
- `turn_on_humidifier`  ... 加湿器が接続されている電源プラグを ON にする


### 加湿器のオン・オフのしきい値を変更する

`isOverHumid` または `isUnderHumid` 内の `border` を変更すると上限・下限を変更できます。
