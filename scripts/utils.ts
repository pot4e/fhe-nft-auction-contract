import { config as dotenvConfig } from "dotenv";
import path, { resolve } from "path";
import _ from "lodash";
import fs from 'fs';

// Load environment variables from the .env file
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

// Resolve the path for the configuration file
const configPath = path.resolve('', process.env.CONFIG_PATH || '../config.json');

export const updateConfig = async (key: string, value: string) => {
    // Check if the config file exists
    if (!fs.existsSync(configPath)) {
        // If the file does not exist, create an empty JSON object in the file
        fs.writeFileSync(configPath, JSON.stringify({}, null, 2));
    }

    // Read and parse the configuration file
    const config = JSON.parse(fs.readFileSync(configPath).toString());

    // Update the configuration with the new key-value pair
    _.set(config, key, value);

    // Write the updated configuration back to the file
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
};

export const getConfigValue = (key: string) => {
    // Read and parse the configuration file
    const config = JSON.parse(fs.readFileSync(configPath).toString());

    // Get the value associated with the key
    return _.get(config, key, '');
}
