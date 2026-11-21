# Лабораторна робота 2. Клієнтська частина

Клієнтська частина створена із використанням команди `bun init` на базі Bun v1.3.8.

## Як запустити

1. Встановіть залежності: `bun install`.
2. Запустіть клієнт командою `bun dev`, а сервер — відповідно до інструкцій у `server/README.md`.
3. Відкрийте `http://localhost:3000`. Handshake запускається автоматично; введіть логін `rimworld` і пароль `awolnation`, щойно форма стане доступною.

## Криптографія

Клієнт використовує лише вбудований Web Crypto API (`crypto.subtle`). Відкритий RSA-ключ сервера закріплений у `src/secrets/serverPublicKey.ts`; він має відповідати локальному `server/private_key.pem`. Web Crypto потребує захищеного контексту, тому використовуйте `localhost` або HTTPS. Запити handshake і login передають cookie через `credentials: "include"`.
