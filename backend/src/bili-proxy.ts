import { Elysia, t } from "elysia";
import { cors } from "@elysiajs/cors";
import axios from "axios";
import http from "http";
import https from "https";

const app = new Elysia();
const port = 4056;
const host = "0.0.0.0";

// 创建持久连接的 agent
const httpAgent = new http.Agent({ keepAlive: true });
const httpsAgent = new https.Agent({ keepAlive: true });

app
  .use(cors())
  .get("/", () => "Bilibili Proxy Server is running.")
  .post(
    "/",
    async ({ body, set }) => {
      const { targetUrl, headers, params, method = "get", data } = body as {
        targetUrl?: string;
        headers?: Record<string, string>;
        params?: Record<string, any>;
        method?: string;
        data?: any;
      };

      if (!targetUrl) {
        set.status = 400;
        return { error: "targetUrl is required" };
      }

      console.log(`[Proxy] Request received for: ${targetUrl}`);
      console.log(`[Proxy] Method: ${String(method).toUpperCase()}`);
      if (params) console.log(`[Proxy] Params: ${JSON.stringify(params)}`);
      if (data) console.log(`[Proxy] Data: ${JSON.stringify(data)}`);

      try {
        const response = await axios({
          method: method as any,
          url: targetUrl,
          params,
          data,
          headers,
          httpAgent,
          httpsAgent,
          timeout: 15_000,
        });
        console.log(`[Proxy] Success for ${targetUrl} - Status: ${response.status}`);
        set.status = response.status as any;
        return response.data;
      } catch (error: any) {
        console.error(`[Proxy] Error for ${targetUrl}: ${error.message}`);
        if (error.response) {
          console.error(
            `[Proxy] Upstream error - Status: ${error.response.status}, Data: ${JSON.stringify(error.response.data)}`
          );
          set.status = error.response.status as any;
          return error.response.data;
        }
        set.status = 500;
        return { error: "Proxy internal error", message: error.message };
      }
    },
    {
      body: t.Object({
        targetUrl: t.String(),
        headers: t.Optional(t.Record(t.String(), t.String())),
        params: t.Optional(t.Record(t.String(), t.Any())),
        method: t.Optional(t.String()),
        data: t.Optional(t.Any()),
      }),
    }
  )
  .listen(port, ({ hostname, port }) => {
    console.log(`Bilibili Proxy Server started. Listening at http://${host}:${port}`);
    console.log("This server is intended to be run on a mainland China server.");
    console.log('It accepts POST requests at "/" with body: { targetUrl, headers, params }');
  }); 