# FCM (Push Bildirim) Kurulumu

Sunucu tarafı **hazır**: sinyal sunucusu, `notifications` tablosuna düşen her satırı
(mesaj, arama, dürtme, arkadaşlık isteği, oda daveti...) kullanıcının cihazına FCM
push olarak iletir. Tek koşul: Firebase yapılandırması.

## 1. Firebase projesi (bir kez, ~10 dk)

1. https://console.firebase.google.com → **Add project** → `kerochat`.
2. **Project settings → Service accounts → Generate new private key** → JSON'u indir.
3. VPS'te `/etc/azar-chat/env` dosyasına tek satır olarak ekle:

```
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"kerochat",...}
```

(JSON'un tamamı tek satırda; içindeki `\n`'ler `private_key` alanında kalmalı.)

4. `systemctl restart azar-chat-server` → logda `[fcm] push bridge active` görünmeli.

## 2. Flutter tarafı (token kaydı)

Uygulamaya `firebase_core` + `firebase_messaging` eklenecek:

```bash
cd app
dart pub global activate flutterfire_cli
flutterfire configure          # Firebase projesini seç — firebase_options.dart üretir
flutter pub add firebase_core firebase_messaging
```

`main.dart` başına:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

Giriş sonrası token kaydı (ör. AuthController._refreshMode içine):

```dart
final token = await FirebaseMessaging.instance.getToken(
  vapidKey: kIsWeb ? 'WEB_PUSH_CERT_KEY' : null,   // web için Cloud Messaging → Web Push certificates
);
if (token != null) {
  await Supabase.instance.client
      .from('profiles').update({'fcm_token': token}).eq('id', uid);
}
FirebaseMessaging.instance.onTokenRefresh.listen((t) => /* aynı update */);
```

İzin isteme (Android 13+ / iOS / web):

```dart
await FirebaseMessaging.instance.requestPermission();
```

`profiles.fcm_token` kolonu şemada hazır (schema_v10).

## 3. Test

1. İki hesapla gir; A, B'yi **dürtsün** (Sohbetler → Arkadaşlar → 👋).
2. B uygulamayı kapatmışsa bile cihaza "👉 Dürtüldün!" push'u düşmeli.
3. Sunucu logu: `journalctl -u azar-chat-server -f | grep fcm`

## Notlar

- Web push için `web/firebase-messaging-sw.js` service worker'ı gerekir
  (flutterfire configure sonrası standart şablon).
- FCM env yoksa sunucu sessizce devre dışı kalır (`[fcm] disabled` logu) —
  uygulama içi bildirimler etkilenmez.
