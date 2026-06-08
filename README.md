# BookSwap

Book exchange platform for university students — IPCA PCM 2025/2026.

Users can list, buy, borrow, and trade books with each other. An admin dashboard provides statistics and transaction management.

---

## Prerequisites

- [Flutter SDK](https://flutter.dev) ≥ 3.11
- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- SQL Server (local instance or SQL Server Express)
- [ngrok](https://ngrok.com) — only needed for testing on a physical device

---

## Database Setup

1. Open SQL Server Management Studio (or `sqlcmd`) and create a database named `BookSwap`.
2. Run the scripts in order:

```
BookSwapAPI/sql/create_tables.sql
BookSwapAPI/sql/insert_test_data.sql
```

---

## API Setup

```bash
cd BookSwapAPI
dotnet run
```

The API starts on `http://0.0.0.0:5003`.

> Update `BookSwapAPI/appsettings.json` if your SQL Server connection string differs from the default.

---

## Flutter App Setup

```bash
cd bookswap_flutter
flutter pub get
flutter run
```

### Server Configuration

On first launch the app shows a **Server Config** screen. Enter the API base URL:

| Scenario | URL |
|---|---|
| Android emulator | `http://10.0.2.2:5003` |
| iOS simulator | `http://localhost:5003` |
| Physical device (ngrok) | `https://<your-subdomain>.ngrok-free.app` |

---

## ngrok (physical device)

```bash
ngrok http 5003
```

Copy the `https://` forwarding URL and paste it into the app's Server Config screen.

---

## Default Credentials

| Role | Email | Password |
|---|---|---|
| Admin | `admin@bookswap.pt` | `admin123` |
| Test user | `ana.silva@email.pt` | `teste123` |
| Test user | `pedro.costa@email.pt` | `teste123` |
| Test user | `maria.ferreira@email.pt` | `teste123` |
| Test user | `joao.santos@email.pt` | `teste123` |

---

## Admin Dashboard

Log in as an admin user and open the **Admin** tab. From there:

- **Estatísticas** — system statistics including transaction counts, completion rate, average books per user, monthly activity chart, and books by category.
- **Transações** — view and act on all pending transactions (accept / reject / cancel).
- **Utilizadores** — manage users and toggle admin status.
- **Livros** — edit or remove books from the catalog.
