# Firebase Storage CORS Configuration for Web Upload

## Problem
Firebase Storage on web requires CORS configuration to allow uploads from localhost during development.

Error seen:
```
Access to XMLHttpRequest blocked by CORS policy
Response to preflight request doesn't pass access control check
```

## Solution: Configure CORS via Google Cloud Console

### Option 1: Using Google Cloud Console (Recommended - No CLI needed)

1. Go to Google Cloud Console: https://console.cloud.google.com
2. Select project: **flexcrew-1f436**
3. Go to **Storage** → **Buckets** → **flexcrew-1f436.appspot.com**
4. Click the **CORS Configuration** tab
5. Click **Edit CORS Configuration**
6. Replace with this configuration:

```json
[
  {
    "origin": ["http://localhost:*", "http://127.0.0.1:*"],
    "method": ["GET", "HEAD", "DELETE", "PUT", "POST"],
    "responseHeader": ["Content-Type", "x-goog-meta-uploaded-content-length"],
    "maxAgeSeconds": 3600
  },
  {
    "origin": ["https://flexcrew-1f436.web.app"],
    "method": ["GET", "HEAD", "DELETE", "PUT", "POST"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```

7. Click **Save**
8. Wait ~1 minute for changes to propagate
9. Go back to the app and try uploading again

### Option 2: Using gsutil (Command Line)

If you have Google Cloud SDK installed, run:

```bash
# From the project directory:
gsutil cors set cors.json gs://flexcrew-1f436.appspot.com
```

The `cors.json` file is already in the project root.

---

## What This CORS Config Does

- **Allows localhost** (all ports): `http://localhost:*` — needed for development
- **Allows 127.0.0.1** (all ports): `http://127.0.0.1:*` — for emulators
- **Allows production**: `https://flexcrew-1f436.web.app` — for production deployments
- **Methods**: GET, HEAD, DELETE, PUT, POST — needed for upload
- **Response headers**: Allows content-type headers in responses
- **Cache**: 3600 seconds (1 hour)

---

## After Applying CORS

1. The avatar upload should work without CORS errors
2. You'll see all our debug logs complete to "Upload completed"
3. Firestore will update with the new avatarUrl
4. The image will display in CircleAvatar

Try it and report back!
