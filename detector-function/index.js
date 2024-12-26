const functions = require('@google-cloud/functions-framework');
const {PubSub} = require('@google-cloud/pubsub');
const redis = require('redis');

const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = process.env.REDIS_PORT || 6379;
const REDIS_DATABASE = process.env.REDIS_DATABASE || 0;
const NOT_FOUND_REQUEST_WINDOW = process.env.NOT_FOUND_REQUEST_WINDOW;
const NOT_FOUND_REQUEST_LIMIT = process.env.NOT_FOUND_REQUEST_LIMIT;
const ATTACK_PUBSUB_PROJECT = process.env.ATTACK_PUBSUB_PROJECT;
const ATTACK_PUBSUB_TOPIC = process.env.ATTACK_PUBSUB_TOPIC;

const redisClient = redis.createClient({
    socket: {
        host: REDIS_HOST,
        port: REDIS_PORT,
    },
});
redisClient.on('error', err => console.error('ERR:REDIS:', err));
redisClient.connect();
redisClient.select(REDIS_DATABASE)

functions.cloudEvent('detectScanAttack', async (cloudEvent) => {
    const data = cloudEvent.data.message.data ? Buffer.from(cloudEvent.data.message.data, 'base64').toString() : '';
    const json = JSON.parse(data);

    const fromIp = json.protoPayload.ip || json.httpRequest.remoteIp || '';
    const resource = json.protoPayload.resource || json.httpRequest.requestUrl || '';

    // random key prefixed by "ip:"
    const key = 'sad:' + json.protoPayload.ip + ':' + Math.random().toString(36).substring(7);

    // set the key with an expiration time in seconds (TTL)
    await redisClient.set(key, resource, 'EX', NOT_FOUND_REQUEST_WINDOW);

    console.log(`Register not found request from ${fromIp} to ${resource}`);

    // count the number of keys with the same prefix
    const count = await redisClient.keys('sad:' + fromIp + ':*');

    // if the count is greater than the limit, publish a message to the Pub/Sub topic
    if (count.length >= NOT_FOUND_REQUEST_LIMIT) {
        console.log(`The number of not found requests from ${fromIp} is greater than ${NOT_FOUND_REQUEST_LIMIT} in a window of ${NOT_FOUND_REQUEST_WINDOW} seconds.`);

        const pubsub = new PubSub({
            projectId: ATTACK_PUBSUB_PROJECT,
        });

        const attacksTopic = pubsub.topic(ATTACK_PUBSUB_TOPIC);

        // publish a new attack message
        const messageId = await attacksTopic.publish(Buffer.from(JSON.stringify({
            ip: fromIp,
            count: count.length,
        })));

        console.log(`Published attack with message id ${messageId}.`);
    }

    return null;
});
