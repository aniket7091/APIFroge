# APIForge 🔥

**A full-stack API testing tool similar to Postman**, built with **Flutter** (Web + Desktop) and a **Node.js + Express + MongoDB** backend.

---

## Features

| Feature | Details |
|---------|---------|
| 🚀 **HTTP Request Builder** | GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS |
| 📦 **Collections** | Create, edit, delete collections with color labels |
| 📜 **History** | Auto-logged request history with pagination |
| 🔐 **JWT Auth** | Signup/Login + Bearer & Basic auth support |
| 🌍 **Environment Variables** | `{{VAR_NAME}}` interpolation in URLs |
| 💡 **Code Snippets** | Generate `curl` & JS `fetch` code |
| 🎨 **Dark / Light Mode** | Persistent, togglable from the sidebar |
| 🖥️ **Responsive Layout** | Side-by-side panels on wide screens, stacked on narrow |

---

## Project Structure

```
APIForge/
├── backend/               # Node.js + Express API
│   ├── config/            # MongoDB connection
│   ├── controllers/       # Auth, Collection, Request, History, Proxy
│   ├── middleware/        # JWT auth, error handler, validation
│   ├── models/            # User, Collection, Request, History schemas
│   ├── routes/            # REST routes
│   ├── services/          # Snippet generator
│   ├── .env               # Environment variables
│   └── server.js          # Entry point
│
└── apiforge/              # Flutter frontend
    └── lib/
        ├── main.dart
        ├── theme/          # AppTheme, AppColors, AppThemeProvider
        ├── models/         # Dart models (User, Collection, Request, History)
        ├── services/       # API clients (auth, proxy, collection, history, request)
        ├── screens/        # HomeScreen, AuthScreen, CollectionsScreen, HistoryScreen, SettingsScreen
        ├── widgets/        # SidebarDrawer, ResponseViewer
        └── utils/          # StorageUtils (SharedPreferences)
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Node.js | v18+ |
| MongoDB | v6+ (or use MongoDB Atlas) |
| Flutter | v3.27+ |
| Dart | v3.5+ |

---

## ⚙️ Backend Setup

```bash
# 1. Navigate to backend
cd APIForge/backend

# 2. Install dependencies
npm install

# 3. Configure environment (edit .env)
# MONGO_URI=mongodb://localhost:27017/apiforge
# JWT_SECRET=your_secret_key
# PORT=5000

# 4. Start MongoDB (skip if using Atlas)
mongod

# 5. Start backend
npm run dev          # Development with nodemon
# or
npm start            # Production
```

The API will be available at **http://localhost:5000/api**

### API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/signup` | ❌ | Register |
| POST | `/api/auth/login` | ❌ | Login |
| GET | `/api/auth/me` | ✅ | Current user |
| GET | `/api/collections` | ✅ | List collections |
| POST | `/api/collections` | ✅ | Create collection |
| PUT | `/api/collections/:id` | ✅ | Update collection |
| DELETE | `/api/collections/:id` | ✅ | Delete collection |
| GET | `/api/requests` | ✅ | List saved requests |
| POST | `/api/requests` | ✅ | Save request |
| PUT | `/api/requests/:id` | ✅ | Update request |
| DELETE | `/api/requests/:id` | ✅ | Delete request |
| GET | `/api/history` | ✅ | Request history |
| DELETE | `/api/history` | ✅ | Clear history |
| POST | `/api/proxy/send` | ✅ | Forward HTTP request |
| POST | `/api/proxy/snippet` | ✅ | Generate code snippet |
| POST | `/api/proxy/performance` | ✅ | Run multiple requests |
| GET | `/api/health` | ❌ | Health check |

---

## 🎨 Flutter Frontend Setup

```bash
# 1. Navigate to Flutter project
cd APIForge/apiforge

# 2. Install packages
flutter pub get

# 3. Run on Web
flutter run -d chrome

# 4. Run on macOS Desktop
flutter run -d macos

# 5. Run on Linux Desktop
flutter run -d linux

# 6. Build for web production
flutter build web
```

> **Note:** The Flutter app connects to `http://localhost:5000/api` by default.
> To change this, edit `lib/services/api_client.dart` and update `_baseUrl`.

---

## 🌍 Using Environment Variables

1. Open the app → Sidebar → **Environment & Settings**
2. Add a variable: e.g., `BASE_URL` = `https://api.example.com`
3. Use it in your URL field: `{{BASE_URL}}/users`

---

## 🚢 Deployment

### Backend — Deploy to Railway / Render / Heroku

```bash
# Set environment variables on your platform:
MONGO_URI=mongodb+srv://...   # Atlas connection string
JWT_SECRET=your_production_secret
PORT=5000
NODE_ENV=production
```

### Frontend — Deploy to Vercel / Firebase Hosting

```bash
flutter build web
# Upload the build/web directory to your hosting provider
```

Update `_baseUrl` in `lib/services/api_client.dart` to your production backend URL before building.

---

## 🔒 Security Notes

- All sensitive credentials are stored in `.env` (never committed)
- Passwords hashed with bcrypt (12 rounds)
- JWT expiry: 7 days (configurable via `JWT_EXPIRES_IN`)
- History auto-expires after 30 days (MongoDB TTL index)
- Input validation on all POST/PUT endpoints

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter 3.27+, Provider, Dio, Google Fonts |
| Backend | Node.js, Express, Axios |
| Database | MongoDB, Mongoose |
| Auth | bcryptjs, jsonwebtoken |
| Storage | SharedPreferences (Flutter), dotenv |

---

## 📝 License

MIT — free to use and modify.
