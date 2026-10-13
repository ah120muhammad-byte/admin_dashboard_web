import { AwsClient } from "aws4fetch";

interface Env {
  R2_BUCKET: R2Bucket;
  R2_ACCOUNT_ID: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_BUCKET_NAME: string;
  R2_ENDPOINT?: string;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  ALLOWED_ADMIN_USER_IDS?: string;
}

interface AuthUser {
  id: string;
  email?: string;
  [key: string]: unknown;
}
interface InitiateBody {
  lecture_id: string;
  filename: string;
  content_type?: string;
  file_size: number;
}
interface PartUrlBody { key: string; upload_id: string; part_number: number }
interface CompleteBody {
  key: string;
  upload_id: string;
  parts: Array<{ part_number: number; etag: string }>;
}
interface AbortBody { key: string; upload_id: string }
interface SignedUrlBody { key: string }

const PART_SIZE = 64 * 1024 * 1024;
const MAX_UPLOAD_BYTES = 5_000_000_000_000;
const ALLOWED_EXTENSIONS = new Set([".mp4", ".mov", ".m4v", ".webm", ".avi", ".mkv"]);

class ApiError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
    this.name = "ApiError";
  }
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD",
  "Access-Control-Allow-Headers": "Authorization, Content-Type, Accept, Origin, X-Requested-With",
  "Access-Control-Expose-Headers": "ETag, Content-Length, Content-Type",
  "Access-Control-Max-Age": "86400",
};

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(CORS_HEADERS)) headers.set(name, value);
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}
function json(data: unknown, status = 200): Response {
  return withCors(Response.json(data, { status }));
}
function requireValue(value: unknown, name: string): string {
  const result = typeof value === "string" ? value.trim() : "";
  if (!result) throw new ApiError(400, name + " is required");
  return result;
}
async function readJson<T>(request: Request): Promise<T> {
  try { return await request.json() as T; }
  catch { throw new ApiError(400, "Request body must be valid JSON"); }
}
function getR2Endpoint(env: Env): string {
  const endpoint = env.R2_ENDPOINT?.trim() || (env.R2_ACCOUNT_ID?.trim()
    ? "https://" + env.R2_ACCOUNT_ID.trim() + ".r2.cloudflarestorage.com" : "");
  if (!endpoint) throw new ApiError(500, "R2_ACCOUNT_ID or R2_ENDPOINT is not configured");
  return endpoint.replace(/\/+$/, "");
}
function getR2Signer(env: Env): AwsClient {
  const accessKeyId = env.R2_ACCESS_KEY_ID?.trim();
  const secretAccessKey = env.R2_SECRET_ACCESS_KEY?.trim();
  if (!accessKeyId || !secretAccessKey) throw new ApiError(500, "R2 signing credentials are not configured");
  return new AwsClient({ accessKeyId, secretAccessKey, service: "s3", region: "auto" });
}
function encodeKey(key: string): string {
  return key.split("/").map((segment) => encodeURIComponent(segment)).join("/");
}
function validateLectureKey(raw: unknown): string {
  const key = requireValue(raw, "key");
  if (!key.startsWith("lectures/") || key.includes("..") || key.includes("\\") || key.includes("//")) {
    throw new ApiError(403, "Invalid R2 object key");
  }
  return key;
}
function safeFilename(raw: string): string {
  const leaf = raw.split(/[\\/]/).pop() || "video.mp4";
  const safe = leaf.replace(/[^A-Za-z0-9._ -]+/g, "_").trim().replace(/\s+/g, "_");
  return (safe || "video.mp4").slice(0, 180);
}
function buildObjectKey(lectureId: string, filename: string): string {
  const lecture = lectureId.replace(/[^A-Za-z0-9_-]+/g, "_").slice(0, 160) || "lecture";
  return "lectures/" + lecture + "/" + crypto.randomUUID().replace(/-/g, "") + "_" + safeFilename(filename);
}
function contentTypeForFilename(name: string, provided?: string): string {
  const extension = name.includes(".") ? "." + name.split(".").pop()!.toLowerCase() : "";
  if (!ALLOWED_EXTENSIONS.has(extension)) throw new ApiError(400, "Unsupported video type");
  const known: Record<string, string> = {
    ".mp4": "video/mp4", ".mov": "video/quicktime", ".m4v": "video/x-m4v",
    ".webm": "video/webm", ".avi": "video/x-msvideo", ".mkv": "video/x-matroska",
  };
  return provided?.trim() || known[extension] || "video/mp4";
}

async function getCurrentUser(request: Request, env: Env): Promise<AuthUser> {
  const authorization = request.headers.get("Authorization") || "";
  if (!authorization.toLowerCase().startsWith("bearer ")) throw new ApiError(401, "Missing Supabase access token");
  const token = authorization.slice(7).trim();
  if (!token) throw new ApiError(401, "Invalid access token");
  if (!env.SUPABASE_URL?.trim() || !env.SUPABASE_ANON_KEY?.trim()) {
    throw new ApiError(500, "Supabase authentication is not configured");
  }
  let response: Response;
  try {
    response = await fetch(env.SUPABASE_URL.replace(/\/+$/, "") + "/auth/v1/user", {
      method: "GET", headers: { Authorization: "Bearer " + token, apikey: env.SUPABASE_ANON_KEY },
    });
  } catch { throw new ApiError(503, "Supabase authentication service is unavailable"); }
  if (!response.ok) throw new ApiError(401, "Supabase Auth rejected the access token (" + response.status + ")");
  const user = await response.json() as Partial<AuthUser>;
  if (typeof user.id !== "string" || !user.id.trim()) throw new ApiError(401, "Authenticated user ID is missing");
  return user as AuthUser;
}

async function requireAdmin(request: Request, env: Env): Promise<AuthUser> {
  const user = await getCurrentUser(request, env);
  const allowlist = (env.ALLOWED_ADMIN_USER_IDS || "").split(",").map((value) => value.trim()).filter(Boolean);
  if (allowlist.length > 0 && !allowlist.includes(user.id)) throw new ApiError(403, "User is not allowed to manage videos");
  const url = new URL(env.SUPABASE_URL.replace(/\/+$/, "") + "/rest/v1/profiles");
  url.searchParams.set("select", "role");
  url.searchParams.set("id", "eq." + user.id);
  url.searchParams.set("limit", "1");
  let response: Response;
  try {
    response = await fetch(url, {
      headers: { Authorization: request.headers.get("Authorization") || "", apikey: env.SUPABASE_ANON_KEY },
    });
  } catch { throw new ApiError(503, "Supabase profile service is unavailable"); }
  if (!response.ok) throw new ApiError(403, "Unable to verify admin role");
  const rows = await response.json() as Array<{ role?: string }>;
  if (!rows.length || rows[0].role !== "admin") throw new ApiError(403, "Admin role is required");
  return user;
}

function s3ObjectUrl(env: Env, key: string, query: Record<string, string> = {}): URL {
  const bucket = requireValue(env.R2_BUCKET_NAME, "R2_BUCKET_NAME");
  const url = new URL(getR2Endpoint(env) + "/" + encodeURIComponent(bucket) + "/" + encodeKey(key));
  for (const [name, value] of Object.entries(query)) url.searchParams.set(name, value);
  return url;
}

async function s3Request(
  env: Env,
  key: string,
  method: string,
  query: Record<string, string> = {},
  body?: string,
  headers: Record<string, string> = {},
): Promise<Response> {
  const url = s3ObjectUrl(env, key, query);
  return getR2Signer(env).fetch(url.toString(), {
    method,
    headers,
    body,
  });
}

function decodeXmlText(value: string): string {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
}

function xmlTagValue(xml: string, tag: string): string | null {
  const match = xml.match(new RegExp("<" + tag + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + tag + ">", "i"));
  return match ? decodeXmlText(match[1].trim()) : null;
}

function s3ErrorSummary(xml: string): string {
  const code = xmlTagValue(xml, "Code");
  const message = xmlTagValue(xml, "Message");
  return [code, message].filter(Boolean).join(": ").slice(0, 300) || xml.replace(/\s+/g, " ").slice(0, 300);
}

async function createSignedUrl(env: Env, key: string, method: "GET" | "PUT", query: Record<string, string> = {}): Promise<string> {
  const url = s3ObjectUrl(env, key, query);
  url.searchParams.set("X-Amz-Expires", "3600");
  const signed = await getR2Signer(env).sign(new Request(url, { method }), { aws: { signQuery: true } });
  return signed.url.toString();
}

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method.toUpperCase();

  if (method === "GET" && (path === "/" || path === "/health")) {
    const configured = Boolean(env.R2_BUCKET && env.R2_BUCKET_NAME && env.R2_ACCOUNT_ID && env.R2_ACCESS_KEY_ID && env.R2_SECRET_ACCESS_KEY && env.SUPABASE_URL && env.SUPABASE_ANON_KEY);
    let r2Ok = false;
    let r2Error: string | null = null;
    if (configured) {
      try {
        await env.R2_BUCKET.list({ limit: 1 });
        const bucketUrl = getR2Endpoint(env) + "/" + encodeURIComponent(env.R2_BUCKET_NAME);
        const credentialCheck = await getR2Signer(env).fetch(bucketUrl, { method: "HEAD" });
        if (!credentialCheck.ok) throw new Error("R2 S3 credentials rejected (HTTP " + credentialCheck.status + ")");
        r2Ok = true;
      } catch (error) {
        r2Error = error instanceof Error ? error.name + ": " + error.message.slice(0, 240) : String(error).slice(0, 240);
      }
    } else r2Error = "Missing one or more required environment variables";
    return json({ status: "ok", r2_configured: configured, r2_ok: r2Ok, r2_error: r2Error, bucket: env.R2_BUCKET_NAME || "medidata-videos", service: "MediData R2 Worker" });
  }

  if (method === "POST" && path === "/api/r2/multipart/initiate") {
    const user = await requireAdmin(request, env);
    const body = await readJson<InitiateBody>(request);
    const lectureId = requireValue(body.lecture_id, "lecture_id");
    const filename = safeFilename(requireValue(body.filename, "filename"));
    const fileSize = Number(body.file_size);
    if (!Number.isSafeInteger(fileSize) || fileSize <= 0) throw new ApiError(400, "File size must be greater than zero");
    if (fileSize > MAX_UPLOAD_BYTES) throw new ApiError(413, "Video exceeds the R2 maximum supported size");
    const contentType = contentTypeForFilename(filename, body.content_type);
    const key = buildObjectKey(lectureId, filename);
    try {
      // Start the multipart session through the S3 API because parts are sent to
      // S3-compatible presigned URLs and must use the same S3 multipart upload ID.
      const response = await s3Request(env, key, "POST", { uploads: "" }, undefined, {
        "Content-Type": contentType,
        "x-amz-meta-lecture-id": lectureId.slice(0, 200),
        "x-amz-meta-uploaded-by": user.id.slice(0, 200),
        "x-amz-meta-original-filename": filename.slice(0, 200),
      });
      const responseText = await response.text();
      if (!response.ok) {
        throw new Error("CreateMultipartUpload failed (HTTP " + response.status + "): " + s3ErrorSummary(responseText));
      }
      const uploadId = xmlTagValue(responseText, "UploadId");
      if (!uploadId) throw new Error("R2 returned no UploadId: " + responseText.slice(0, 240));
      return json({ ok: true, key, upload_id: uploadId, part_size: PART_SIZE, file_name: filename, file_size: fileSize });
    } catch (error) {
      console.error("R2 S3 multipart initiate failed", error);
      throw new ApiError(502, "R2 could not start the multipart upload: " + (error instanceof Error ? error.message.slice(0, 300) : String(error).slice(0, 300)));
    }
  }

  if (method === "POST" && path === "/api/r2/multipart/part-url") {
    await requireAdmin(request, env);
    const body = await readJson<PartUrlBody>(request);
    const key = validateLectureKey(body.key);
    const uploadId = requireValue(body.upload_id, "upload_id");
    const partNumber = Number(body.part_number);
    if (!Number.isInteger(partNumber) || partNumber < 1 || partNumber > 10000) throw new ApiError(400, "Invalid part number");
    const signedUrl = await createSignedUrl(env, key, "PUT", { partNumber: String(partNumber), uploadId });
    return json({ ok: true, url: signedUrl });
  }

  if (method === "POST" && path === "/api/r2/multipart/complete") {
    const user = await requireAdmin(request, env);
    const body = await readJson<CompleteBody>(request);
    const key = validateLectureKey(body.key);
    const uploadId = requireValue(body.upload_id, "upload_id");
    if (!Array.isArray(body.parts) || body.parts.length === 0) throw new ApiError(400, "Invalid multipart completion request");
    const parts = body.parts.map((part) => ({ partNumber: Number(part.part_number), etag: requireValue(part.etag, "etag") })).sort((a, b) => a.partNumber - b.partNumber);
    const seenPartNumbers = new Set<number>();
    for (const part of parts) {
      if (!Number.isInteger(part.partNumber) || part.partNumber < 1 || part.partNumber > 10000) {
        throw new ApiError(400, "Invalid uploaded part number");
      }
      if (seenPartNumbers.has(part.partNumber)) throw new ApiError(400, "Duplicate uploaded part number");
      seenPartNumbers.add(part.partNumber);
    }
    const xml = '<?xml version="1.0" encoding="UTF-8"?>' +
      "<CompleteMultipartUpload>" +
      parts.map((part) => "<Part><PartNumber>" + part.partNumber +
        "</PartNumber><ETag>" + part.etag.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") +
        "</ETag></Part>").join("") +
      "</CompleteMultipartUpload>";
    try {
      // Complete through the same S3 API that created the upload ID and received each part.
      const response = await s3Request(env, key, "POST", { uploadId }, xml, {
        "Content-Type": "application/xml",
      });
      const responseText = await response.text();
      // S3 can report a multipart completion error inside an HTTP 200 response.
      if (!response.ok || /<Error(?:\s|>)/i.test(responseText)) {
        throw new Error("CompleteMultipartUpload failed (HTTP " + response.status + "): " + s3ErrorSummary(responseText));
      }
      const object = await env.R2_BUCKET.head(key);
      if (!object) throw new Error("Multipart completion returned success, but the object was not found in the bucket.");
      return json({ ok: true, key, etag: object.httpEtag, file_size: object.size, content_type: object.httpMetadata?.contentType || null, uploaded_by: user.id });
    } catch (error) {
      console.error("R2 S3 multipart complete failed", error);
      throw new ApiError(502, "R2 could not complete the multipart upload: " + (error instanceof Error ? error.message.slice(0, 300) : String(error).slice(0, 300)));
    }
  }

  if (method === "POST" && path === "/api/r2/multipart/abort") {
    await requireAdmin(request, env);
    const body = await readJson<AbortBody>(request);
    const key = validateLectureKey(body.key);
    const uploadId = requireValue(body.upload_id, "upload_id");
    try {
      const response = await s3Request(env, key, "DELETE", { uploadId });
      const responseText = await response.text();
      if (!response.ok) {
        throw new Error("AbortMultipartUpload failed (HTTP " + response.status + "): " + s3ErrorSummary(responseText));
      }
      return json({ ok: true });
    } catch (error) {
      console.error("R2 S3 multipart abort failed", error);
      throw new ApiError(502, "R2 could not abort the multipart upload: " + (error instanceof Error ? error.message.slice(0, 300) : String(error).slice(0, 300)));
    }
  }

  if (method === "POST" && path === "/api/r2/signed-url") {
    await getCurrentUser(request, env);
    const body = await readJson<SignedUrlBody>(request);
    const key = validateLectureKey(body.key);
    return json({ ok: true, url: await createSignedUrl(env, key, "GET"), expires_in: 3600 });
  }

  if (method === "DELETE" && path === "/api/r2/object") {
    await requireAdmin(request, env);
    const key = validateLectureKey(url.searchParams.get("key"));
    try { await env.R2_BUCKET.delete(key); return json({ ok: true, key }); }
    catch (error) { console.error("R2 delete failed", error); throw new ApiError(502, "R2 could not delete the object"); }
  }

  return json({ detail: "Not Found" }, 404);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method.toUpperCase() === "OPTIONS") return withCors(new Response(null, { status: 204 }));
    try { return await route(request, env); }
    catch (error) {
      const status = error instanceof ApiError ? error.status : 500;
      const detail = error instanceof ApiError ? error.message : "Unexpected internal server error";
      console.error("MediData R2 Worker request failed", { path: new URL(request.url).pathname, status, error: error instanceof Error ? error.message : String(error) });
      return json({ detail }, status);
    }
  },
} satisfies ExportedHandler<Env>;