import axios from "axios";
import dotenv from "dotenv";

dotenv.config({ path: "/usr/local/src/controlHumidifier/.env" });

interface AxiosResponseHumidStat {
  statusCode: string;
  body: {
    deviceId: string;
    deviceType: string;
    hubDeviceId: string;
    humidity: number;
    temperature: number;
  };
  message: string;
}

const helloWorld = () => {
  console.log("hello");
  console.log(process.env.DEVICE_ID);
  console.log(process.env.SWITCHBOT_KEY);
  console.log(process.env.IFTTT_API_KEY);
};

const fetchHumid = async (): Promise<number> => {
  const device = process.env.DEVICE_ID;
  const apiKey = process.env.SWITCHBOT_KEY;
  const url = `https://api.switch-bot.com/v1.0/devices/${device}/status`;

  if (!device || !apiKey) throw Error("no device id or api key");

  const config = {
    headers: {
      Authorization: apiKey,
      "Content-Type": "application/json; charset=utf8",
    },
  };

  const result = await axios.get<AxiosResponseHumidStat>(url, config);

  return result.data.body.humidity;
};

const isOverHumid = (humid: number) => {
  const upperBorder = 60;
  return humid >= upperBorder;
};

const isUnderHumid = (humid: number) => {
  const underBorder = 50;
  return humid < underBorder;
};

const controlHumidifier = async (
  action: "turn_on_humidifier" | "turn_off_humidifier"
): Promise<void> => {
  const iftttApiKey = process.env.IFTTT_API_KEY;
  const url = `https://maker.ifttt.com/trigger/${action}/with/key/${iftttApiKey}`;

  if (!iftttApiKey) throw Error("no ifttt api key");

  const result = await axios.post(url);
  if (result.status === 200) {
    console.log("action is completed successfully.");
  } else {
    console.error("somethig went wrong.");
  }

  return;
};

const main = () => {
  return (async () => {
    const humid = await fetchHumid();
    console.log(humid);

    if (!isOverHumid(humid) && !isUnderHumid(humid)) {
      console.log("no action");
      return;
    }

    if (isOverHumid(humid)) {
      await controlHumidifier("turn_off_humidifier");
    }

    if (isUnderHumid(humid)) {
      await controlHumidifier("turn_on_humidifier");
    }
  })().catch((e) => {
    console.error(e);
  });
};

main();
