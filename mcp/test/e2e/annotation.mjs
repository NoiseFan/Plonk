import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const [kind, directory] = process.argv.slice(2);
const input = join(directory, "source.png");
const output = join(directory, "marked.png");
const client = new Client({ name: "plonk-shot-e2e", version: "1" });
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [fileURLToPath(new URL("../../dist/server.js", import.meta.url))],
});
try {
  await client.connect(transport);
  const capture = await client.callTool({
    name: "take_screenshot",
    arguments: { mode: "screen", path: input, clipboard: false, include_image: false },
  });
  if (capture.isError) throw new Error(JSON.stringify(capture.content));
  const marks = kind === "line"
    ? [{ kind, points: [{ x: 0.3, y: 0.4 }, { x: 0.7, y: 0.6 }], color: "red", width: 0.025 }]
    : [{ kind, points: [{ x: 0.35, y: 0.35 }, { x: 0.55, y: 0.65 }] },
        { kind, points: [{ x: 0.45, y: 0.35 }, { x: 0.65, y: 0.65 }] }];
  const annotation = await client.callTool({
    name: "annotate_screenshot",
    arguments: { path: input, output, marks, clipboard: false },
  });
  if (annotation.isError) throw new Error(JSON.stringify(annotation.content));
} finally {
  await client.close();
}
