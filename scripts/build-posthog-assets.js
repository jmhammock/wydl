const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const envPath = path.join(root, ".env");
const configPath = path.join(root, "public", "posthog-config.js");
const sdkPath = path.join(root, "public", "posthog.js");

function readEnv(file) {
  if (!fs.existsSync(file)) {
    return {};
  }

  return fs.readFileSync(file, "utf8").split(/\r?\n/).reduce((env, line) => {
    const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (!match || line.trim().startsWith("#")) {
      return env;
    }

    env[match[1]] = match[2].replace(/^(['"])(.*)\1$/, "$2");
    return env;
  }, {});
}

const env = { ...readEnv(envPath), ...process.env };
const key = env.POSTHOG_KEY;
const host = env.POSTHOG_HOST;

if (key && host) {
  fs.writeFileSync(configPath, `window.POSTHOG_CONFIG = ${JSON.stringify({ key, host })};\n`);
} else if (fs.existsSync(configPath)) {
  fs.unlinkSync(configPath);
}

fs.copyFileSync(require.resolve("posthog-js/dist/array.js"), sdkPath);
