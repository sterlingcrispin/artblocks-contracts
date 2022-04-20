import { getPBABBucketName, getBucketURL } from "./format";
const { S3Client, CreateBucketCommand } = require("@aws-sdk/client-s3");

// Docs: https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-s3/index.html

const awsCreds = {
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
};

const s3Client = new S3Client({
  region: "us-east-1",
  credentials: awsCreds,
});

const createBucket = async (bucketName: string, client: any) => {
  const input = {
    Bucket: bucketName,
  };
  const command = new CreateBucketCommand(input);
  return await client.send(command);
};

const createPBABBucket = async (
  pbabTokenName: string,
  networkName: string,
  client: any = s3Client,
  isTest: boolean = false
) => {
  let payload = {};
  payload["response"] = {};
  payload["url"] = "";

  if (
    networkName === "mainnet" ||
    networkName === "ropsten" ||
    isTest === true
  ) {
    const bucketName = getPBABBucketName(pbabTokenName, networkName);
    const bucketURL = getBucketURL(bucketName);
    const bucketResponse = await createBucket(bucketName, client);

    payload["response"] = bucketResponse;
    payload["url"] = bucketURL;
    console.log(`Created s3 bucket for ${bucketURL}`);
  }

  return payload;
};

export { createPBABBucket, createBucket };